import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/presentation/controllers/foreground_scanner_service.dart';
import 'package:vehicle_document_vault/presentation/widgets/pending_ai_scan_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForegroundScanner State & PendingAiScanBadge UI Tests', () {
    testWidgets('Renders Pending AI Scan and Scan Now button when state is idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(
              const ForegroundScanState(status: ScanStatus.idle),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingAiScanBadge(
                documentId: 'doc_idle_1',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending AI Scan'), findsOneWidget);
      expect(find.text('Scan Now'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Offline Mode: all countdown timers are stopped and badge shows Pending AI Scan with cloud_off icon', (tester) async {
      const offlineState = ForegroundScanState(
        status: ScanStatus.offline,
        isOnline: false,
        baseSecondsRemaining: 0,
        pendingQueueIds: ['doc_off_1', 'doc_off_2', 'doc_off_3'],
      );

      // Verify state level: getWaitSecondsFor returns null for all documents when offline
      expect(offlineState.getWaitSecondsFor('doc_off_1'), isNull);
      expect(offlineState.getWaitSecondsFor('doc_off_2'), isNull);
      expect(offlineState.getWaitSecondsFor('doc_off_3'), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(offlineState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingAiScanBadge(
                documentId: 'doc_off_1',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending AI Scan'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });

    testWidgets('Offline Mode: tapping Scan Now shows offline alert SnackBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(
              const ForegroundScanState(
                status: ScanStatus.offline,
                isOnline: false,
                pendingQueueIds: ['doc_off_1'],
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingAiScanBadge(
                documentId: 'doc_off_1',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Scan Now while offline
      await tester.tap(find.text('Scan Now'));
      await tester.pump();

      expect(find.text('Cannot scan while offline. Connect to the internet to scan.'), findsOneWidget);
    });

    testWidgets('Online Sequence: 1st doc scans with NO timer (0s), others remain dormant without timer during scan', (tester) async {
      // 1st document ('doc_1') is actively scanning with no timer.
      // 2nd, 3rd, 4th documents do NOT have active timers while 1st doc is scanning.
      const onlineScanningState = ForegroundScanState(
        status: ScanStatus.scanning,
        isOnline: true,
        activeDocumentId: 'doc_1',
        baseSecondsRemaining: 0,
        pendingQueueIds: ['doc_2', 'doc_3', 'doc_4'],
      );

      // Doc 1 (active): 0s wait
      expect(onlineScanningState.getWaitSecondsFor('doc_1'), 0);
      // Doc 2, 3, 4: no countdown timer runs while 1st doc is scanning
      expect(onlineScanningState.getWaitSecondsFor('doc_2'), isNull);
      expect(onlineScanningState.getWaitSecondsFor('doc_3'), isNull);
      expect(onlineScanningState.getWaitSecondsFor('doc_4'), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(onlineScanningState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PendingAiScanBadge(documentId: 'doc_1', isDark: true),
                  PendingAiScanBadge(documentId: 'doc_2', isDark: true),
                  PendingAiScanBadge(documentId: 'doc_3', isDark: true),
                  PendingAiScanBadge(documentId: 'doc_4', isDark: true),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1st document renders active scanning with progress indicators
      expect(find.text('Scanning Document...'), findsOneWidget);
      // Other queued documents render Pending AI Scan without countdown numbers
      expect(find.text('Pending AI Scan'), findsNWidgets(3));
    });

    testWidgets('Renders countdown timer and Scan Now button for Document 2 (next in line)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(
              const ForegroundScanState(
                status: ScanStatus.waitingRateLimit,
                activeDocumentId: 'doc_rate_limit_1',
                baseSecondsRemaining: 45,
                pendingQueueIds: ['doc_rate_limit_1', 'doc_rate_limit_2'],
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingAiScanBadge(
                documentId: 'doc_rate_limit_1',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Scan (in 45s)'), findsOneWidget);
      expect(find.text('Scan Now'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('When previous scan finishes: only next doc in line displays 60s cooldown timer', (tester) async {
      const rateLimitState = ForegroundScanState(
        status: ScanStatus.waitingRateLimit,
        activeDocumentId: 'doc_2',
        baseSecondsRemaining: 55,
        pendingQueueIds: ['doc_2', 'doc_3', 'doc_4'],
      );

      // Next in line: 55s
      expect(rateLimitState.getWaitSecondsFor('doc_2'), 55);
      // Deep queue documents: wait in queue without ticking timers
      expect(rateLimitState.getWaitSecondsFor('doc_3'), isNull);
      expect(rateLimitState.getWaitSecondsFor('doc_4'), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(rateLimitState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PendingAiScanBadge(
                    documentId: 'doc_2', // next in line: 55s
                    isDark: true,
                  ),
                  PendingAiScanBadge(
                    documentId: 'doc_3', // in queue
                    isDark: true,
                  ),
                  PendingAiScanBadge(
                    documentId: 'doc_4', // in queue
                    isDark: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Scan (in 55s)'), findsOneWidget);
      expect(find.text('Pending AI Scan'), findsNWidgets(2));
      expect(find.text('Scan Now'), findsNWidgets(3));
    });

    testWidgets('Renders Scanning Document... with LinearProgressIndicator when actively scanning', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(
              const ForegroundScanState(
                status: ScanStatus.scanning,
                activeDocumentId: 'doc_scanning_1',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingAiScanBadge(
                documentId: 'doc_scanning_1',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Scanning Document...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // "Scan Now" button should be hidden while already scanning this document
      expect(find.text('Scan Now'), findsNothing);
    });

    testWidgets('Waiting for Backup: displays "Waiting for Backup" badge with cloud_upload icon and null wait seconds', (tester) async {
      const backupState = ForegroundScanState(
        status: ScanStatus.waitingBackup,
        isOnline: true,
        baseSecondsRemaining: 0,
        pendingQueueIds: ['doc_backup_1', 'doc_backup_2'],
      );

      // Verify timers are suppressed
      expect(backupState.getWaitSecondsFor('doc_backup_1'), isNull);
      expect(backupState.getWaitSecondsFor('doc_backup_2'), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(backupState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingAiScanBadge(
                documentId: 'doc_backup_1',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for Backup'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });
  });
}
