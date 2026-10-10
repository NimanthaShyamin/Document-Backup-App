import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/domain/entities/document_type.dart';
import 'package:vehicle_document_vault/domain/entities/sync_status.dart';
import 'package:vehicle_document_vault/domain/entities/vehicle_document.dart';
import 'package:vehicle_document_vault/presentation/screens/document_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyFile;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('doc_viewer_test_');
    dummyFile = File('${tempDir.path}/test_image.png');
    // Minimal 1x1 png bytes
    await dummyFile.writeAsBytes([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);
  });

  group('Phase 3: Dynamic Display & hiddenContext Security in DocumentViewerScreen', () {
    testWidgets('Renders dynamic visibleFields and never leaks hiddenContext', (tester) async {
      final doc = VehicleDocument(
        id: 'doc-phase3-01',
        title: 'Dell Precision 5570 Receipt',
        vehicleRegNo: '',
        category: 'electronics',
        documentType: DocumentType.bill,
        localFilePath: dummyFile.path,
        fileChecksumSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        syncStatus: SyncStatus.synced,
        lastModifiedTimestamp: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        requiresAiScan: true,
        visibleFields: const {
          'invoice_number': 'INV-2026-9988',
          'supplier_vat': 'VAT-44556677',
          'total_amount': '\$2,499.00',
        },
        hiddenContext: 'CONFIDENTIAL_MAC_ADDRESS: AA:BB:CC:11:22:33, INTERNAL_SERIAL: SN-DELL-SEC-999',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DocumentViewerScreen(document: doc),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify dynamic visible fields are displayed
      expect(find.text('Invoice Number'), findsOneWidget);
      expect(find.text('INV-2026-9988'), findsOneWidget);
      expect(find.text('Supplier Vat'), findsOneWidget);
      expect(find.text('VAT-44556677'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.text('\$2,499.00'), findsOneWidget);

      // 2. Verify "Pending AI Scan" badge is visible because requiresAiScan == true
      expect(find.text('Pending AI Scan'), findsOneWidget);

      // 3. Verify Ask AI button is available
      expect(find.text('Ask AI'), findsOneWidget);

      // 4. CRITICAL SECURITY CHECK: hiddenContext must NEVER be rendered on the user screen
      expect(find.textContaining('CONFIDENTIAL_MAC_ADDRESS'), findsNothing);
      expect(find.textContaining('AA:BB:CC:11:22:33'), findsNothing);
      expect(find.textContaining('INTERNAL_SERIAL'), findsNothing);
      expect(find.textContaining('SN-DELL-SEC-999'), findsNothing);
    });

    testWidgets('Gracefully handles empty visibleFields without empty boxes or errors', (tester) async {
      final doc = VehicleDocument(
        id: 'doc-phase3-02',
        title: 'Offline Manual Document',
        vehicleRegNo: '',
        category: 'other',
        documentType: DocumentType.custom,
        localFilePath: dummyFile.path,
        fileChecksumSha256: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        syncStatus: SyncStatus.synced,
        lastModifiedTimestamp: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        requiresAiScan: false,
        visibleFields: const {}, // Empty visible fields
        hiddenContext: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DocumentViewerScreen(document: doc),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & category render fine
      expect(find.text('Offline Manual Document'), findsWidgets);
      // No "Pending AI Scan" badge
      expect(find.text('Pending AI Scan'), findsNothing);
      // Ask AI button is still rendered
      expect(find.text('Ask AI'), findsOneWidget);
      // SHA-256 is rendered
      expect(find.textContaining('SHA-256: abcdef12...'), findsOneWidget);
    });
  });
}
