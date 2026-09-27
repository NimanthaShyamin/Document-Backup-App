import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/core/hardware/biometric_auth_service.dart';
import 'package:vehicle_document_vault/data/datasources/remote/gemini_document_extraction_service.dart';
import 'package:vehicle_document_vault/domain/entities/document_type.dart';
import 'package:vehicle_document_vault/domain/entities/sync_status.dart';
import 'package:vehicle_document_vault/domain/entities/vehicle_document.dart';
import 'package:vehicle_document_vault/domain/repositories/i_vehicle_document_repository.dart';
import 'package:vehicle_document_vault/presentation/controllers/document_providers.dart';
import 'package:vehicle_document_vault/presentation/screens/document_list_screen.dart';
import 'package:vehicle_document_vault/presentation/screens/settings_screen.dart';
import 'package:vehicle_document_vault/presentation/widgets/import_document_metadata_sheet.dart';

class FakeBiometricAuthService extends BiometricAuthService {
  bool shouldSucceed = true;
  int callCount = 0;

  @override
  Future<bool> authenticate({String reason = ''}) async {
    callCount++;
    return shouldSucceed;
  }

  @override
  Future<bool> canAuthenticate() async => true;
}

class FakeVehicleDocumentRepository implements IVehicleDocumentRepository {
  final List<VehicleDocument> _docs;
  final List<String> deletedIds = [];

  FakeVehicleDocumentRepository(this._docs);

  @override
  Stream<List<VehicleDocument>> watchAllDocuments() => Stream.value(_docs);

  @override
  Future<VehicleDocument?> getDocumentById(String id) async {
    try {
      return _docs.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
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
    final doc = VehicleDocument(
      id: existingId ?? 'test_saved_id',
      documentType: documentType,
      title: title,
      vehicleRegNo: vehicleRegNo,
      policyNo: policyNo,
      expiryDate: expiryDate,
      localFilePath: sourceFile.path,
      fileChecksumSha256: 'sha256_mock',
      syncStatus: SyncStatus.queuedUpload,
      lastModifiedTimestamp: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _docs.add(doc);
    return doc;
  }

  @override
  Future<void> deleteDocument(String id) async {
    deletedIds.add(id);
    _docs.removeWhere((d) => d.id == id);
  }
}

class FakeGeminiService extends GeminiDocumentExtractionService {
  final ExtractedDocumentDetails detailsToReturn;

  FakeGeminiService(this.detailsToReturn) : super(apiKey: 'AIzaSyMockKey');

  @override
  bool get isConfigured => true;

  @override
  Future<ExtractedDocumentDetails> extractDetailsFromFile(File file) async {
    return detailsToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleDoc = VehicleDocument(
    id: 'doc_to_delete_1',
    documentType: DocumentType.revenueLicense,
    title: 'Revenue License 2026',
    vehicleRegNo: 'WP CAB-9999',
    policyNo: 'POL-REV-99',
    expiryDate: DateTime.now().add(const Duration(days: 90)),
    localFilePath: '/test/path/rev.pdf',
    driveFileId: null,
    fileChecksumSha256: 'sha_test',
    syncStatus: SyncStatus.synced,
    lastModifiedTimestamp: DateTime.now(),
    createdAt: DateTime.now(),
  );

  group('Document Deletion with Biometric Confirmation Tests', () {
    testWidgets('Tapping delete shows confirmation dialog with document name and details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeBio = FakeBiometricAuthService();
      final fakeRepo = FakeVehicleDocumentRepository([sampleDoc]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricAuthServiceProvider.overrideWithValue(fakeBio),
            vehicleDocumentRepositoryProvider.overrideWithValue(fakeRepo),
            vehicleDocumentsStreamProvider.overrideWith((ref) => Stream.value([sampleDoc])),
          ],
          child: const MaterialApp(home: DocumentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe left on document card to reveal delete action
      await tester.drag(find.text('Revenue License 2026'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog appears
      expect(find.text('Delete Document?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to permanently delete "Revenue License 2026"'), findsOneWidget);
      final dialogDeleteBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete'));
      expect(find.text('Cancel'), findsOneWidget);
      expect(dialogDeleteBtn, findsOneWidget);

      // Tap Cancel -> should not delete
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeBio.callCount, 0);
      expect(fakeRepo.deletedIds, isEmpty);
    });

    testWidgets('Confirming delete invokes Biometric Authentication and deletes on success', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeBio = FakeBiometricAuthService();
      fakeBio.shouldSucceed = true;
      final fakeRepo = FakeVehicleDocumentRepository([sampleDoc]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricAuthServiceProvider.overrideWithValue(fakeBio),
            vehicleDocumentRepositoryProvider.overrideWithValue(fakeRepo),
            vehicleDocumentsStreamProvider.overrideWith((ref) => Stream.value([sampleDoc])),
          ],
          child: const MaterialApp(home: DocumentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe left to trigger delete
      await tester.drag(find.text('Revenue License 2026'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Tap Delete in dialog
      final dialogDeleteBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete'));
      await tester.tap(dialogDeleteBtn);
      await tester.pumpAndSettle();

      // Verify biometric was called and document was deleted
      expect(fakeBio.callCount, 1);
      expect(fakeRepo.deletedIds, contains('doc_to_delete_1'));
    });

    testWidgets('When Biometric Auth fails or is canceled, document is NOT deleted', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeBio = FakeBiometricAuthService();
      fakeBio.shouldSucceed = false; // User cancels or biometric mismatch
      final fakeRepo = FakeVehicleDocumentRepository([sampleDoc]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricAuthServiceProvider.overrideWithValue(fakeBio),
            vehicleDocumentRepositoryProvider.overrideWithValue(fakeRepo),
            vehicleDocumentsStreamProvider.overrideWith((ref) => Stream.value([sampleDoc])),
          ],
          child: const MaterialApp(home: DocumentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe left to trigger delete
      await tester.drag(find.text('Revenue License 2026'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      final dialogDeleteBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete'));
      await tester.tap(dialogDeleteBtn);
      await tester.pumpAndSettle();

      // Verify biometric was challenged but deletion was aborted
      expect(fakeBio.callCount, 1);
      expect(fakeRepo.deletedIds, isEmpty);
      expect(find.textContaining('Authentication canceled or failed'), findsOneWidget);
    });
  });

  group('Settings Screen Biometric Deletion & Gemini API Key Tests', () {
    testWidgets('Settings screen renders Biometric Protection toggle (Default ON) and Gemini card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Biometric Protection Card
      expect(find.text('Biometric Deletion Protection'), findsOneWidget);
      expect(find.text('DEFAULT ON'), findsOneWidget);

      // Verify Gemini Document Scanner Card
      expect(find.text('Gemini AI Document Scanner'), findsOneWidget);

      // Tap Gemini card to open Key Dialog
      await tester.tap(find.text('Gemini AI Document Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Gemini API Key'), findsOneWidget);
      expect(find.text('Save Key'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('Gemini Auto-Fill & Manual Prompt Box Fallback Tests', () {
    testWidgets('When Gemini does not detect details, shows prompt box and all fields are editable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeGemini = FakeGeminiService(ExtractedDocumentDetails.empty());
      final fakeRepo = FakeVehicleDocumentRepository([]);

      // Create a temporary mock file
      final tempFile = File('${Directory.systemTemp.path}/test_manual_doc.png');
      if (!tempFile.existsSync()) {
        tempFile.writeAsStringSync('dummy content');
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geminiDocumentExtractionServiceProvider.overrideWithValue(fakeGemini),
            vehicleDocumentRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ImportDocumentMetadataSheet.show(
                      context: context,
                      sourceFile: tempFile,
                      originalName: 'test_manual_doc.png',
                      extension: 'png',
                      fileSize: 1024,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify the prompt box is displayed:
      expect(find.text('Manual Entry Required'), findsOneWidget);
      expect(find.textContaining('Gemini could not detect details from this document'), findsOneWidget);

      // Verify all fields are editable TextFields
      final titleField = find.widgetWithText(TextField, 'Document Title');
      expect(titleField, findsOneWidget);

      // User enters manual details
      await tester.enterText(titleField, 'Manually Entered Insurance');
      await tester.pumpAndSettle();

      expect(find.text('Manually Entered Insurance'), findsOneWidget);
      expect(find.text('Secure & Save to Vault'), findsOneWidget);
    });

    testWidgets('When Gemini detects details, fields are auto-filled and still editable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final detected = ExtractedDocumentDetails(
        vehicleRegNo: 'WP CBA-7788',
        title: 'SLIC Comprehensive Motor Insurance',
        documentType: DocumentType.insuranceCard,
        policyNo: 'POL-SLIC-778899',
        expiryDate: DateTime(2027, 5, 20),
        isAiDetected: true,
      );

      final fakeGemini = FakeGeminiService(detected);
      final fakeRepo = FakeVehicleDocumentRepository([]);

      final tempFile = File('${Directory.systemTemp.path}/test_gemini_doc.pdf');
      if (!tempFile.existsSync()) {
        tempFile.writeAsStringSync('dummy pdf content');
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geminiDocumentExtractionServiceProvider.overrideWithValue(fakeGemini),
            vehicleDocumentRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ImportDocumentMetadataSheet.show(
                      context: context,
                      sourceFile: tempFile,
                      originalName: 'test_gemini_doc.pdf',
                      extension: 'pdf',
                      fileSize: 2048,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify Gemini Auto-Filled Banner
      expect(find.text('Gemini AI Auto-Filled Details'), findsOneWidget);

      // Verify fields auto-filled
      expect(find.text('SLIC Comprehensive Motor Insurance'), findsOneWidget);
      expect(find.text('WP CBA-7788'), findsOneWidget);
      expect(find.text('POL-SLIC-778899'), findsOneWidget);

      // Verify fields can still be edited
      final titleField = find.widgetWithText(TextField, 'SLIC Comprehensive Motor Insurance');
      await tester.enterText(titleField, 'Edited SLIC Insurance');
      await tester.pumpAndSettle();

      expect(find.text('Edited SLIC Insurance'), findsOneWidget);
    });
  });
}
