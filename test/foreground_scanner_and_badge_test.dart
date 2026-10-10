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

    testWidgets('Online Sequence: 1st doc scans with NO timer (0s), 2nd doc starts 60s timer, others delay + 60s', (tester) async {
      // 1st document ('doc_1') is actively scanning.
      // 2nd document ('doc_2') has 60s timer.
      // 3rd document ('doc_3') has 120s timer (60 + 60).
      // 4th document ('doc_4') has 180s timer (60 + 120).
      const onlineScanningState = ForegroundScanState(
        status: ScanStatus.scanning,
        isOnline: true,
        activeDocumentId: 'doc_1',
        baseSecondsRemaining: 60,
        pendingQueueIds: ['doc_2', 'doc_3', 'doc_4'],
      );

      // Doc 1 (active): 0s wait
      expect(onlineScanningState.getWaitSecondsFor('doc_1'), 0);
      // Doc 2 (2nd in line): 60s
      expect(onlineScanningState.getWaitSecondsFor('doc_2'), 60);
      // Doc 3 (3rd in line): 120s
      expect(onlineScanningState.getWaitSecondsFor('doc_3'), 120);
      // Doc 4 (4th in line): 180s
      expect(onlineScanningState.getWaitSecondsFor('doc_4'), 180);

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
      // 2nd document renders 60s timer
      expect(find.text('Pending Scan (in 60s)'), findsOneWidget);
      // 3rd document renders 120s timer
      expect(find.text('Pending Scan (in 120s)'), findsOneWidget);
      // 4th document renders 180s timer
      expect(find.text('Pending Scan (in 180s)'), findsOneWidget);
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

    testWidgets('Calculates wait time for Document 3+ (Deep Queue) by adding 60s per position', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foregroundScanStateProvider.overrideWithValue(
              const ForegroundScanState(
                status: ScanStatus.waitingRateLimit,
                baseSecondsRemaining: 55,
                pendingQueueIds: ['doc_2', 'doc_3', 'doc_4'],
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PendingAiScanBadge(
                    documentId: 'doc_2', // index 0: 55s
                    isDark: true,
                  ),
                  PendingAiScanBadge(
                    documentId: 'doc_3', // index 1: 55 + 60 = 115s
                    isDark: true,
                  ),
                  PendingAiScanBadge(
                    documentId: 'doc_4', // index 2: 55 + 120 = 175s
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
      expect(find.text('Pending Scan (in 115s)'), findsOneWidget);
      expect(find.text('Pending Scan (in 175s)'), findsOneWidget);
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
  });
}
