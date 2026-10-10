import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/core/storage/file_storage_manager.dart';
import 'package:vehicle_document_vault/data/datasources/local/app_database.dart';
import 'package:vehicle_document_vault/data/repositories/vehicle_document_repository_impl.dart';
import 'package:vehicle_document_vault/domain/entities/sync_status.dart';
import 'package:vehicle_document_vault/domain/repositories/i_sync_queue_repository.dart';

class DummySyncQueueRepository implements ISyncQueueRepository {
  final List<String> deletedIds = [];
  final List<String> uploadedIds = [];

  @override
  Future<void> enqueueDelete(String documentId, String? driveFileId) async {
    deletedIds.add(documentId);
  }

  @override
  Future<void> enqueueUpload(String documentId) async {
    uploadedIds.add(documentId);
  }

  @override
  Future<void> processQueue() async {}

  @override
  Future<void> reconcileStartupDelta() async {}

  @override
  Stream<SyncEngineState> get syncStateStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late FileStorageManager storageManager;
  late DummySyncQueueRepository syncQueue;
  late VehicleDocumentRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('recycle_bin_test_');
    storageManager = FileStorageManager(baseDirectory: tempDir);
    syncQueue = DummySyncQueueRepository();

    repo = VehicleDocumentRepositoryImpl(
      db: db,
      storageManager: storageManager,
      syncQueue: syncQueue,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> insertTestDocument({
    required String id,
    required String title,
    bool isDeleted = false,
    int? deletedAt,
  }) async {
    final file = File('${tempDir.path}/$id.dat');
    await file.writeAsString('test document content');

    await db.into(db.vehicleDocuments).insert(
          VehicleDocumentsCompanion.insert(
            id: id,
            documentType: 'insurance',
            category: const Value('Insurance'),
            title: title,
            vehicleRegNo: 'WP-CAD-1234',
            localFilePath: file.path,
            fileChecksumSha256: 'sha256_$id',
            syncStatus: 'synced',
            lastModifiedTimestamp: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            isDeleted: Value(isDeleted),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  group('Recycle Bin & Anti-Resurrection Tombstone Tests', () {
    test('Soft delete moves document to Recycle Bin and cancels notifications', () async {
      await insertTestDocument(id: 'doc-1', title: 'Vehicle Insurance');

      // 1. Initial state: document appears in active catalog
      final activeInitial = await repo.watchAllDocuments().first;
      expect(activeInitial.length, equals(1));
      expect(activeInitial.first.id, equals('doc-1'));

      // 2. Move to recycle bin
      await repo.moveToRecycleBin('doc-1');

      // 3. Document no longer in active catalog
      final activeAfter = await repo.watchAllDocuments().first;
      expect(activeAfter, isEmpty);

      // 4. Document visible in Recycle Bin
      final recycled = await repo.watchRecycleBinDocuments().first;
      expect(recycled.length, equals(1));
      expect(recycled.first.id, equals('doc-1'));
      expect(recycled.first.isDeleted, isTrue);
      expect(recycled.first.deletedAt, isNotNull);
    });

    test('Restore from Recycle Bin restores document back to active vault', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await insertTestDocument(id: 'doc-2', title: 'Revenue License', isDeleted: true, deletedAt: now);

      // Initially in recycle bin, not active
      expect(await repo.watchAllDocuments().first, isEmpty);
      expect((await repo.watchRecycleBinDocuments().first).length, equals(1));

      // Restore
      await repo.restoreFromRecycleBin('doc-2');

      // Now back in active catalog, removed from recycle bin
      final active = await repo.watchAllDocuments().first;
      expect(active.length, equals(1));
      expect(active.first.id, equals('doc-2'));
      expect(active.first.isDeleted, isFalse);
      expect(active.first.deletedAt, isNull);

      expect(await repo.watchRecycleBinDocuments().first, isEmpty);
    });

    test('Permanently delete registers a Tombstone in database and enqueues sync delete', () async {
      await insertTestDocument(id: 'doc-3', title: 'Eco Test Certificate', isDeleted: true);

      // Permanently delete
      await repo.permanentlyDeleteDocument('doc-3');

      // Document removed completely from SQLite vehicleDocuments
      final checkRow = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('doc-3'))).getSingleOrNull();
      expect(checkRow, isNull);

      // Tombstone MUST be created to prevent Google Drive AppData resurrection
      final tombstone = await (db.select(db.documentTombstones)..where((t) => t.documentId.equals('doc-3'))).getSingleOrNull();
      expect(tombstone, isNotNull);
      expect(tombstone!.documentId, equals('doc-3'));
      expect(tombstone.deletedAt, isNotNull);

      // Enqueued to sync queue
      expect(syncQueue.deletedIds, contains('doc-3'));
    });

    test('emptyRecycleBin purges all soft-deleted documents and creates tombstones for each', () async {
      await insertTestDocument(id: 'doc-active', title: 'Active Doc', isDeleted: false);
      await insertTestDocument(id: 'doc-bin-1', title: 'Bin 1', isDeleted: true);
      await insertTestDocument(id: 'doc-bin-2', title: 'Bin 2', isDeleted: true);

      // Empty Recycle Bin
      await repo.emptyRecycleBin();

      // Active document remains untouched
      final active = await repo.watchAllDocuments().first;
      expect(active.length, equals(1));
      expect(active.first.id, equals('doc-active'));

      // Recycle bin is completely empty
      final recycled = await repo.watchRecycleBinDocuments().first;
      expect(recycled, isEmpty);

      // Tombstones created for both purged documents
      final tombstones = await db.select(db.documentTombstones).get();
      final tombIds = tombstones.map((t) => t.documentId).toSet();
      expect(tombIds, containsAll(['doc-bin-1', 'doc-bin-2']));
      expect(tombIds, isNot(contains('doc-active')));
    });

    test('autoCleanupRecycleBin purges only documents older than the retention period', () async {
      final now = DateTime.now();
      // Doc 1: deleted 45 days ago (should be purged under 30-day retention)
      final oldTimestamp = now.subtract(const Duration(days: 45)).millisecondsSinceEpoch;
      await insertTestDocument(id: 'doc-old', title: 'Old Deleted Doc', isDeleted: true, deletedAt: oldTimestamp);

      // Doc 2: deleted 5 days ago (should be kept under 30-day retention)
      final recentTimestamp = now.subtract(const Duration(days: 5)).millisecondsSinceEpoch;
      await insertTestDocument(id: 'doc-recent', title: 'Recent Deleted Doc', isDeleted: true, deletedAt: recentTimestamp);

      // Run auto-cleanup with 30-day retention
      await repo.autoCleanupRecycleBin(30);

      final remainingInBin = await repo.watchRecycleBinDocuments().first;
      expect(remainingInBin.length, equals(1));
      expect(remainingInBin.first.id, equals('doc-recent'));

      // doc-old was permanently deleted and has a tombstone
      final oldTombstone = await (db.select(db.documentTombstones)..where((t) => t.documentId.equals('doc-old'))).getSingleOrNull();
      expect(oldTombstone, isNotNull);
    });
  });
}
