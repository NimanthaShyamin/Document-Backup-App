import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/domain/entities/document_type.dart';
import 'package:vehicle_document_vault/domain/entities/sync_status.dart';
import 'package:vehicle_document_vault/domain/entities/vehicle_document.dart';
import 'package:vehicle_document_vault/presentation/controllers/document_providers.dart';
import 'package:vehicle_document_vault/presentation/screens/document_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleDocs = [
    VehicleDocument(
      id: 'doc_1',
      documentType: DocumentType.revenueLicense,
      title: 'Annual Revenue License',
      vehicleRegNo: 'WP CAB-1234',
      policyNo: 'REV-9921',
      expiryDate: DateTime.now().add(const Duration(days: 15)), // Expiring soon
      localFilePath: '/mock/path/rev.pdf',
      driveFileId: 'drive_1',
      fileChecksumSha256: 'sha256_1',
      syncStatus: SyncStatus.synced,
      lastModifiedTimestamp: DateTime.now(),
      createdAt: DateTime.now(),
    ),
    VehicleDocument(
      id: 'doc_2',
      documentType: DocumentType.insuranceCard,
      title: 'Comprehensive Insurance',
      vehicleRegNo: 'WP CAB-1234',
      policyNo: 'POL-1002',
      expiryDate: DateTime.now().add(const Duration(days: 180)), // Valid, not expiring soon
      localFilePath: '/mock/path/ins.png',
      driveFileId: 'drive_2',
      fileChecksumSha256: 'sha256_2',
      syncStatus: SyncStatus.synced,
      lastModifiedTimestamp: DateTime.now(),
      createdAt: DateTime.now(),
    ),
    // A probe document that MUST be filtered out
    VehicleDocument(
      id: 'probe_test_123',
      documentType: DocumentType.custom,
      title: 'E2E Verification Probe (probe_test_123)',
      vehicleRegNo: 'VERIFY-E2E',
      policyNo: 'PROBE-SYNC-OK',
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      localFilePath: '/mock/path/probe.txt',
      driveFileId: 'drive_probe',
      fileChecksumSha256: 'sha256_probe',
      syncStatus: SyncStatus.synced,
      lastModifiedTimestamp: DateTime.now(),
      createdAt: DateTime.now(),
    ),
  ];

  Widget createSubject({List<VehicleDocument>? docs}) {
    return ProviderScope(
      overrides: [
        vehicleDocumentsStreamProvider.overrideWith(
          (ref) => Stream.value(docs ?? sampleDocs),
        ),
      ],
      child: const MaterialApp(
        home: DocumentListScreen(),
      ),
    );
  }

  group('DocumentListScreen Tests', () {
    testWidgets('Renders AppBar and Floating Action Button for manual import', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Document Vault'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Import Document'), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
    });

    testWidgets('Collapsible Stats Header displays correct metrics and toggles visibility', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Verify the three metric boxes are present
      expect(find.text('Total Docs'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('Expiring Soon'), findsOneWidget);

      // Total docs should be 2 (because probe document VERIFY-E2E must be excluded!)
      expect(find.text('2'), findsWidgets); // Total: 2, Valid: 2
      expect(find.text('1'), findsWidgets); // Expiring soon: 1

      // Find the toggle button in AppBar
      final toggleButton = find.byTooltip('Hide Statistics Header');
      expect(toggleButton, findsOneWidget);

      // Tap to collapse
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Now tooltip should update to 'Show Statistics Header'
      expect(find.byTooltip('Show Statistics Header'), findsOneWidget);

      // Tap again to unhide
      await tester.tap(find.byTooltip('Show Statistics Header'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide Statistics Header'), findsOneWidget);
      expect(find.text('Total Docs'), findsOneWidget);
    });

    testWidgets('Strictly strips and excludes VERIFY-E2E probe documents from document feed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Real documents must be displayed
      expect(find.text('Annual Revenue License'), findsOneWidget);
      expect(find.text('Comprehensive Insurance'), findsOneWidget);

      // Probe document MUST NOT appear anywhere in the feed
      expect(find.text('VERIFY-E2E'), findsNothing);
      expect(find.textContaining('Verification Probe'), findsNothing);
    });

    testWidgets('Shows Empty State with manual import button when vault has no real docs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pass empty list or only probe document
      await tester.pumpWidget(createSubject(docs: []));
      await tester.pumpAndSettle();

      expect(find.text('No Vehicle Documents Found'), findsOneWidget);
      expect(find.text('Import Document Now (.pdf, .png, .jpg)'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // 0 in total docs
    });
  });
}
