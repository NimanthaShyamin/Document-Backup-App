import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/hardware/notification_engine.dart';
import '../../core/storage/file_storage_manager.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import '../../domain/repositories/i_sync_queue_repository.dart';
import '../../domain/repositories/i_vehicle_document_repository.dart';
import '../datasources/local/app_database.dart';

/// Implementation of IVehicleDocumentRepository combining Drift SQLite with sandboxed file vault.
class VehicleDocumentRepositoryImpl implements IVehicleDocumentRepository {
  final AppDatabase _db;
  final FileStorageManager _storageManager;
  final ISyncQueueRepository _syncQueue;
  final LocalNotificationEngine _notificationEngine;
  final Uuid _uuid = const Uuid();

  VehicleDocumentRepositoryImpl({
    required AppDatabase db,
    required FileStorageManager storageManager,
    required ISyncQueueRepository syncQueue,
    LocalNotificationEngine? notificationEngine,
  })  : _db = db,
        _storageManager = storageManager,
        _syncQueue = syncQueue,
        _notificationEngine = notificationEngine ?? LocalNotificationEngine.instance;

  @override
  Stream<List<VehicleDocument>> watchAllDocuments() {
    return (_db.select(_db.vehicleDocuments)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<VehicleDocument?> getDocumentById(String id) async {
    final row = await (_db.select(_db.vehicleDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null ? _mapToDomain(row) : null;
  }

  @override
  Future<VehicleDocument> saveDocument({
    String? existingId,
    required DocumentType documentType,
    required String title,
    required String vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    required File sourceFile,
  }) async {
    final documentId = existingId ?? _uuid.v4();
    final now = DateTime.now();

    // Ingest into sandboxed vault & compute SHA-256
    final ingestResult = await _storageManager.ingestFile(
      documentId: documentId,
      sourceFile: sourceFile,
    );

    final companion = VehicleDocumentsCompanion(
      id: Value(documentId),
      documentType: Value(documentType.value),
      title: Value(title),
      vehicleRegNo: Value(vehicleRegNo),
      policyNo: Value(policyNo),
      expiryDate: Value(expiryDate?.millisecondsSinceEpoch),
      localFilePath: Value(ingestResult.localFilePath),
      fileChecksumSha256: Value(ingestResult.checksumSha256),
      syncStatus: const Value('queued_upload'),
      lastModifiedTimestamp: Value(now.millisecondsSinceEpoch),
      createdAt: Value(now.millisecondsSinceEpoch),
    );

    await _db.into(_db.vehicleDocuments).insertOnConflictUpdate(companion);

    // Schedule local push notification alerts if expiry date is present
    if (expiryDate != null) {
      await _notificationEngine.scheduleExpiryAlerts(
        documentId: documentId,
        title: title,
        vehicleRegNo: vehicleRegNo,
        expiryDate: expiryDate,
      );
    }

    // Queue upload to private Google Drive AppData
    await _syncQueue.enqueueUpload(documentId);

    final saved = await getDocumentById(documentId);
    return saved!;
  }

  @override
  Future<void> deleteDocument(String id) async {
    final doc = await getDocumentById(id);
    if (doc != null) {
      // Cancel local notifications
      await _notificationEngine.cancelDocumentAlerts(id);

      // Delete physical sandboxed folder
      await _storageManager.deleteDocumentFolder(id);

      // Queue remote cloud deletion
      await _syncQueue.enqueueDelete(id, doc.driveFileId);

      // Delete local database record
      await (_db.delete(_db.vehicleDocuments)..where((t) => t.id.equals(id))).go();
    }
  }

  VehicleDocument _mapToDomain(VehicleDocumentData data) {
    return VehicleDocument(
      id: data.id,
      documentType: DocumentType.fromString(data.documentType),
      title: data.title,
      vehicleRegNo: data.vehicleRegNo,
      policyNo: data.policyNo,
      expiryDate: data.expiryDate != null ? DateTime.fromMillisecondsSinceEpoch(data.expiryDate!) : null,
      localFilePath: data.localFilePath,
      driveFileId: data.driveFileId,
      fileChecksumSha256: data.fileChecksumSha256,
      syncStatus: SyncStatus.fromString(data.syncStatus),
      lastModifiedTimestamp: DateTime.fromMillisecondsSinceEpoch(data.lastModifiedTimestamp),
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
    );
  }
}
