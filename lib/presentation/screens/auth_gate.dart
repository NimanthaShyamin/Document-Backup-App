import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/document_providers.dart';
import 'login_screen.dart';
import 'main_shell_screen.dart';

/// Provider tracking whether the user chose to bypass Google Sign-In for an offline session.
final offlineBypassProvider = StateProvider<bool>((ref) => false);

/// Central authentication routing gate.
/// Seamlessly directs authenticated users to the document vault,
/// unauthenticated users to the Google Login Screen,
/// or respects the user's explicit choice to operate in local offline mode.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(googleAuthStateProvider);
    final isOfflineBypass = ref.watch(offlineBypassProvider);

    return authState.when(
      data: (user) {
        if (user != null || isOfflineBypass) {
          return const MainShellScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF121214),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E24),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car_filled,
                    color: Colors.amberAccent,
                    size: 36,
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.amberAccent,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => const LoginScreen(),
    );
  }
}
