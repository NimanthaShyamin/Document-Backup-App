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
