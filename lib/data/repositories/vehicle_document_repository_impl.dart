import 'dart:convert';
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
        _notificationEngine = notificationEngine ?? LocalNotificationEngine.instance {
    _purgeLegacyProbeRecords();
  }

  void _purgeLegacyProbeRecords() {
    (_db.delete(_db.vehicleDocuments)
          ..where((t) => t.vehicleRegNo.equals('VERIFY-E2E')))
        .go()
        .catchError((_) => 0);
  }

  @override
  Stream<List<VehicleDocument>> watchAllDocuments() {
    return (_db.select(_db.vehicleDocuments)
          ..where((t) => t.vehicleRegNo.isNotValue('VERIFY-E2E') & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows
            .where((r) =>
                !r.isDeleted &&
                !r.vehicleRegNo.startsWith('VERIFY-') &&
                !r.title.toLowerCase().contains('probe'))
            .map(_mapToDomain)
            .toList());
  }

  @override
  Stream<List<VehicleDocument>> watchRecycleBinDocuments() {
    return (_db.select(_db.vehicleDocuments)
          ..where((t) => t.isDeleted.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows
            .where((r) =>
                r.isDeleted &&
                !r.vehicleRegNo.startsWith('VERIFY-') &&
                !r.title.toLowerCase().contains('probe'))
            .map(_mapToDomain)
            .toList());
  }

  @override
  Future<VehicleDocument?> getDocumentById(String id) async {
    final row = await (_db.select(_db.vehicleDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.vehicleRegNo.startsWith('VERIFY-')) return null;
    return _mapToDomain(row);
  }

  @override
  Future<VehicleDocument> saveDocument({
    String? existingId,
    DocumentType? documentType,
    String? category,
    required String title,
    String? vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    Map<String, dynamic> visibleFields = const {},
    String? hiddenContext,
    bool requiresAiScan = false,
    required File sourceFile,
  }) async {
    final documentId = existingId ?? _uuid.v4();
    final now = DateTime.now();

    final effectiveCategory = category?.trim().isNotEmpty == true
        ? category!.trim()
        : (documentType?.value ?? 'general');
    final effectiveDocType = documentType ?? DocumentType.fromString(effectiveCategory);
    final effectiveRegNo = vehicleRegNo?.trim().isNotEmpty == true
        ? vehicleRegNo!.trim()
        : ((visibleFields['vehicleRegNo'] as String?)?.trim().isNotEmpty == true
            ? (visibleFields['vehicleRegNo'] as String).trim()
            : 'General');
    final effectivePolicyNo = policyNo?.trim().isNotEmpty == true
        ? policyNo!.trim()
        : ((visibleFields['policyNo'] as String?)?.trim().isNotEmpty == true
            ? (visibleFields['policyNo'] as String).trim()
            : null);

    // Merge any extracted legacy keys into visibleFields
    final mergedFields = Map<String, dynamic>.from(visibleFields);
    if (effectiveRegNo.isNotEmpty && effectiveRegNo != 'General' && !mergedFields.containsKey('vehicleRegNo')) {
      mergedFields['vehicleRegNo'] = effectiveRegNo;
    }
    if (effectivePolicyNo != null && effectivePolicyNo.isNotEmpty && !mergedFields.containsKey('policyNo')) {
      mergedFields['policyNo'] = effectivePolicyNo;
    }

    // Ingest into sandboxed vault & compute SHA-256
    final ingestResult = await _storageManager.ingestFile(
      documentId: documentId,
      sourceFile: sourceFile,
    );

    final companion = VehicleDocumentsCompanion(
      id: Value(documentId),
      documentType: Value(effectiveDocType.value),
      category: Value(effectiveCategory),
      title: Value(title),
      vehicleRegNo: Value(effectiveRegNo),
      policyNo: Value(effectivePolicyNo),
      expiryDate: Value(expiryDate?.millisecondsSinceEpoch),
      localFilePath: Value(ingestResult.localFilePath),
      fileChecksumSha256: Value(ingestResult.checksumSha256),
      syncStatus: const Value('queued_upload'),
      lastModifiedTimestamp: Value(now.millisecondsSinceEpoch),
      createdAt: Value(now.millisecondsSinceEpoch),
      visibleFields: Value(jsonEncode(mergedFields)),
      hiddenContext: Value(hiddenContext),
      requiresAiScan: Value(requiresAiScan),
      isDeleted: const Value(false),
      deletedAt: const Value(null),
    );

    await _db.into(_db.vehicleDocuments).insertOnConflictUpdate(companion);

    // Schedule local push notification alerts if expiry date is present
    if (expiryDate != null) {
      try {
        await _notificationEngine.scheduleExpiryAlerts(
          documentId: documentId,
          title: title,
          vehicleRegNo: effectiveRegNo,
          expiryDate: expiryDate,
        );
      } catch (_) {
        // Notification permission or exact alarm restriction shouldn't fail vault save
      }
    }

    // Queue upload to private Google Drive AppData
    await _syncQueue.enqueueUpload(documentId);

    final saved = await getDocumentById(documentId);
    return saved!;
  }

  @override
  Future<void> deleteDocument(String id) => moveToRecycleBin(id);

  @override
  Future<void> moveToRecycleBin(String id) async {
    final doc = await getDocumentById(id);
    if (doc != null) {
      await _notificationEngine.cancelDocumentAlerts(id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(id))).write(
        VehicleDocumentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          lastModifiedTimestamp: Value(now),
        ),
      );
    }
  }

  @override
  Future<void> restoreFromRecycleBin(String id) async {
    final row = await (_db.select(_db.vehicleDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.vehicleDocuments)..where((t) => t.id.equals(id))).write(
        VehicleDocumentsCompanion(
          isDeleted: const Value(false),
          deletedAt: const Value(null),
          lastModifiedTimestamp: Value(now),
        ),
      );
      if (row.expiryDate != null) {
        try {
          await _notificationEngine.scheduleExpiryAlerts(
            documentId: row.id,
            title: row.title,
            vehicleRegNo: row.vehicleRegNo,
            expiryDate: DateTime.fromMillisecondsSinceEpoch(row.expiryDate!),
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> permanentlyDeleteDocument(String id) async {
    final row = await (_db.select(_db.vehicleDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    final driveId = row?.driveFileId;

    // Cancel local notifications & delete physical files
    await _notificationEngine.cancelDocumentAlerts(id);
    await _storageManager.deleteDocumentFolder(id);

    // Save tombstone to permanently block cloud sync resurrection
    await _db.into(_db.documentTombstones).insertOnConflictUpdate(
          DocumentTombstonesCompanion.insert(
            documentId: id,
            driveFileId: Value(driveId),
            deletedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // Enqueue cloud deletion
    await _syncQueue.enqueueDelete(id, driveId);

    // Delete local database record
    await (_db.delete(_db.vehicleDocuments)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> emptyRecycleBin() async {
    final recycled = await (_db.select(_db.vehicleDocuments)..where((t) => t.isDeleted.equals(true))).get();
    for (final doc in recycled) {
      await permanentlyDeleteDocument(doc.id);
    }
  }

  @override
  Future<void> autoCleanupRecycleBin(int retentionDays) async {
    if (retentionDays <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays)).millisecondsSinceEpoch;
    final expired = await (_db.select(_db.vehicleDocuments)
          ..where((t) => t.isDeleted.equals(true) & t.deletedAt.isSmallerOrEqualValue(cutoff)))
        .get();
    for (final doc in expired) {
      await permanentlyDeleteDocument(doc.id);
    }
  }

  VehicleDocument _mapToDomain(VehicleDocumentData data) {
    Map<String, dynamic> decodedFields = {};
    try {
      if (data.visibleFields.isNotEmpty) {
        decodedFields = jsonDecode(data.visibleFields) as Map<String, dynamic>;
      }
    } catch (_) {}

    return VehicleDocument(
      id: data.id,
      documentType: DocumentType.fromString(data.documentType),
      category: data.category.isNotEmpty ? data.category : data.documentType,
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
      visibleFields: decodedFields,
      hiddenContext: data.hiddenContext,
      requiresAiScan: data.requiresAiScan,
      isDeleted: data.isDeleted,
      deletedAt: data.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!) : null,
    );
  }
}
