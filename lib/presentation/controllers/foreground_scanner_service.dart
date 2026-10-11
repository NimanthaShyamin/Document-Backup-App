import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hardware/notification_engine.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/datasources/remote/gemini_document_extraction_service.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import 'document_providers.dart';

/// Scanning status of the Global Foreground Scanner Queue.
enum ScanStatus {
  idle,
  scanning,
  waitingRateLimit,
  waitingBackup,
  offline,
}

/// State exposed to the UI representing the global sequential AI extraction queue.
class ForegroundScanState {
  final ScanStatus status;
  final bool isOnline;
  final String? activeDocumentId;
  final int baseSecondsRemaining; // Seconds until the NEXT document starts scanning
  final List<String> pendingQueueIds; // Pending document IDs in FIFO order
  final DateTime? lastScanCompletionTime;

  const ForegroundScanState({
    this.status = ScanStatus.idle,
    this.isOnline = true,
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
  /// - If offline: returns null (no countdown timer should run or be displayed).
  /// - Active document: returns 0.
  /// - 1st Queued Document (index 0): returns `baseSecondsRemaining` (ticking down from 60s).
  /// - Deep Queue Documents (index k): adds 60 seconds per position in the queue.
  int? getWaitSecondsFor(String docId) {
    if (!isOnline || status == ScanStatus.offline || status == ScanStatus.waitingBackup) return null;
    if (isScanning(docId)) return 0;

    // While ANY document is actively scanning, all other documents remain dormant without timers
    if (status == ScanStatus.scanning) return null;

    // When the previous AI scan is over and the rate-limit cooldown begins:
    // Only the NEXT document in line displays the 1-minute (60s) countdown
    if (status == ScanStatus.waitingRateLimit) {
      final nextDocId = activeDocumentId ?? (pendingQueueIds.isNotEmpty ? pendingQueueIds.first : null);
      if (docId == nextDocId) {
        return baseSecondsRemaining;
      }
      return null;
    }

    return null;
  }

  ForegroundScanState copyWith({
    ScanStatus? status,
    bool? isOnline,
    String? activeDocumentId,
    int? baseSecondsRemaining,
    List<String>? pendingQueueIds,
    DateTime? lastScanCompletionTime,
  }) {
    return ForegroundScanState(
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      activeDocumentId: activeDocumentId ?? this.activeDocumentId,
      baseSecondsRemaining: baseSecondsRemaining ?? this.baseSecondsRemaining,
      pendingQueueIds: pendingQueueIds ?? this.pendingQueueIds,
      lastScanCompletionTime: lastScanCompletionTime ?? this.lastScanCompletionTime,
    );
  }

  @override
  String toString() =>
      'ForegroundScanState(status: $status, online: $isOnline, activeId: $activeDocumentId, baseRemaining: $baseSecondsRemaining, queueLen: ${pendingQueueIds.length})';
}

/// Riverpod StateNotifier managing a Global Cooldown Queue for foreground AI scanning.
///
/// Rules:
/// 1. Offline Mode: All timers are stopped. No countdowns display.
/// 2. Going Online:
///    - 1st imported document scans IMMEDIATELY with NO timer (0s delay).
///    - 2nd imported document starts 1 min (60s) timer.
///    - Subsequent documents start with previous document delay + 1 min (120s, 180s...).
/// 3. If the app goes offline, ALL timers stop immediately until back online.
/// 4. When re-connected online, sequence resets with remaining pending docs.
class ForegroundScannerNotifier extends StateNotifier<ForegroundScanState> {
  final Ref _ref;
  final Connectivity _connectivity;
  final Future<bool> Function()? isOnlineChecker;

  /// Global timestamp tracking the completion of the last AI extraction across the entire app
  static DateTime? lastScanCompletionTime;

  Timer? _globalCooldownTimer;
  Completer<void>? _cooldownCompleter;
  bool _isLoopRunning = false;
  String? _forcedDocumentId;
  final Map<String, int> _scanAttempts = {};
  int _currentBaseRemaining = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  ProviderSubscription<AsyncValue<SyncEngineState>>? _syncEngineSubscription;

  ForegroundScannerNotifier(
    this._ref, {
    Connectivity? connectivity,
    this.isOnlineChecker,
  })  : _connectivity = connectivity ?? Connectivity(),
        super(const ForegroundScanState()) {
    _initialize();
  }

  void _initialize() {
    // 1. Listen to connectivity state changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      _handleConnectivityChanged(hasConnection);
    });

    // 2. Listen to Sync Engine state changes (e.g. SyncEngineOffline, SyncEngineSyncing)
    _syncEngineSubscription = _ref.listen<AsyncValue<SyncEngineState>>(
      syncEngineStateProvider,
      (previous, next) {
        final syncState = next.valueOrNull;
        if (syncState is SyncEngineOffline) {
          _setOffline();
        } else if (syncState is SyncEngineSyncing) {
          _setWaitingBackup();
        } else if (syncState is SyncEngineIdle || syncState is SyncEngineFailed) {
          _checkAndSetOnline();
        }
      },
      fireImmediately: false,
    );

    // 3. Listen to reactive vehicle documents
    _ref.listen<AsyncValue<List<VehicleDocument>>>(
      vehicleDocumentsStreamProvider,
      (previous, next) {
        next.whenData((docs) {
          _onDocumentsChanged(docs);
        });
      },
      fireImmediately: true,
    );

    // 4. Initial network check
    Future.microtask(() => _checkAndSetOnline());
  }

  @override
  void dispose() {
    _stopGlobalTimer();
    _connectivitySubscription?.cancel();
    _syncEngineSubscription?.close();
    super.dispose();
  }

  void _stopGlobalTimer() {
    _globalCooldownTimer?.cancel();
    _globalCooldownTimer = null;
  }

  Future<void> _handleConnectivityChanged(bool hasConnection) async {
    if (!hasConnection) {
      _setOffline();
    } else {
      await _checkAndSetOnline();
    }
  }

  void _setOffline() {
    if (!state.isOnline && state.status == ScanStatus.offline) return;
    developer.log('[ForegroundScanner] Device / app went offline. Halting all scanning timers.');

    _stopGlobalTimer();
    if (_cooldownCompleter != null && !_cooldownCompleter!.isCompleted) {
      _cooldownCompleter!.complete();
    }
    _currentBaseRemaining = 0;
    _isLoopRunning = false;

    state = state.copyWith(
      isOnline: false,
      status: ScanStatus.offline,
      baseSecondsRemaining: 0,
      activeDocumentId: null,
    );
  }

  void _setWaitingBackup() {
    if (!state.isOnline) return;
    developer.log('[ForegroundScanner] Cloud backup active. Pausing AI scanning timers.');
    _stopGlobalTimer();
    if (_cooldownCompleter != null && !_cooldownCompleter!.isCompleted) {
      _cooldownCompleter!.complete();
    }
    _currentBaseRemaining = 0;
    state = state.copyWith(
      status: ScanStatus.waitingBackup,
      baseSecondsRemaining: 0,
    );
  }

  Future<void> _checkAndSetOnline() async {
    final online = await _checkIsOnline();
    if (online) {
      if (!state.isOnline || state.status == ScanStatus.offline || state.status == ScanStatus.waitingBackup) {
        developer.log('[ForegroundScanner] Device / app is online and backup idle. Resuming sequential queue.');
        state = state.copyWith(
          isOnline: true,
          status: ScanStatus.idle,
        );
        if (!_isLoopRunning) {
          _startQueueLoop();
        }
      }
    } else {
      _setOffline();
    }
  }

  Future<bool> _checkIsOnline() async {
    if (isOnlineChecker != null) {
      return await isOnlineChecker!();
    }

    try {
      final syncState = _ref.read(syncEngineStateProvider).valueOrNull;
      if (syncState is SyncEngineOffline) {
        return false;
      }

      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }

      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return results.any((r) => r != ConnectivityResult.none);
      }

      final lookup = await InternetAddress.lookup('generativelanguage.googleapis.com')
          .timeout(const Duration(seconds: 2), onTimeout: () => []);
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Triggered whenever the reactive document stream updates.
  void _onDocumentsChanged(List<VehicleDocument> docs) {
    final pending = docs.where((d) => d.requiresAiScan).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final pendingIds = pending
        .where((d) => d.id != state.activeDocumentId)
        .map((d) => d.id)
        .toList();

    state = state.copyWith(pendingQueueIds: pendingIds);

    if (pending.isEmpty) {
      if (state.status != ScanStatus.idle && state.isOnline && state.status != ScanStatus.waitingBackup) {
        _stopGlobalTimer();
        state = state.copyWith(
          status: ScanStatus.idle,
          baseSecondsRemaining: 0,
          activeDocumentId: null,
        );
      }
      return;
    }

    // Only start loop if the app is online!
    if (state.isOnline && !_isLoopRunning) {
      _startQueueLoop();
    }
  }

  /// Manual override: Bypasses queue wait time and processes [documentId] immediately.
  Future<void> forceScan(String documentId) async {
    developer.log('[ForegroundScanner] Force Scan requested for document: $documentId');

    if (!state.isOnline) {
      developer.log('[ForegroundScanner] Cannot force scan while offline.');
      return;
    }

    if (state.isScanning(documentId)) {
      developer.log('[ForegroundScanner] Document $documentId is already scanning.');
      return;
    }

    _forcedDocumentId = documentId;
    _currentBaseRemaining = 0;
    _stopGlobalTimer();

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

  void _startTickingTimer(int seconds) {
    _stopGlobalTimer();
    _currentBaseRemaining = seconds;
    _cooldownCompleter = Completer<void>();

    state = state.copyWith(baseSecondsRemaining: seconds);

    _globalCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isOnline) {
        timer.cancel();
        if (_cooldownCompleter != null && !_cooldownCompleter!.isCompleted) {
          _cooldownCompleter!.complete();
        }
        return;
      }

      _currentBaseRemaining--;
      if (_currentBaseRemaining <= 0) {
        _currentBaseRemaining = 0;
        timer.cancel();
        if (_cooldownCompleter != null && !_cooldownCompleter!.isCompleted) {
          _cooldownCompleter!.complete();
        }
      }

      state = state.copyWith(baseSecondsRemaining: _currentBaseRemaining);
    });
  }

  /// The core single-loop sequential executor.
  Future<void> _runSequentialQueueLoop() async {
    if (_isLoopRunning) return;
    _isLoopRunning = true;

    developer.log('[ForegroundScanner] Starting global sequential queue loop.');

    try {
      while (state.isOnline) {
        // Priority 1: Delay AI scan while cloud backup is actively syncing
        final syncState = _ref.read(syncEngineStateProvider).valueOrNull;
        final syncRepo = _ref.read(syncRepositoryProvider);
        if (syncState is SyncEngineSyncing || syncRepo.isReconciling) {
          developer.log('[ForegroundScanner] Sync engine is active. Pausing AI scan until backup ends.');
          _stopGlobalTimer();
          state = state.copyWith(status: ScanStatus.waitingBackup, baseSecondsRemaining: 0);
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        final db = _ref.read(appDatabaseProvider);

        // Priority 2: Delay AI scan if documents are pending upload and Drive sync is configured
        final authService = _ref.read(googleAuthServiceProvider);
        if (authService.isSignedIn && syncState is! SyncEngineFailed) {
          final pendingBackups = await (db.select(db.vehicleDocuments)
                ..where((t) => t.syncStatus.isIn(['pending_upload', 'queued_upload']) & t.isDeleted.equals(false)))
              .get();

          if (pendingBackups.isNotEmpty) {
            developer.log('[ForegroundScanner] Found ${pendingBackups.length} document(s) pending backup. Waiting for backup.');
            _stopGlobalTimer();
            state = state.copyWith(status: ScanStatus.waitingBackup, baseSecondsRemaining: 0);
            unawaited(syncRepo.reconcileStartupDelta());
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }

        final apiKey = _ref.read(geminiApiKeyProvider);

        if (apiKey.trim().isEmpty) {
          developer.log('[ForegroundScanner] Gemini API key not configured. Halting foreground queue.');
          _stopGlobalTimer();
          state = state.copyWith(status: ScanStatus.idle, baseSecondsRemaining: 0);
          break;
        }

        // Query pending documents from Drift DB, ordered strictly by oldest imported sequence first
        final pendingDocs = await (db.select(db.vehicleDocuments)
              ..where((t) => t.requiresAiScan.equals(true) & t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
            .get();

        if (pendingDocs.isEmpty) {
          developer.log('[ForegroundScanner] No more pending documents. Queue is idle.');
          _stopGlobalTimer();
          state = state.copyWith(
            status: ScanStatus.idle,
            baseSecondsRemaining: 0,
            activeDocumentId: null,
            pendingQueueIds: [],
          );
          break;
        }

        // Verify still online before processing
        if (!state.isOnline || !await _checkIsOnline()) {
          _setOffline();
          break;
        }

        // Determine which document to process: forced override has top priority
        VehicleDocumentData docToProcess;
        if (_forcedDocumentId != null) {
          docToProcess = pendingDocs.firstWhere(
            (d) => d.id == _forcedDocumentId,
            orElse: () => pendingDocs.first,
          );
          _forcedDocumentId = null;
        } else {
          docToProcess = pendingDocs.first;
        }

        final remainingIds = pendingDocs
            .where((d) => d.id != docToProcess.id)
            .map((d) => d.id)
            .toList();

        // Actively scanning: NO timer runs during scan!
        _stopGlobalTimer();
        _currentBaseRemaining = 0;

        state = state.copyWith(
          status: ScanStatus.scanning,
          activeDocumentId: docToProcess.id,
          baseSecondsRemaining: 0,
          pendingQueueIds: remainingIds,
        );

        developer.log('[ForegroundScanner] Actively scanning: ${docToProcess.id} ("${docToProcess.title}")');
        try {
          await _executeScan(db, apiKey, docToProcess);
        } finally {
          state = state.copyWith(activeDocumentId: null);
        }

        // If app went offline during scan, break out cleanly
        if (!state.isOnline) break;

        // Scan for current document is now OVER!
        // The next document in line begins its 1-minute (60s) rate limit cooldown timer now.
        if (remainingIds.isNotEmpty) {
          final nextDocId = remainingIds.first;
          developer.log('[ForegroundScanner] Previous AI scan is over. Starting 60s cooldown for next document: $nextDocId');

          state = state.copyWith(
            status: ScanStatus.waitingRateLimit,
            activeDocumentId: nextDocId,
            baseSecondsRemaining: 60,
            pendingQueueIds: remainingIds,
          );

          _startTickingTimer(60);

          if (_cooldownCompleter != null && !_cooldownCompleter!.isCompleted) {
            await _cooldownCompleter!.future;
          }
        }
      }
    } catch (e, stack) {
      developer.log('[ForegroundScanner] Error in queue loop: $e', error: e, stackTrace: stack);
      if (state.isOnline) {
        state = state.copyWith(status: ScanStatus.idle);
      }
    } finally {
      _isLoopRunning = false;
      developer.log('[ForegroundScanner] Global sequential queue loop finished.');
    }
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
      final extracted = await extractionService.extractDetailsFromFile(
        file,
        userDraftTitle: docData.title,
        userDraftCategory: docData.category,
        userDraftExpiryDate: docData.expiryDate != null
            ? DateTime.fromMillisecondsSinceEpoch(docData.expiryDate!)
            : null,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => ExtractedDocumentDetails.error('Scan timed out after 90 seconds.'),
      );

      if (extracted.isAiDetected) {
        developer.log('[ForegroundScanner] AI Scan successful for ${docData.id}. Updating database.');
        _scanAttempts.remove(docData.id);

        final effectiveCategory = (extracted.category != null && extracted.category!.isNotEmpty)
            ? extracted.category!
            : docData.category;

        final isPhoto = effectiveCategory == 'photo' || effectiveCategory == 'image';

        Map<String, dynamic> mergedVisible = {};
        if (!isPhoto && docData.visibleFields.isNotEmpty) {
          try {
            mergedVisible = jsonDecode(docData.visibleFields) as Map<String, dynamic>;
          } catch (_) {}
        }
        if (extracted.visibleFields.isNotEmpty) {
          mergedVisible.addAll(extracted.visibleFields);
        }

        final effectiveDocType = extracted.documentType?.value ??
            (extracted.category != null ? DocumentType.fromString(extracted.category!).value : docData.documentType);

        final effectiveTitle = (extracted.title != null && extracted.title!.trim().isNotEmpty)
            ? extracted.title!.trim()
            : docData.title;

        // When AI successfully detects the document, use AI-verified expiry date.
        // If the document has no expiration (e.g. Student ID, birth certificate, photo),
        // extracted.expiryDate is null, which properly clears any user-entered erroneous expiry date.
        final effectiveExpiry = isPhoto ? null : extracted.expiryDate?.millisecondsSinceEpoch;

        final effectiveHidden = (extracted.hiddenContext != null && extracted.hiddenContext!.isNotEmpty)
            ? extracted.hiddenContext
            : docData.hiddenContext;

        final String effectiveRegNo = isPhoto
            ? 'General'
            : ((extracted.vehicleRegNo != null && extracted.vehicleRegNo!.isNotEmpty)
                ? extracted.vehicleRegNo!
                : (docData.vehicleRegNo.isNotEmpty ? docData.vehicleRegNo : 'General'));

        final String? effectivePolicyNo = isPhoto
            ? null
            : ((extracted.policyNo != null && extracted.policyNo!.isNotEmpty)
                ? extracted.policyNo!
                : docData.policyNo);

        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
          VehicleDocumentsCompanion(
            category: Value(effectiveCategory),
            documentType: Value(effectiveDocType),
            title: Value(effectiveTitle),
            vehicleRegNo: Value(effectiveRegNo),
            policyNo: Value(effectivePolicyNo),
            expiryDate: Value(effectiveExpiry),
            visibleFields: Value(jsonEncode(mergedVisible)),
            hiddenContext: Value(effectiveHidden),
            requiresAiScan: const Value(false),
            lastModifiedTimestamp: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

        try {
          final notifEngine = LocalNotificationEngine.instance;
          if (effectiveExpiry != null) {
            await notifEngine.scheduleExpiryAlerts(
              documentId: docData.id,
              title: effectiveTitle,
              vehicleRegNo: effectiveRegNo,
              expiryDate: DateTime.fromMillisecondsSinceEpoch(effectiveExpiry),
            );
          } else if (docData.expiryDate != null) {
            await notifEngine.cancelDocumentAlerts(docData.id);
          }
        } catch (_) {}
      } else if (extracted.errorMessage == null) {
        developer.log('[ForegroundScanner] Scan completed with no metadata detected for ${docData.id}. Clearing flag.');
        _scanAttempts.remove(docData.id);
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docData.id))).write(
          const VehicleDocumentsCompanion(requiresAiScan: Value(false)),
        );
      } else if (extracted.errorMessage != null &&
          (extracted.errorMessage!.contains('quota exceeded') ||
              extracted.errorMessage!.contains('429') ||
              extracted.errorMessage!.contains('RESOURCE_EXHAUSTED'))) {
        developer.log('[ForegroundScanner] Rate limit hit for ${docData.id}. Retaining scan flag for next cycle.');
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
    } on SocketException catch (e) {
      developer.log('[ForegroundScanner] SocketException scanning ${docData.id}: $e. Marking offline.');
      _setOffline();
    } on HttpException catch (e) {
      developer.log('[ForegroundScanner] HttpException scanning ${docData.id}: $e. Marking offline.');
      _setOffline();
    } catch (e, stack) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') ||
          errStr.contains('network') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection refused') ||
          errStr.contains('connection closed') ||
          errStr.contains('handshake') ||
          errStr.contains('clientexception')) {
        developer.log('[ForegroundScanner] Network error during scan of ${docData.id}: $e. Halting queue.');
        _setOffline();
        return;
      }

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
