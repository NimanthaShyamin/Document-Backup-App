import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/presentation/screens/auth_gate.dart';
import 'package:vehicle_document_vault/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders LoginScreen branding, Google button, and benefits',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify branding elements
      expect(find.text('Vehicle Document Vault'), findsOneWidget);
      expect(find.text('Secure Personal Vault with Google Drive AppData Backup'),
          findsOneWidget);
      expect(find.text('Offline-First • Private Cloud Sync'), findsOneWidget);

      // Verify Google Sign-In button
      expect(find.text('Sign in with Google'), findsOneWidget);

      // Verify Offline Mode action
      expect(find.text('Continue in Offline Mode'), findsOneWidget);

      // Verify Drive AppData explanation section
      expect(find.text('How Google Drive Backup Works'), findsOneWidget);
      expect(find.text('Private AppData Sandbox'), findsOneWidget);
      expect(find.text('Zero-Latency Offline Mode'), findsOneWidget);
      expect(find.text('Automatic Silent Synchronization'), findsOneWidget);
    });

    testWidgets('Tapping Offline Mode sets offlineBypassProvider to true',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const MaterialApp(
                home: LoginScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially offline bypass should be false
      expect(capturedRef.read(offlineBypassProvider), isFalse);

      // Scroll to button if needed and tap
      final offlineBtn = find.text('Continue in Offline Mode');
      expect(offlineBtn, findsOneWidget);
      await tester.ensureVisible(offlineBtn);
      await tester.tap(offlineBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify state was flipped to true
      expect(capturedRef.read(offlineBypassProvider), isTrue);
    });
  });

  group('AuthGate Widget Tests', () {
    testWidgets('Shows LoginScreen when user is unauthenticated and bypass is false',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthGate(),
          ),
        ),
      );

      // Allow async riverpod stream provider to deliver null user
      await tester.pumpAndSettle();

      // Since unauthenticated, AuthGate displays LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });
}
