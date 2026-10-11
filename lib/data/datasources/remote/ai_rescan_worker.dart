import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/hardware/notification_engine.dart';
import '../../../core/theme/app_preferences_provider.dart';
import '../../../domain/entities/document_type.dart';
import '../local/app_database.dart';
import 'gemini_document_extraction_service.dart';

/// Background Worker responsible for rate-limited, resilient AI extraction
/// of offline-imported documents flagged with `requiresAiScan == true`.
///
/// Strictly enforces a 60-second delay between processing individual documents
/// to protect free-tier Gemini API quotas.
class AiRescanWorker {
  static const String aiRescanTaskKey = 'ai_rescan_worker';

  /// Dispatches the background worker execution.
  /// Strictly selects ONE pending document, extracts its metadata via Gemini,
  /// updates the Drift database, and schedules the next one-off task with a
  /// 60-second delay if more documents remain in the queue.
  static Future<bool> executeWorker({
    AppDatabase? dbOverride,
    String? apiKeyOverride,
    bool skipScheduleNext = false,
  }) async {
    developer.log('[AiRescanWorker] Starting background AI rescan worker.');

    final db = dbOverride ?? AppDatabase();
    final bool ownsDb = dbOverride == null;

    try {
      // 0. Priority gating: Defer AI extraction if documents are pending in the sync queue
      final pendingQueue = await (db.select(db.syncQueue)..where((t) => t.action.equals('upload'))).get();

      if (pendingQueue.isNotEmpty) {
        developer.log('[AiRescanWorker] Found ${pendingQueue.length} upload task(s) in sync queue. Deferring AI scan.');
        if (!skipScheduleNext) {
          await scheduleRescan(initialDelay: const Duration(seconds: 30));
        }
        if (ownsDb) await db.close();
        return true;
      }

      // 1. Query for pending documents needing AI scan, ordered by oldest first
      final pendingDocs = await (db.select(db.vehicleDocuments)
            ..where((t) => t.requiresAiScan.equals(true) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
          .get();

      if (pendingDocs.isEmpty) {
        developer.log('[AiRescanWorker] No documents pending AI scan. Exiting gracefully.');
        if (ownsDb) await db.close();
        return true;
      }

      // 2. Pick strictly ONE document to enforce rate-limiting
      final docToProcess = pendingDocs.first;
      developer.log('[AiRescanWorker] Processing single document: ${docToProcess.id} ("${docToProcess.title}")');

      // 3. Obtain API key
      String? key = apiKeyOverride?.trim();
      if (key == null || key.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          key = prefs.getString(keyGeminiApiKey)?.trim();
        } catch (e) {
          developer.log('[AiRescanWorker] Error reading SharedPreferences for API key: $e');
        }
      }

      if (key == null || key.isEmpty) {
        developer.log('[AiRescanWorker] Gemini API key is missing. Cannot perform scan. Will retry later.');
        if (ownsDb) await db.close();
        return true;
      }

      // 4. Validate local file
      final localFile = File(docToProcess.localFilePath);
      if (!await localFile.exists()) {
        developer.log('[AiRescanWorker] Local file not found at ${docToProcess.localFilePath}. Clearing flag to prevent deadlock.');
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docToProcess.id))).write(
          const VehicleDocumentsCompanion(
            requiresAiScan: Value(false),
          ),
        );
      } else {
        // 5. Run Gemini Extraction with user draft reconciliation
        final extractionService = GeminiDocumentExtractionService(apiKey: key);
        final extracted = await extractionService.extractDetailsFromFile(
          localFile,
          userDraftTitle: docToProcess.title,
          userDraftCategory: docToProcess.category,
          userDraftExpiryDate: docToProcess.expiryDate != null
              ? DateTime.fromMillisecondsSinceEpoch(docToProcess.expiryDate!)
              : null,
        );

        if (extracted.isAiDetected) {
          developer.log('[AiRescanWorker] AI extraction successful for ${docToProcess.id}. Updating database.');

          // Merge visible fields
          Map<String, dynamic> mergedVisible = {};
          if (docToProcess.visibleFields.isNotEmpty) {
            try {
              mergedVisible = jsonDecode(docToProcess.visibleFields) as Map<String, dynamic>;
            } catch (_) {}
          }
          if (extracted.visibleFields.isNotEmpty) {
            mergedVisible.addAll(extracted.visibleFields);
          }

          final effectiveCategory = (extracted.category != null && extracted.category!.isNotEmpty)
              ? extracted.category!
              : docToProcess.category;

          final effectiveDocType = extracted.documentType?.value ??
              (extracted.category != null ? DocumentType.fromString(extracted.category!).value : docToProcess.documentType);

          final effectiveTitle = (extracted.title != null && extracted.title!.trim().isNotEmpty)
              ? extracted.title!.trim()
              : docToProcess.title;

          // When AI successfully detects the document, use AI-verified expiry date.
          // If the document has no expiration (e.g. Student ID, birth certificate, photo),
          // extracted.expiryDate is null, which properly clears any user-entered erroneous expiry date.
          final effectiveExpiry = extracted.expiryDate?.millisecondsSinceEpoch;

          final effectiveHidden = (extracted.hiddenContext != null && extracted.hiddenContext!.isNotEmpty)
              ? extracted.hiddenContext
              : docToProcess.hiddenContext;

          final effectiveRegNo = (extracted.vehicleRegNo != null && extracted.vehicleRegNo!.isNotEmpty)
              ? extracted.vehicleRegNo!
              : docToProcess.vehicleRegNo;

          final effectivePolicyNo = (extracted.policyNo != null && extracted.policyNo!.isNotEmpty)
              ? extracted.policyNo!
              : docToProcess.policyNo;

          await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docToProcess.id))).write(
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
                documentId: docToProcess.id,
                title: effectiveTitle,
                vehicleRegNo: effectiveRegNo,
                expiryDate: DateTime.fromMillisecondsSinceEpoch(effectiveExpiry),
              );
            } else if (docToProcess.expiryDate != null) {
              await notifEngine.cancelDocumentAlerts(docToProcess.id);
            }
          } catch (_) {}
        } else if (extracted.errorMessage == null) {
          // Extraction completed cleanly without errors, but no details recognized
          developer.log('[AiRescanWorker] AI scan found no metadata for ${docToProcess.id}. Clearing pending flag.');
          await (db.update(db.vehicleDocuments)..where((t) => t.id.equals(docToProcess.id))).write(
            const VehicleDocumentsCompanion(
              requiresAiScan: Value(false),
            ),
          );
        } else {
          // Temporary network failure or rate limit: retain requiresAiScan = true for next attempt
          developer.log('[AiRescanWorker] AI extraction temporary error: ${extracted.errorMessage}. Will retry on next cycle.');
        }
      }

      // 6. CRITICAL RATE LIMIT: Check if more documents remain pending
      final remainingDocs = await (db.select(db.vehicleDocuments)
            ..where((t) => t.requiresAiScan.equals(true)))
          .get();

      if (remainingDocs.isNotEmpty && !skipScheduleNext) {
        developer.log(
          '[AiRescanWorker] Rate limit active: ${remainingDocs.length} document(s) still pending. Scheduling next run with exactly 60 seconds delay.',
        );
        await scheduleRescan(initialDelay: const Duration(seconds: 60));
      } else {
        developer.log('[AiRescanWorker] AI scan queue is now empty. No further runs needed.');
      }

      if (ownsDb) await db.close();
      return true;
    } catch (e, stack) {
      developer.log('[AiRescanWorker] Background worker failed with error: $e', error: e, stackTrace: stack);
      if (ownsDb) await db.close();
      return false;
    }
  }

  static const String rescanUniqueWorkName = 'com.vehicledocs.ai_rescan_worker';

  /// Schedules a one-off background worker task with network constraint
  /// and an optional initial delay (default: immediate).
  static Future<void> scheduleRescan({Duration initialDelay = Duration.zero}) async {
    try {
      await Workmanager().registerOneOffTask(
        rescanUniqueWorkName,
        aiRescanTaskKey,
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      developer.log(
        '[AiRescanWorker] Registered one-off task "$aiRescanTaskKey" with delay ${initialDelay.inSeconds}s (requires NetworkType.connected).',
      );
    } catch (e) {
      developer.log('[AiRescanWorker] Could not register Workmanager task (e.g. desktop/test environment): $e');
    }
  }

  /// Checks if any documents have `requiresAiScan == true`. If so, schedules
  /// the very first rescan worker task to kick off the queue.
  static Future<void> scheduleRescanIfPending({AppDatabase? dbOverride}) async {
    final db = dbOverride ?? AppDatabase();
    final bool ownsDb = dbOverride == null;

    try {
      final pendingDocs = await (db.select(db.vehicleDocuments)
            ..where((t) => t.requiresAiScan.equals(true)))
          .get();

      if (pendingDocs.isNotEmpty) {
        developer.log('[AiRescanWorker] Found ${pendingDocs.length} pending document(s). Initiating AI queue.');
        await scheduleRescan();
      }
    } catch (e) {
      developer.log('[AiRescanWorker] scheduleRescanIfPending error: $e');
    } finally {
      if (ownsDb) await db.close();
    }
  }
}
