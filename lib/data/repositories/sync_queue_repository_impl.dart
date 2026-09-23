import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../../core/storage/file_storage_manager.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/repositories/i_sync_queue_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/drive_app_data_service.dart';

/// Concrete implementation of the FIFO Offline-to-Cloud Sync Engine.
class SyncQueueRepository implements ISyncQueueRepository {
  final AppDatabase _db;
  final DriveAppDataService _driveService;
  final FileStorageManager _storageManager;
  final Connectivity _connectivity;

  final StreamController<SyncEngineState> _syncStateController =
      StreamController<SyncEngineState>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;

  SyncQueueRepository({
    required AppDatabase db,
    required DriveAppDataService driveService,
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

  void _initializeConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        developer.log('Network connectivity restored. Triggering sync queue processing.');
        processQueue();
      }
    });
  }

  @override
  Future<void> enqueueUpload(String documentId) async {
    await _db.into(_db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            documentId: documentId,
            action: 'upload',
            retryCount: const Value(0),
            nextRetryAt: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // Update document local status to reflect queued state
    await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(documentId))).write(
      const VehicleDocumentsCompanion(syncStatus: Value('queued_upload')),
    );

    // Trigger immediate non-blocking flush
    unawaited(processQueue());
  }

  @override
  Future<void> enqueueDelete(String documentId, String? driveFileId) async {
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

    unawaited(processQueue());
  }

  @override
  Future<void> reconcileStartupDelta() async {
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      developer.log('Startup sync skipped: Device is offline.');
      _syncStateController.add(const SyncEngineState.offline());
      return;
    }

    _syncStateController.add(const SyncEngineState.syncing(progress: 0.0, currentAction: 'Reconciling AppData'));

    try {
      // 1. Fetch remote cloud state from Google Drive AppData
      final remoteFiles = await _driveService.listAppDataFiles();
      final remoteMap = {for (var f in remoteFiles) f.documentId: f};

      // 2. Fetch local SQLite catalog
      final localDocs = await _db.select(_db.vehicleDocuments).get();
      final localMap = {for (var d in localDocs) d.id: d};

      // 3. Detect remote documents missing locally (Cloud -> Local Download)
      for (final remote in remoteFiles) {
        if (!localMap.containsKey(remote.documentId)) {
          developer.log('Discovered new remote document: ${remote.documentId}. Scheduling download.');
          final sandboxedPath = await _storageManager.generatePath(
            remote.documentId,
            remote.name.split('.').last,
          );

          // Insert preliminary stub in local database
          await _db.into(_db.vehicleDocuments).insert(
                VehicleDocumentsCompanion.insert(
                  id: remote.documentId,
                  documentType: remote.documentType,
                  title: remote.name,
                  vehicleRegNo: remote.vehicleRegNo,
                  policyNo: Value(remote.policyNo),
                  expiryDate: Value(remote.expiryDate?.millisecondsSinceEpoch),
                  localFilePath: sandboxedPath,
                  driveFileId: Value(remote.driveFileId),
                  fileChecksumSha256: remote.checksumSha256,
                  syncStatus: 'download_pending',
                  lastModifiedTimestamp: remote.clientModified.millisecondsSinceEpoch,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ),
              );

          // Enqueue download task
          await _db.into(_db.syncQueue).insert(
                SyncQueueCompanion.insert(
                  documentId: remote.documentId,
                  action: 'download',
                  driveFileId: Value(remote.driveFileId),
                  nextRetryAt: DateTime.now().millisecondsSinceEpoch,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ),
              );
        }
      }

      // 4. Reconcile matching documents and detect conflicts
      for (final local in localDocs) {
        final remote = remoteMap[local.id];
        if (remote != null) {
          if (local.fileChecksumSha256 == remote.checksumSha256) {
            // Checksums match: marked as synced
            if (local.syncStatus != 'synced') {
              await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(local.id))).write(
                VehicleDocumentsCompanion(
                  driveFileId: Value(remote.driveFileId),
                  syncStatus: const Value('synced'),
                ),
              );
            }
          } else {
            // Checksums differ: resolve by last modified timestamp
            if (remote.clientModified.millisecondsSinceEpoch > local.lastModifiedTimestamp) {
              developer.log('Remote version is newer for ${local.id}. Scheduling download.');
              await _db.into(_db.syncQueue).insertOnConflictUpdate(
                    SyncQueueCompanion.insert(
                      documentId: local.id,
                      action: 'download',
                      driveFileId: Value(remote.driveFileId),
                      nextRetryAt: DateTime.now().millisecondsSinceEpoch,
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
            } else if (local.lastModifiedTimestamp > remote.clientModified.millisecondsSinceEpoch) {
              developer.log('Local version is newer for ${local.id}. Queuing upload.');
              await enqueueUpload(local.id);
            }
          }
        }
      }

      // 5. Drain pending queue
      await processQueue();
    } catch (e, stack) {
      developer.log('Delta reconciliation failed', error: e, stackTrace: stack);
      _syncStateController.add(SyncEngineState.failed(error: e.toString()));
    }
  }

  @override
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // FIFO query: tasks ready for execution
      final pendingTasks = await (_db.select(_db.syncQueue)
            ..where((t) => t.nextRetryAt.isSmallerOrEqualValue(now))
            ..orderBy([(t) => OrderingTerm(expression: t.queueId, mode: OrderingMode.asc)]))
          .get();

      if (pendingTasks.isEmpty) {
        _syncStateController.add(const SyncEngineState.idle());
        _isProcessing = false;
        return;
      }

      for (int i = 0; i < pendingTasks.length; i++) {
        final task = pendingTasks[i];
        final progress = (i + 1) / pendingTasks.length;
        _syncStateController.add(SyncEngineState.syncing(
          progress: progress,
          currentAction: '${task.action.toUpperCase()} for ${task.documentId}',
        ));

        try {
          await _executeTask(task);
          // Delete successfully finished task
          await (_db.delete(_db.syncQueue)..where((t) => t.queueId.equals(task.queueId))).go();
        } catch (e, stack) {
          developer.log('Task execution failed for ${task.queueId}', error: e, stackTrace: stack);
          await _handleTaskFailure(task, e.toString());
        }
      }

      _syncStateController.add(const SyncEngineState.idle());
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeTask(SyncQueueData task) async {
    switch (task.action) {
      case 'upload':
        final doc = await (_db.select(_db.vehicleDocuments)
              ..where((t) => t.id.equals(task.documentId)))
            .getSingleOrNull();

        if (doc == null) {
          // Document was deleted before upload took place
          return;
        }

        final driveId = await _driveService.uploadDocumentFile(
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

        await _driveService.downloadDocumentFile(
          driveFileId: task.driveFileId!,
          targetFile: File(doc.localFilePath),
          expectedSha256: doc.fileChecksumSha256,
        );

        await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(doc.id))).write(
          const VehicleDocumentsCompanion(syncStatus: Value('synced')),
        );
        break;

      case 'delete':
        if (task.driveFileId != null) {
          await _driveService.deleteDocumentFile(task.driveFileId!);
        }
        break;
    }
  }

  Future<void> _handleTaskFailure(SyncQueueData task, String error) async {
    const maxRetries = 5;
    final nextRetryCount = task.retryCount + 1;

    if (nextRetryCount >= maxRetries) {
      developer.log('Max retries exceeded for task ${task.queueId}. Marking document as failed.');
      await (_db.delete(_db.syncQueue)..where((t) => t.queueId.equals(task.queueId))).go();
      await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(task.documentId))).write(
        const VehicleDocumentsCompanion(syncStatus: Value('sync_failed')),
      );
      return;
    }

    // Exponential backoff: base 5s * 2^retry + jitter (0-2s)
    final randomJitter = Random().nextDouble() * 2000;
    final backoffMs = (5000 * pow(2, task.retryCount)).toInt() + randomJitter.toInt();
    final clampedBackoff = min(backoffMs, 900000); // Max 15 minutes
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
