import 'package:flutter/material.dart';

/// Synchronization states for local vehicle documents.
enum SyncStatus {
  synced('synced', 'Synced with Drive', Icons.cloud_done, Colors.greenAccent),
  queuedUpload('queued_upload', 'Upload Pending', Icons.cloud_upload_outlined, Colors.amberAccent),
  queuedDelete('queued_delete', 'Delete Pending', Icons.cloud_off, Colors.orangeAccent),
  downloadPending('download_pending', 'Downloading...', Icons.cloud_download_outlined, Colors.lightBlueAccent),
  syncFailed('sync_failed', 'Sync Failed (Will Retry)', Icons.sync_problem, Colors.redAccent);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const SyncStatus(this.value, this.label, this.icon, this.color);

  static SyncStatus fromString(String val) {
    return SyncStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => SyncStatus.queuedUpload,
    );
  }
}

/// Dynamic state representation for the background sync engine.
sealed class SyncEngineState {
  const SyncEngineState();

  const factory SyncEngineState.idle() = SyncEngineIdle;
  const factory SyncEngineState.syncing({required double progress, required String currentAction}) = SyncEngineSyncing;
  const factory SyncEngineState.offline() = SyncEngineOffline;
  const factory SyncEngineState.failed({required String error}) = SyncEngineFailed;
}

class SyncEngineIdle extends SyncEngineState {
  const SyncEngineIdle();
}

class SyncEngineSyncing extends SyncEngineState {
  final double progress;
  final String currentAction;

  const SyncEngineSyncing({required this.progress, required this.currentAction});
}

class SyncEngineOffline extends SyncEngineState {
  const SyncEngineOffline();
}

class SyncEngineFailed extends SyncEngineState {
  final String error;

  const SyncEngineFailed({required this.error});
}
