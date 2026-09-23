import '../entities/sync_status.dart';

/// Contract for the FIFO Offline-to-Cloud Sync Engine.
abstract class ISyncQueueRepository {
  /// Stream of the current engine status (idle, syncing, offline, failed).
  Stream<SyncEngineState> get syncStateStream;

  /// Enqueues an upload task for a local document.
  Future<void> enqueueUpload(String documentId);

  /// Enqueues a delete task to remove a file from Google Drive AppData.
  Future<void> enqueueDelete(String documentId, String? driveFileId);

  /// Performs the non-blocking startup delta diff between local SQLite catalog and remote AppData metadata.
  Future<void> reconcileStartupDelta();

  /// Processes queued FIFO tasks with exponential backoff retry.
  Future<void> processQueue();
}
