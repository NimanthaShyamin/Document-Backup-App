import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_preferences_provider.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/datasources/remote/gemini_document_extraction_service.dart';
import '../../domain/entities/vehicle_document.dart';
import 'document_providers.dart';

/// Scanning status of the Global Foreground Scanner Queue.
enum ScanStatus {
  idle,
  scanning,
  waitingRateLimit,
}

/// State exposed to the UI representing the global sequential AI extraction queue.
class ForegroundScanState {
  final ScanStatus status;
  final String? activeDocumentId;
  final int baseSecondsRemaining; // Seconds until the NEXT document starts scanning
  final List<String> pendingQueueIds; // Pending document IDs in FIFO order
  final DateTime? lastScanCompletionTime;

  const ForegroundScanState({
    this.status = ScanStatus.idle,
    this.activeDocumentId,
    this.baseSecondsRemaining = 0,
    this.pendingQueueIds = const [],
    this.lastScanCompletionTime,
  });

  /// Backward-compatible alias for baseSecondsRemaining.
  int get secondsRemaining => baseSecondsRemaining;

  /// Whether a specific document is actively being scanned right now.
  bool isScanning(String docId) =>
      status == ScanStatus.scanning && activeDocumentId == docId;

  /// Whether the global queue is currently observing the 60-second rate limit cooldown.
  bool get isWaiting => status == ScanStatus.waitingRateLimit;

  /// Calculates the exact remaining seconds for a given document in the global queue.
  ///
  /// - Active document: returns 0.
  /// - Next document (index 0): returns `baseSecondsRemaining` (ticking down from 60s).
  /// - Deep queue documents (index k): adds 60 seconds per position in the queue.
  int? getWaitSecondsFor(String docId) {
    if (isScanning(docId)) return 0;

    int index = pendingQueueIds.indexOf(docId);
    if (index == -1) {
      if (activeDocumentId == docId && status == ScanStatus.waitingRateLimit) {
        index = 0;
      } else {
        return null;
      }
    }

    if (status == ScanStatus.scanning) {
      // An active document is currently scanning; queued docs wait 60s per position
      return 60 + (index * 60);
    } else if (status == ScanStatus.waitingRateLimit) {
      return baseSecondsRemaining + (index * 60);
    } else {
      // Idle / ready to start
      return index * 60;
    }
  }

  ForegroundScanState copyWith({
    ScanStatus? status,
    String? activeDocumentId,
    int? baseSecondsRemaining,
    List<String>? pendingQueueIds,
    DateTime? lastScanCompletionTime,
  }) {
    return ForegroundScanState(
      status: status ?? this.status,
      activeDocumentId: activeDocumentId ?? this.activeDocumentId,
      baseSecondsRemaining: baseSecondsRemaining ?? this.baseSecondsRemaining,
      pendingQueueIds: pendingQueueIds ?? this.pendingQueueIds,
      lastScanCompletionTime: lastScanCompletionTime ?? this.lastScanCompletionTime,
    );
  }

  @override
  String toString() =>
      'ForegroundScanState(status: $status, activeId: $activeDocumentId, baseRemaining: $baseSecondsRemaining, queueLen: ${pendingQueueIds.length})';
}

/// Riverpod StateNotifier managing a Global Cooldown Queue for foreground AI scanning.
///
/// Ensures:
/// 1. Documents flagged with `requiresAiScan == true` are processed strictly ONE by ONE.
/// 2. First document processes IMMEDIATELY (0s) if no scan occurred in the last 60 seconds.
/// 3. Subsequent documents enforce a strict 60-second cooldown via a single global timer.
/// 4. Deep queue items dynamically calculate their wait time (+60s per queue position).
/// 5. Manual override ("Force Scan Now") bypasses the cooldown for that specific document.
class ForegroundScannerNotifier extends StateNotifier<ForegroundScanState> {
  final Ref _ref;

  /// Global timestamp tracking the completion of the last AI extraction across the entire app
  static DateTime? lastScanCompletionTime;

  Timer? _globalCooldownTimer;
  Completer<void>? _cooldownCompleter;
  bool _isLoopRunning = false;
  String? _forcedDocumentId;
  final Map<String, int> _scanAttempts = {};

  ForegroundScannerNotifier(this._ref) : super(const ForegroundScanState()) {
    // Listen to changes in the document stream to detect newly imported documents
    _ref.listen<AsyncValue<List<VehicleDocument>>>(
      vehicleDocumentsStreamProvider,
      (previous, next) {
        next.whenData((docs) {
          _onDocumentsChanged(docs);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _stopGlobalTimer();
    super.dispose();
  }

  void _stopGlobalTimer() {
    _globalCooldownTimer?.cancel();
    _globalCooldownTimer = null;
  }

  /// Triggered whenever the reactive document stream updates.
  void _onDocumentsChanged(List<VehicleDocument> docs) {
    final pending = docs.where((d) => d.requiresAiScan).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final pendingIds = pending
        .where((d) => d.id != state.activeDocumentId)
        .map((d) => d.id)
        .toList();

    // Update pending queue IDs in the state without resetting active scanning
    state = state.copyWith(pendingQueueIds: pendingIds);

    if (pending.isEmpty) {
      if (state.status != ScanStatus.idle) {
        _stopGlobalTimer();
        state = const ForegroundScanState(status: ScanStatus.idle);
      }
      return;
    }

    // If loop is not already running, kick off the sequential queue loop
    if (!_isLoopRunning) {
      _startQueueLoop();
    }
  }

  /// Manual override: Bypasses queue wait time and processes [documentId] immediately.
  Future<void> forceScan(String documentId) async {
    developer.log('[ForegroundScanner] Force Scan requested for document: $documentId');

    if (state.isScanning(documentId)) {
      developer.log('[ForegroundScanner] Document $documentId is already scanning.');
      return;
    }

    _forcedDocumentId = documentId;
    lastScanCompletionTime = null; // Reset rate limit for immediate execution

    // Interrupt any active cooldown wait so the loop proceeds immediately
    if (_cooldownCompleter != null && !_cooldownCompleter!.isCompleted) {
      _cooldownCompleter!.complete();
    }

    if (!_isLoopRunning) {
      _startQueueLoop();
    }
  }

  /// Initiates the single-loop sequential queue processor.
  void _startQueueLoop() {
    if (_isLoopRunning) return;
    _runSequentialQueueLoop();
  }

  /// The core single-loop sequential executor.
  Future<void> _runSequentialQueueLoop() async {
    if (_isLoopRunning) return;
    _isLoopRunning = true;

    developer.log('[ForegroundScanner] Starting global sequential queue loop.');

    try {
      while (true) {
        final db = _ref.read(appDatabaseProvider);
        final apiKey = _ref.read(geminiApiKeyProvider);

        if (apiKey.trim().isEmpty) {
          developer.log('[ForegroundScanner] Gemini API key not configured. Halting foreground queue.');
          _stopGlobalTimer();
          state = const ForegroundScanState(status: ScanStatus.idle);
          break;
        }

        // Query pending documents from Drift DB
        final pendingDocs = await (db.select(db.vehicleDocuments)
              ..where((t) => t.requiresAiScan.equals(true))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
            .get();

        if (pendingDocs.isEmpty) {
          developer.log('[ForegroundScanner] No more pending documents. Queue is idle.');
          _stopGlobalTimer();
          state = const ForegroundScanState(status: ScanStatus.idle);
          break;
        }

        // Determine which document to process: forced override has top priority
        VehicleDocumentData docToProcess;
        if (_forcedDocumentId != null) {
          final forcedMatch = pendingDocs.where((d) => d.id == _forcedDocumentId).firstOrNull;
          if (forcedMatch != null) {
            docToProcess = forcedMatch;
          } else {
            docToProcess = pendingDocs.first;
          }
          _forcedDocumentId = null;
        } else {
          docToProcess = pendingDocs.first;
        }

        // Evaluate token bucket timing relative to global lastScanCompletionTime
        final now = DateTime.now();
        if (lastScanCompletionTime != null) {
          final elapsedSeconds = now.difference(lastScanCompletionTime!).inSeconds;
          final waitSeconds = 60 - elapsedSeconds;

          if (waitSeconds > 0) {
            final queuedIds = pendingDocs.map((d) => d.id).toList();
            developer.log('[ForegroundScanner] Rate limit active. Next scan starts in $waitSeconds seconds.');
            await _waitForCooldown(waitSeconds, queuedIds);

            // Re-check after cooldown completes (document might have been deleted)
            continue;
          }
        }

        // Rate limit satisfied (or first document): Scan immediately!
        final remainingIds = pendingDocs
            .where((d) => d.id != docToProcess.id)
            .map((d) => d.id)
            .toList();

        _stopGlobalTimer();
        state = ForegroundScanState(
          status: ScanStatus.scanning,
          activeDocumentId: docToProcess.id,
          baseSecondsRemaining: 0,
          pendingQueueIds: remainingIds,
          lastScanCompletionTime: lastScanCompletionTime,
        );

        developer.log('[ForegroundScanner] Processing document: ${docToProcess.id} ("${docToProcess.title}")');
        try {
          await _executeScan(db, apiKey, docToProcess);
        } finally {
          state = state.copyWith(activeDocumentId: null);
        }

        // Record global completion time
        lastScanCompletionTime = DateTime.now();
        developer.log('[ForegroundScanner] Scan completed at $lastScanCompletionTime.');
      }
    } catch (e, stack) {
      developer.log('[ForegroundScanner] Error in queue loop: $e', error: e, stackTrace: stack);
      state = const ForegroundScanState(status: ScanStatus.idle);
    } finally {
      _isLoopRunning = false;
      developer.log('[ForegroundScanner] Global sequential queue loop finished.');
    }
  }

  /// Waits for the rate limit cooldown while broadcasting a 1-second ticking countdown to Riverpod.
  Future<void> _waitForCooldown(int totalSeconds, List<String> queuedIds) async {
    _stopGlobalTimer();
    _cooldownCompleter = Completer<void>();

    state = ForegroundScanState(
      status: ScanStatus.waitingRateLimit,
      activeDocumentId: null,
      baseSecondsRemaining: totalSeconds,
      pendingQueueIds: queuedIds,
      lastScanCompletionTime: lastScanCompletionTime,
    );

    _globalCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (lastScanCompletionTime == null) {
        // Cooldown was manually bypassed by forceScan
        timer.cancel();
        if (!_cooldownCompleter!.isCompleted) _cooldownCompleter!.complete();
        return;
      }

      final elapsed = DateTime.now().difference(lastScanCompletionTime!).inSeconds;
      final remaining = 60 - elapsed;

      if (remaining <= 0) {
        timer.cancel();
        if (!_cooldownCompleter!.isCompleted) _cooldownCompleter!.complete();
      } else {
        state = state.copyWith(
          baseSecondsRemaining: remaining,
        );
      }
    });

    await _cooldownCompleter!.future;
    _stopGlobalTimer();
  }

  /// Executes Gemini multimodal extraction and updates Drift DB.
  Future<void> _executeScan(
    AppDatabase db,
    String apiKey,
    VehicleDocumentData docData,
  ) async {
    final file = File(docData.localFilePath);
    if (!await file.exists()) {
      developer.log('[ForegroundScanner] File missing at ${docData.localFilePath}. Clearing flag.');
      _scanAttempts.remove(docData.id);
      await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
        const VehicleDocumentsCompanion(requiresAiScan: Value(false)),
      );
      return;
    }

    try {
      final extractionService = GeminiDocumentExtractionService(apiKey: apiKey);
      final extracted = await extractionService.extractDetailsFromFile(file).timeout(
        const Duration(seconds: 30),
        onTimeout: () => ExtractedDocumentDetails.error('Scan timed out after 30 seconds.'),
      );

      if (extracted.isAiDetected) {
        developer.log('[ForegroundScanner] AI Scan successful for ${docData.id}. Updating database.');
        _scanAttempts.remove(docData.id);

        Map<String, dynamic> mergedVisible = {};
        if (docData.visibleFields.isNotEmpty) {
          try {
            mergedVisible = jsonDecode(docData.visibleFields) as Map<String, dynamic>;
          } catch (_) {}
        }
        if (extracted.visibleFields.isNotEmpty) {
          mergedVisible.addAll(extracted.visibleFields);
        }

        final effectiveCategory = (extracted.category != null && extracted.category!.isNotEmpty)
            ? extracted.category!
            : docData.category;

        final effectiveTitle = (extracted.title != null &&
                extracted.title!.isNotEmpty &&
                (docData.title.isEmpty ||
                    docData.title == 'Untitled Document' ||
                    docData.title == 'General Document' ||
                    docData.title.toLowerCase().contains('scan')))
            ? extracted.title!
            : docData.title;

        final effectiveExpiry = extracted.expiryDate != null
            ? extracted.expiryDate!.millisecondsSinceEpoch
            : docData.expiryDate;

        final effectiveHidden = (extracted.hiddenContext != null && extracted.hiddenContext!.isNotEmpty)
            ? extracted.hiddenContext
            : docData.hiddenContext;

        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
          VehicleDocumentsCompanion(
            category: Value(effectiveCategory),
            title: Value(effectiveTitle),
            expiryDate: Value(effectiveExpiry),
            visibleFields: Value(jsonEncode(mergedVisible)),
            hiddenContext: Value(effectiveHidden),
            requiresAiScan: const Value(false),
            lastModifiedTimestamp: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      } else if (extracted.errorMessage == null) {
        developer.log('[ForegroundScanner] Scan completed with no metadata detected for ${docData.id}. Clearing flag.');
        _scanAttempts.remove(docData.id);
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
          const VehicleDocumentsCompanion(requiresAiScan: Value(false)),
        );
      } else {
        final attempts = (_scanAttempts[docData.id] ?? 0) + 1;
        _scanAttempts[docData.id] = attempts;
        developer.log('[ForegroundScanner] Temporary scan error for ${docData.id} (attempt $attempts): ${extracted.errorMessage}.');

        if (attempts >= 3) {
          developer.log('[ForegroundScanner] Max scan attempts (3) reached for ${docData.id}. Clearing flag to unblock queue.');
          _scanAttempts.remove(docData.id);
          await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
            const VehicleDocumentsCompanion(requiresAiScan: Value(false)),
          );
        }
      }
    } catch (e, stack) {
      developer.log('[ForegroundScanner] Error executing scan for ${docData.id}: $e', error: e, stackTrace: stack);
      final attempts = (_scanAttempts[docData.id] ?? 0) + 1;
      _scanAttempts[docData.id] = attempts;
      if (attempts >= 3) {
        developer.log('[ForegroundScanner] Max scan attempts (3) reached after error for ${docData.id}. Clearing flag.');
        _scanAttempts.remove(docData.id);
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
          const VehicleDocumentsCompanion(requiresAiScan: Value(false)),
        );
      }
    }
  }
}

/// Provider for the [ForegroundScannerNotifier].
final foregroundScannerServiceProvider =
    StateNotifierProvider<ForegroundScannerNotifier, ForegroundScanState>((ref) {
  return ForegroundScannerNotifier(ref);
});

/// Provider for watching the live [ForegroundScanState].
final foregroundScanStateProvider = Provider<ForegroundScanState>((ref) {
  return ref.watch(foregroundScannerServiceProvider);
});
