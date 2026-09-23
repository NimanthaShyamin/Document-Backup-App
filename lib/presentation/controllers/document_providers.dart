import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hardware/notification_engine.dart';
import '../../core/storage/file_storage_manager.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/datasources/remote/drive_app_data_service.dart';
import '../../data/repositories/sync_queue_repository_impl.dart';
import '../../data/repositories/vehicle_document_repository_impl.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import '../../domain/repositories/i_sync_queue_repository.dart';
import '../../domain/repositories/i_vehicle_document_repository.dart';

// Singletons & Core Services
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final fileStorageManagerProvider = Provider<FileStorageManager>((ref) {
  return FileStorageManager();
});

final driveAppDataServiceProvider = Provider<DriveAppDataService>((ref) {
  return DriveAppDataService();
});

final notificationEngineProvider = Provider<LocalNotificationEngine>((ref) {
  return LocalNotificationEngine.instance;
});

// Repositories
final syncQueueRepositoryProvider = Provider<ISyncQueueRepository>((ref) {
  final repo = SyncQueueRepository(
    db: ref.watch(appDatabaseProvider),
    driveService: ref.watch(driveAppDataServiceProvider),
    storageManager: ref.watch(fileStorageManagerProvider),
  );
  return repo;
});

final vehicleDocumentRepositoryProvider = Provider<IVehicleDocumentRepository>((ref) {
  return VehicleDocumentRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    storageManager: ref.watch(fileStorageManagerProvider),
    syncQueue: ref.watch(syncQueueRepositoryProvider),
    notificationEngine: ref.watch(notificationEngineProvider),
  );
});

// Reactive Document List Stream (Direct from Local SQLite WAL)
final vehicleDocumentsStreamProvider = StreamProvider<List<VehicleDocument>>((ref) {
  final repository = ref.watch(vehicleDocumentRepositoryProvider);
  return repository.watchAllDocuments();
});

// Reactive Sync Engine State Stream
final syncEngineStateProvider = StreamProvider<SyncEngineState>((ref) {
  final syncQueue = ref.watch(syncQueueRepositoryProvider);
  return syncQueue.syncStateStream;
});
