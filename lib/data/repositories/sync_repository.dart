import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../../core/constants/drive_constants.dart';
import '../../core/storage/file_storage_manager.dart';
import '../../core/utils/crypto_utils.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/repositories/i_sync_queue_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/drive_sync_service.dart';
import '../datasources/remote/google_auth_service.dart';

/// Result summary of an end-to-end cloud sync verification test probe.
class VerificationProbeResult {
  final String documentId;
  final String localPath;
  final String? driveFileId;
  final String checksum;
  final bool isSuccess;
  final String? errorMessage;
  final DateTime timestamp;

  const VerificationProbeResult({
    required this.documentId,
    required this.localPath,
    this.driveFileId,
    required this.checksum,
    required this.isSuccess,
    this.errorMessage,
    required this.timestamp,
  });
}

/// Central repository managing offline-first local storage tracking and Google Drive AppData synchronization.
/// Tracks three core sync states: `synced`, `pending_upload`, and `pending_delete`.
/// Automatically triggers delta reconciliation upon internet connectivity restoration.
class SyncRepository implements ISyncQueueRepository {
  final AppDatabase _db;
  final DriveSyncService _driveService;
  final FileStorageManager _storageManager;
  final Connectivity _connectivity;

  final StreamController<SyncEngineState> _syncStateController =
      StreamController<SyncEngineState>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isReconciling = false;

  SyncRepository({
    required AppDatabase db,
    required DriveSyncService driveService,
    required FileStorageManager storageManager,
    Connectivity? connectivity,
  })  : _db = db,
        _driveService = driveService,
        _storageManager = storageManager,
        _connectivity = connectivity ?? Connectivity() {
    _initializeConnectivityListener();
  }

  @override
  Stream<SyncEngineState> get syncStateStream => _syncStateController.stream;

  /// Underlying DriveSyncService instance.
  DriveSyncService get driveService => _driveService;

  /// Listens to network state transitions and triggers non-blocking reconciliation when back online.
  void _initializeConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        developer.log('[SyncRepository] Internet connection restored. Initiating reconciliation.');
        unawaited(reconcile());
      } else {
        developer.log('[SyncRepository] Internet connection lost. Device is offline.');
        _syncStateController.add(const SyncEngineState.offline());
      }
    });
  }

  /// Marks a document for upload and triggers a non-blocking queue sync.
  @override
  Future<void> enqueueUpload(String documentId) async {
    developer.log('[SyncRepository] Document $documentId marked as pending_upload.');

    // 1. Update local database sync state
    await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(documentId))).write(
      const VehicleDocumentsCompanion(syncStatus: Value('pending_upload')),
    );

    // 2. Insert into FIFO sync queue table
    await _db.into(_db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            documentId: documentId,
            action: 'upload',
            retryCount: const Value(0),
            nextRetryAt: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // 3. Trigger immediate non-blocking reconciliation
    unawaited(processQueue());
  }

  /// Marks a document for remote deletion and enqueues cloud cleanup.
  @override
  Future<void> enqueueDelete(String documentId, String? driveFileId) async {
    developer.log('[SyncRepository] Document $documentId marked as pending_delete.');

    // 1. Update local record status if it still exists
    await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(documentId))).write(
      const VehicleDocumentsCompanion(syncStatus: Value('pending_delete')),
    );

    // 2. Insert deletion task in FIFO queue
    await _db.into(_db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            documentId: documentId,
            action: 'delete',
            driveFileId: Value(driveFileId),
            retryCount: const Value(0),
            nextRetryAt: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // 3. Trigger immediate non-blocking execution
    unawaited(processQueue());
  }

  /// Compatibility alias for startup delta reconciliation.
  @override
  Future<void> reconcileStartupDelta() => reconcile(interactiveAuth: false);

  /// **Non-Blocking Reconciliation Engine:**
  /// 1. Verifies internet connectivity.
  /// 2. Verifies authentication status (silent auth or interactive if requested).
  /// 3. Uploads all local documents marked as `pending_upload`.
  /// 4. Deletes all remote documents marked as `pending_delete`.
  /// 5. Queries cloud AppData (`'appDataFolder' in parents and trashed = false`).
  /// 6. Compares cloud AppData file IDs against local records and downloads any missing documents.
  /// 7. Resolves any timestamp-based delta conflicts between cloud and local states.
  Future<void> reconcile({bool interactiveAuth = false}) async {
    if (_isReconciling) {
      developer.log('[SyncRepository] Reconciliation already in progress. Skipping duplicate run.');
      return;
    }

    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      developer.log('[SyncRepository] Cannot reconcile: Device is offline.');
      _syncStateController.add(const SyncEngineState.offline());
      return;
    }

    // Verify authentication status before attempting cloud reconciliation
    if (!_driveService.authService.isSignedIn) {
      final account = await _driveService.authService.signInSilently();
      if (account == null) {
        if (!interactiveAuth) {
          developer.log('[SyncRepository] Cloud reconciliation skipped: Google Drive is not connected.');
          _syncStateController.add(const SyncEngineState.idle());
          return;
        } else {
          // Explicit user trigger: initiate sign-in
          await _driveService.authService.signIn();
        }
      }
    }

    _isReconciling = true;
    _syncStateController.add(
      const SyncEngineState.syncing(progress: 0.05, currentAction: 'Initiating AppData reconciliation...'),
    );

    try {
      // Step A: Process all pending uploads
      await _uploadAllPendingDocuments();

      // Step B: Process all pending deletes
      await _deleteAllPendingDocuments();

      // Step C: Reconcile Cloud AppData vs Local Database
      _syncStateController.add(
        const SyncEngineState.syncing(progress: 0.35, currentAction: 'Querying Google Drive AppData...'),
      );

      final remoteBackups = await _driveService.listCloudBackups();
      final remoteMap = {for (final f in remoteBackups) f.documentId: f};

      final localDocs = await _db.select(_db.vehicleDocuments).get();
      final localMap = {for (final d in localDocs) d.id: d};

      int totalItems = remoteBackups.length + localDocs.length;
      int processedCount = 0;

      // 1. Detect and download remote documents missing on local storage
      for (final remote in remoteBackups) {
        processedCount++;
        final progress = 0.35 + (0.35 * (processedCount / (totalItems == 0 ? 1 : totalItems)));
        _syncStateController.add(
          SyncEngineState.syncing(
            progress: progress,
            currentAction: 'Synchronizing ${remote.name}...',
          ),
        );

        final localDoc = localMap[remote.documentId];
        if (localDoc == null) {
          // Document exists on Drive AppData but is completely missing locally -> Download
          developer.log('[SyncRepository] Discovered missing document in AppData: ${remote.documentId}. Downloading...');
          await _downloadRemoteDocument(remote);
        } else {
          // Document exists locally and remotely: evaluate checksum and timestamps
          if (localDoc.fileChecksumSha256 == remote.checksumSha256) {
            if (localDoc.syncStatus != 'synced' || localDoc.driveFileId != remote.driveFileId) {
              await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(localDoc.id))).write(
                VehicleDocumentsCompanion(
                  driveFileId: Value(remote.driveFileId),
                  syncStatus: const Value('synced'),
                ),
              );
            }
          } else {
            // Checksum mismatch: conflict resolution
            if (remote.clientModified.millisecondsSinceEpoch > localDoc.lastModifiedTimestamp) {
              developer.log('[SyncRepository] Remote document ${localDoc.id} is newer. Downloading update...');
              await _downloadRemoteDocument(remote);
            } else if (localDoc.lastModifiedTimestamp > remote.clientModified.millisecondsSinceEpoch) {
              developer.log('[SyncRepository] Local document ${localDoc.id} is newer. Scheduling upload...');
              await enqueueUpload(localDoc.id);
            }
          }
        }
      }

      // Step D: Drain FIFO retry queue if any scheduled retries remain
      await processQueue();

      _syncStateController.add(const SyncEngineState.idle());
      developer.log('[SyncRepository] Reconciliation completed successfully.');
    } catch (e, stack) {
      developer.log('[SyncRepository] Reconciliation error', error: e, stackTrace: stack);
      _syncStateController.add(SyncEngineState.failed(error: e.toString()));
      if (interactiveAuth) rethrow;
    } finally {
      _isReconciling = false;
    }
  }

  /// Creates a dummy test file in local sandboxed storage, flags it as `pending_upload`,
  /// and immediately executes upload reconciliation to Google Drive `appDataFolder` to verify
  /// OAuth token and Drive REST API permissions end-to-end.
  Future<VerificationProbeResult> triggerEndToEndVerification() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final verificationId = 'verify_$timestamp';
    final targetPath = await _storageManager.generatePath(verificationId, 'txt');
    final dummyFile = File(targetPath);

    final content = 'Vehicle Document Vault - E2E Verification Sync Probe\n'
        'Timestamp: ${DateTime.now().toUtc().toIso8601String()}\n'
        'Probe ID: $verificationId\n'
        'OAuth Client ID: ${GoogleAuthService.defaultClientId}\n'
        'Target Scope: ${GoogleAuthService.driveAppDataScope}\n'
        'Sandbox Directory: ${DriveConstants.vaultDirectory}/${DriveConstants.documentsSubdirectory}\n'
        'Integrity: SHA-256 Verified\n';

    await dummyFile.writeAsString(content);
    final checksum = await CryptoUtils.computeSha256(dummyFile);

    try {
      // 1. Insert dummy record into vehicleDocuments as pending_upload
      await _db.into(_db.vehicleDocuments).insertOnConflictUpdate(
            VehicleDocumentsCompanion.insert(
              id: verificationId,
              documentType: 'custom',
              title: 'E2E Verification Probe ($verificationId)',
              vehicleRegNo: 'VERIFY-E2E',
              policyNo: const Value('PROBE-SYNC-OK'),
              expiryDate: Value(timestamp + const Duration(days: 30).inMilliseconds),
              localFilePath: targetPath,
              driveFileId: const Value(null),
              fileChecksumSha256: checksum,
              syncStatus: 'pending_upload',
              lastModifiedTimestamp: timestamp,
              createdAt: timestamp,
            ),
          );

      // 2. Insert into FIFO sync queue
      await _db.into(_db.syncQueue).insertOnConflictUpdate(
            SyncQueueCompanion.insert(
              documentId: verificationId,
              action: 'upload',
              retryCount: const Value(0),
              nextRetryAt: timestamp,
              createdAt: timestamp,
            ),
          );

      // 3. Directly upload to verify permissions immediately & accurately
      final driveFileId = await _driveService.uploadFile(
        localFile: dummyFile,
        documentId: verificationId,
        documentType: 'custom',
        vehicleRegNo: 'VERIFY-E2E',
        policyNo: 'PROBE-SYNC-OK',
        expiryDate: DateTime.fromMillisecondsSinceEpoch(timestamp + const Duration(days: 30).inMilliseconds),
        checksumSha256: checksum,
        lastModifiedTimestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        customMimeType: 'text/plain',
      );

      // 4. Update status in local database
      await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(verificationId))).write(
        VehicleDocumentsCompanion(
          driveFileId: Value(driveFileId),
          syncStatus: const Value('synced'),
        ),
      );

      // Clean up queue task
      await (_db.delete(_db.syncQueue)..where((t) => t.documentId.equals(verificationId))).go();

      developer.log('[SyncRepository] E2E verification probe succeeded. Remote Drive File ID: $driveFileId');

      return VerificationProbeResult(
        documentId: verificationId,
        localPath: targetPath,
        driveFileId: driveFileId,
        checksum: checksum,
        isSuccess: true,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      developer.log('[SyncRepository] E2E verification probe failed', error: e, stackTrace: stack);
      // Mark as sync_failed in SQLite
      await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(verificationId))).write(
        const VehicleDocumentsCompanion(
          syncStatus: Value('sync_failed'),
        ),
      );

      return VerificationProbeResult(
        documentId: verificationId,
        localPath: targetPath,
        checksum: checksum,
        isSuccess: false,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Creates a dummy test probe file and enqueues it as pending_upload without immediate upload,
  /// enabling background WorkManager worker verification.
  Future<VerificationProbeResult> createVerificationProbeOnly() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final verificationId = 'verify_bg_$timestamp';
    final targetPath = await _storageManager.generatePath(verificationId, 'txt');
    final dummyFile = File(targetPath);

    final content = 'Vehicle Document Vault - Background Sync Probe\n'
        'Timestamp: ${DateTime.now().toUtc().toIso8601String()}\n'
        'Probe ID: $verificationId\n'
        'OAuth Client ID: ${GoogleAuthService.defaultClientId}\n'
        'Target Scope: ${GoogleAuthService.driveAppDataScope}\n'
        'Sandbox Directory: ${DriveConstants.vaultDirectory}/${DriveConstants.documentsSubdirectory}\n'
        'Integrity: SHA-256 Verified\n';

    await dummyFile.writeAsString(content);
    final checksum = await CryptoUtils.computeSha256(dummyFile);

    await _db.into(_db.vehicleDocuments).insertOnConflictUpdate(
          VehicleDocumentsCompanion.insert(
            id: verificationId,
            documentType: 'custom',
            title: 'Background Probe ($verificationId)',
            vehicleRegNo: 'VERIFY-BG',
            policyNo: const Value('BG-PROBE-001'),
            expiryDate: Value(timestamp + const Duration(days: 30).inMilliseconds),
            localFilePath: targetPath,
            driveFileId: const Value(null),
            fileChecksumSha256: checksum,
            syncStatus: 'pending_upload',
            lastModifiedTimestamp: timestamp,
            createdAt: timestamp,
          ),
        );

    await _db.into(_db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            documentId: verificationId,
            action: 'upload',
            retryCount: const Value(0),
            nextRetryAt: timestamp,
            createdAt: timestamp,
          ),
        );

    return VerificationProbeResult(
      documentId: verificationId,
      localPath: targetPath,
      checksum: checksum,
      isSuccess: true,
      timestamp: DateTime.now(),
    );
  }

  /// Uploads all documents currently marked as `pending_upload` or `queued_upload`.
  Future<void> _uploadAllPendingDocuments() async {
    final pendingDocs = await (_db.select(_db.vehicleDocuments)
          ..where((t) => t.syncStatus.isIn(['pending_upload', 'queued_upload'])))
        .get();

    for (final doc in pendingDocs) {
      try {
        final localFile = File(doc.localFilePath);
        if (!await localFile.exists()) {
          developer.log('[SyncRepository] Local file missing for upload: ${doc.localFilePath}. Skipping.');
          continue;
        }

        final driveId = await _driveService.uploadFile(
          localFile: localFile,
          documentId: doc.id,
          documentType: doc.documentType,
          vehicleRegNo: doc.vehicleRegNo,
          policyNo: doc.policyNo,
          expiryDate: doc.expiryDate != null ? DateTime.fromMillisecondsSinceEpoch(doc.expiryDate!) : null,
          checksumSha256: doc.fileChecksumSha256,
          lastModifiedTimestamp: DateTime.fromMillisecondsSinceEpoch(doc.lastModifiedTimestamp),
        );

        // Mark as synced
        await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(doc.id))).write(
          VehicleDocumentsCompanion(
            driveFileId: Value(driveId),
            syncStatus: const Value('synced'),
          ),
        );

        // Clean up any corresponding queue tasks
        await (_db.delete(_db.syncQueue)..where((t) => t.documentId.equals(doc.id))).go();
        developer.log('[SyncRepository] Successfully synced document ${doc.id} with Drive ID $driveId');
      } catch (e) {
        developer.log('[SyncRepository] Failed to upload pending document ${doc.id}: $e');
      }
    }
  }

  /// Deletes all documents currently marked as `pending_delete` or `queued_delete`.
  Future<void> _deleteAllPendingDocuments() async {
    final pendingDeletes = await (_db.select(_db.vehicleDocuments)
          ..where((t) => t.syncStatus.isIn(['pending_delete', 'queued_delete'])))
        .get();

    for (final doc in pendingDeletes) {
      try {
        if (doc.driveFileId != null) {
          await _driveService.deleteRemoteFile(doc.driveFileId!);
        }
        await _storageManager.deleteDocumentFolder(doc.id);
        await (_db.delete(_db.vehicleDocuments)..where((t) => t.id.equals(doc.id))).go();
        await (_db.delete(_db.syncQueue)..where((t) => t.documentId.equals(doc.id))).go();
        developer.log('[SyncRepository] Deleted pending document ${doc.id}');
      } catch (e) {
        developer.log('[SyncRepository] Failed to delete document ${doc.id}: $e');
      }
    }
  }

  /// Downloads a remote document from Google Drive AppData into sandboxed local storage and registers in SQLite.
  Future<void> _downloadRemoteDocument(dynamic remote) async {
    final fileExt = remote.name.contains('.') ? remote.name.split('.').last : 'dat';
    final targetPath = await _storageManager.generatePath(remote.documentId, fileExt);
    final targetFile = File(targetPath);

    // Save temporary stub in SQLite to ensure atomic tracking
    await _db.into(_db.vehicleDocuments).insertOnConflictUpdate(
          VehicleDocumentsCompanion.insert(
            id: remote.documentId,
            documentType: remote.documentType,
            title: remote.name,
            vehicleRegNo: remote.vehicleRegNo,
            policyNo: Value(remote.policyNo),
            expiryDate: Value(remote.expiryDate?.millisecondsSinceEpoch),
            localFilePath: targetPath,
            driveFileId: Value(remote.driveFileId),
            fileChecksumSha256: remote.checksumSha256,
            syncStatus: 'download_pending',
            lastModifiedTimestamp: remote.clientModified.millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // Download file contents with checksum validation
    await _driveService.downloadFile(
      fileId: remote.driveFileId,
      targetFile: targetFile,
      expectedSha256: remote.checksumSha256,
    );

    // Update status to synced
    await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(remote.documentId))).write(
      const VehicleDocumentsCompanion(syncStatus: Value('synced')),
    );

    developer.log('[SyncRepository] Download and verification complete for ${remote.documentId}');
  }

  /// Processes queued background sync tasks with exponential backoff and randomized jitter.
  @override
  Future<void> processQueue() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final pendingTasks = await (_db.select(_db.syncQueue)
          ..where((t) => t.nextRetryAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.queueId, mode: OrderingMode.asc)]))
        .get();

    if (pendingTasks.isEmpty) {
      return;
    }

    for (final task in pendingTasks) {
      try {
        await _executeQueueTask(task);
        // Remove successfully executed task
        await (_db.delete(_db.syncQueue)..where((t) => t.queueId.equals(task.queueId))).go();
      } catch (e) {
        developer.log('[SyncRepository] Task ${task.queueId} failed: $e');
        await _handleQueueTaskFailure(task, e.toString());
      }
    }
  }

  Future<void> _executeQueueTask(SyncQueueData task) async {
    switch (task.action) {
      case 'upload':
        final doc = await (_db.select(_db.vehicleDocuments)
              ..where((t) => t.id.equals(task.documentId)))
            .getSingleOrNull();

        if (doc == null) return;

        final driveId = await _driveService.uploadFile(
          localFile: File(doc.localFilePath),
          documentId: doc.id,
          documentType: doc.documentType,
          vehicleRegNo: doc.vehicleRegNo,
          policyNo: doc.policyNo,
          expiryDate: doc.expiryDate != null ? DateTime.fromMillisecondsSinceEpoch(doc.expiryDate!) : null,
          checksumSha256: doc.fileChecksumSha256,
          lastModifiedTimestamp: DateTime.fromMillisecondsSinceEpoch(doc.lastModifiedTimestamp),
        );

        await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(doc.id))).write(
          VehicleDocumentsCompanion(
            driveFileId: Value(driveId),
            syncStatus: const Value('synced'),
          ),
        );
        break;

      case 'download':
        final doc = await (_db.select(_db.vehicleDocuments)
              ..where((t) => t.id.equals(task.documentId)))
            .getSingleOrNull();

        if (doc == null || task.driveFileId == null) return;

        await _driveService.downloadFile(
          fileId: task.driveFileId!,
          targetFile: File(doc.localFilePath),
          expectedSha256: doc.fileChecksumSha256,
        );

        await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(doc.id))).write(
          const VehicleDocumentsCompanion(syncStatus: Value('synced')),
        );
        break;

      case 'delete':
        if (task.driveFileId != null) {
          await _driveService.deleteRemoteFile(task.driveFileId!);
        }
        await _storageManager.deleteDocumentFolder(task.documentId);
        await (_db.delete(_db.vehicleDocuments)..where((t) => t.id.equals(task.documentId))).go();
        break;
    }
  }

  Future<void> _handleQueueTaskFailure(SyncQueueData task, String error) async {
    const maxRetries = 5;
    final nextRetryCount = task.retryCount + 1;

    if (nextRetryCount >= maxRetries) {
      developer.log('[SyncRepository] Max retries exceeded for task ${task.queueId}. Marking as sync_failed.');
      await (_db.delete(_db.syncQueue)..where((t) => t.queueId.equals(task.queueId))).go();
      await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(task.documentId))).write(
        const VehicleDocumentsCompanion(syncStatus: Value('sync_failed')),
      );
      return;
    }

    // Exponential backoff: 5s * 2^retry + jitter (0-2000ms), clamped at 15 minutes (900,000ms)
    final randomJitter = Random().nextDouble() * 2000;
    final backoffMs = (5000 * pow(2, task.retryCount)).toInt() + randomJitter.toInt();
    final clampedBackoff = min(backoffMs, 900000);
    final nextRetryTimestamp = DateTime.now().millisecondsSinceEpoch + clampedBackoff;

    await (_db.update(_db.syncQueue)..where((t) => t.queueId.equals(task.queueId))).write(
      SyncQueueCompanion(
        retryCount: Value(nextRetryCount),
        lastAttempt: Value(DateTime.now().millisecondsSinceEpoch),
        nextRetryAt: Value(nextRetryTimestamp),
        errorMessage: Value(error),
      ),
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStateController.close();
  }
}
