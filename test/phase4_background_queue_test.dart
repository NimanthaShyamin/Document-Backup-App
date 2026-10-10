import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/data/datasources/local/app_database.dart';
import 'package:vehicle_document_vault/data/datasources/remote/ai_rescan_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late File dummyFile1;
  late File dummyFile2;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('ai_worker_test_');

    dummyFile1 = File('${tempDir.path}/doc1.png');
    await dummyFile1.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    dummyFile2 = File('${tempDir.path}/doc2.png');
    await dummyFile2.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 4: AI Rescan Worker & Rate Limiting Tests', () {
    test('Gracefully exits when queue has no pending documents (requiresAiScan == false)', () async {
      // Insert a document that already has requiresAiScan = false
      await db.into(db.vehicleDocuments).insert(
            VehicleDocumentsCompanion.insert(
              id: 'doc-completed',
              documentType: 'bill',
              category: const Value('bill'),
              title: 'Utility Bill',
              vehicleRegNo: 'General',
              localFilePath: dummyFile1.path,
              fileChecksumSha256: 'hash1',
              syncStatus: 'synced',
              lastModifiedTimestamp: 1000,
              createdAt: 1000,
              requiresAiScan: const Value(false),
            ),
          );

      final success = await AiRescanWorker.executeWorker(
        dbOverride: db,
        apiKeyOverride: 'test_key',
        skipScheduleNext: true,
      );

      expect(success, isTrue);

      final doc = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('doc-completed'))).getSingle();
      expect(doc.requiresAiScan, isFalse);
    });

    test('Strictly processes ONE document per execution loop and handles missing local file', () async {
      // Insert 2 documents that require AI scan
      await db.into(db.vehicleDocuments).insert(
            VehicleDocumentsCompanion.insert(
              id: 'doc-pending-1',
              documentType: 'bill',
              category: const Value('bill'),
              title: 'Invoice 1',
              vehicleRegNo: 'General',
              localFilePath: '${tempDir.path}/non_existent_file.png', // missing file
              fileChecksumSha256: 'hash1',
              syncStatus: 'queued_upload',
              lastModifiedTimestamp: 1000,
              createdAt: 1000, // Older
              requiresAiScan: const Value(true),
            ),
          );

      await db.into(db.vehicleDocuments).insert(
            VehicleDocumentsCompanion.insert(
              id: 'doc-pending-2',
              documentType: 'id_card',
              category: const Value('id_card'),
              title: 'ID Card 2',
              vehicleRegNo: 'General',
              localFilePath: dummyFile2.path,
              fileChecksumSha256: 'hash2',
              syncStatus: 'queued_upload',
              lastModifiedTimestamp: 2000,
              createdAt: 2000, // Newer
              requiresAiScan: const Value(true),
            ),
          );

      // Run worker once with API key
      final success = await AiRescanWorker.executeWorker(
        dbOverride: db,
        apiKeyOverride: 'test_key',
        skipScheduleNext: true, // test mode prevents WorkManager platform calls
      );

      expect(success, isTrue);

      // doc-pending-1 should have been processed (missing file cleared flag to prevent stall)
      final doc1 = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('doc-pending-1'))).getSingle();
      expect(doc1.requiresAiScan, isFalse);

      // doc-pending-2 MUST STILL BE PENDING (strictly 1 document processed per execution loop)
      final doc2 = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('doc-pending-2'))).getSingle();
      expect(doc2.requiresAiScan, isTrue);
    });

    test('Gracefully handles missing API key without crashing or throwing exceptions', () async {
      await db.into(db.vehicleDocuments).insert(
            VehicleDocumentsCompanion.insert(
              id: 'doc-pending-nokey',
              documentType: 'bill',
              category: const Value('bill'),
              title: 'Pending Doc',
              vehicleRegNo: 'General',
              localFilePath: dummyFile1.path,
              fileChecksumSha256: 'hash1',
              syncStatus: 'queued_upload',
              lastModifiedTimestamp: 1000,
              createdAt: 1000,
              requiresAiScan: const Value(true),
            ),
          );

      final success = await AiRescanWorker.executeWorker(
        dbOverride: db,
        apiKeyOverride: '', // empty key
        skipScheduleNext: true,
      );

      expect(success, isTrue);
      final doc = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('doc-pending-nokey'))).getSingle();
      // Document remains marked for scan until an API key is available
      expect(doc.requiresAiScan, isTrue);
    });
  });
}
