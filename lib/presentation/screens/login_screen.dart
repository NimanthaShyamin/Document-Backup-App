import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/exceptions.dart';
import '../controllers/document_providers.dart';
import 'auth_gate.dart';
import 'main_shell_screen.dart';

/// Dedicated, premium Login and Cloud Backup Authentication Screen.
/// Manages Google Drive AppData authorization, account switching,
/// offline fallback mode, and live Drive connection testing.
class LoginScreen extends ConsumerStatefulWidget {
  /// When true, navigating 'back' or 'continue' will simply pop the current screen
  /// instead of replacing the entire navigation stack.
  final bool isOpenedFromSettings;

  const LoginScreen({
    super.key,
    this.isOpenedFromSettings = false,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isTestingConnection = false;
  bool? _connectionTestPassed;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();

    // Attempt silent sign-in in background on initial view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(googleAuthServiceProvider).signInSilently();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _proceedToVault() {
    ref.read(offlineBypassProvider.notifier).state = true;
    if (widget.isOpenedFromSettings && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainShellScreen(),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _connectionTestPassed = null;
    });

    try {
      final authService = ref.read(googleAuthServiceProvider);
      final account = await authService.signIn();

      setState(() {
        _successMessage = 'Welcome, ${account.displayName ?? account.email}!';
      });

      // Trigger delta sync upon successful login
      try {
        await ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
      } catch (syncErr) {
        developer.log('Initial sync attempt: $syncErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Signed in as ${account.email}. Google Drive AppData backup enabled.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2D24),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on DriveAuthException catch (e) {
      developer.log('Google Sign-In failed', error: e);
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      developer.log('Unexpected sign-in error', error: e);
      setState(() {
        _errorMessage = 'Sign-in failed. Please verify your internet connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'Your local document files remain safe on your device. '
          'Cloud synchronization to Google Drive AppData will be paused.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _connectionTestPassed = null;
    });

    try {
      ref.read(offlineBypassProvider.notifier).state = false;
      final authService = ref.read(googleAuthServiceProvider);
      await authService.signOut();
      setState(() {
        _successMessage = 'Successfully disconnected from Google Drive.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-out failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testDriveConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestPassed = null;
    });

    try {
      final authService = ref.read(googleAuthServiceProvider);
      final isWorking = await authService.testDriveConnection();
      setState(() {
        _connectionTestPassed = isWorking;
      });
    } catch (_) {
      setState(() {
        _connectionTestPassed = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(googleAuthStateProvider);
    final user = userAsync.value;
    final isSignedIn = user != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: (widget.isOpenedFromSettings || Navigator.of(context).canPop())
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (!isSignedIn)
            TextButton.icon(
              onPressed: _proceedToVault,
              icon: const Icon(Icons.skip_next, color: Colors.amberAccent, size: 18),
              label: const Text(
                'Offline Mode',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  // App Branding Hero Section
                  _buildHeroHeader(),

                  const SizedBox(height: 28),

                  // Status / Error / Success Banners
                  if (_errorMessage != null) ...[
                    _buildFeedbackBanner(
                      message: _errorMessage!,
                      isError: true,
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_successMessage != null) ...[
                    _buildFeedbackBanner(
                      message: _successMessage!,
                      isError: false,
                      onDismiss: () => setState(() => _successMessage = null),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Core Authentication Card
                  if (isSignedIn)
                    _buildAuthenticatedCard(user)
                  else
                    _buildUnauthenticatedCard(),

                  const SizedBox(height: 24),

                  // Drive AppData Architecture Features
                  _buildCloudBackupBenefits(),

                  const SizedBox(height: 24),

                  // Footer note
                  Text(
                    'Protected by AES & SHA-256 local verification • Google Drive AppData Sandbox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFFFB300),
                Color(0xFF1E1E24),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF16161A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.amberAccent,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Vehicle Document Vault',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Secure Personal Vault with Google Drive AppData Backup',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.amberAccent),
              SizedBox(width: 6),
              Text(
                'Offline-First • Private Cloud Sync',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner({
    required String message,
    required bool isError,
    required VoidCallback onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? Colors.redAccent.withValues(alpha: 0.15)
            : Colors.greenAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? Colors.redAccent.withValues(alpha: 0.4)
              : Colors.greenAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.redAccent : Colors.greenAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.redAccent.shade100 : Colors.greenAccent.shade100,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.close,
              size: 16,
              color: isError ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Colors.amberAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive Sync',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Automated & private backup',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Sign in with your Google Account to automatically back up your digital fuel passes, insurance certificates, and revenue licenses.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF151518),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 16, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stored in hidden drive.appdata folder. Never exposed publicly and protected from accidental deletion.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Google Sign-In Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Connecting to Google...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGoogleIcon(),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign in with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Offline fallback button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _proceedToVault,
              icon: const Icon(Icons.flash_on, size: 16, color: Colors.amberAccent),
              label: const Text(
                'Continue in Offline Mode',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedCard(GoogleSignInAccount user) {
    final email = user.email;
    final displayName = user.displayName;
    final photoUrl = user.photoUrl;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amberAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amberAccent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Connected Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Connected Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      'Drive Active',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // User Profile Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF151518),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          (displayName?.isNotEmpty == true
                                  ? displayName![0]
                                  : email.isNotEmpty
                                      ? email[0]
                                      : 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayName != null && displayName.isNotEmpty)
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      SelectableText(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 11, color: Colors.amberAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Scope: drive.appdata (Sandboxed)',
                            style: TextStyle(
                              color: Colors.amberAccent.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Connection Test Pill / Result
          if (_connectionTestPassed != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _connectionTestPassed!
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _connectionTestPassed!
                      ? Colors.greenAccent.withValues(alpha: 0.4)
                      : Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionTestPassed! ? Icons.verified : Icons.cancel,
                    color: _connectionTestPassed! ? Colors.greenAccent : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionTestPassed!
                          ? 'Google Drive AppData API connection verified.'
                          : 'Drive API connection test failed. Check token/permissions.',
                      style: TextStyle(
                        color: _connectionTestPassed!
                            ? Colors.greenAccent.shade100
                            : Colors.redAccent.shade100,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Primary Button: Proceed to Vault
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _proceedToVault,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text(
                'Open Vehicle Vault',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Actions Row: Test Drive Connection & Sign Out
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isTestingConnection ? null : _testDriveConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.amberAccent,
                          ),
                        )
                      : const Icon(Icons.network_ping, size: 16),
                  label: const Text('Test Drive', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleSignOut,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBackupBenefits() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'How Google Drive Backup Works',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBenefitItem(
            icon: Icons.cloud_done,
            title: 'Private AppData Sandbox',
            subtitle:
                'Documents upload to Google Drive\'s private app data folder, completely separate from your general Drive files.',
          ),
          const SizedBox(height: 10),
          _buildBenefitItem(
            icon: Icons.offline_bolt,
            title: 'Zero-Latency Offline Mode',
            subtitle:
                'SQLite database with WAL mode ensures all vehicle documents open instantly without internet access.',
          ),
          const SizedBox(height: 10),
          _buildBenefitItem(
            icon: Icons.sync,
            title: 'Automatic Silent Synchronization',
            subtitle:
                'Edits and additions queue locally and synchronize silently to Google Drive as soon as network is restored.',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.amberAccent, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

/// Custom painter for the Google "G" brand icon
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Draw Google 4-color arcs
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -0.785, 1.57, true, paintBlue); // Right blue
    canvas.drawArc(rect, 0.785, 1.57, true, paintGreen); // Bottom green
    canvas.drawArc(rect, 2.355, 1.57, true, paintYellow); // Left yellow
    canvas.drawArc(rect, 3.925, 1.57, true, paintRed); // Top red

    // Inner cutout to make it a ring
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.58, innerPaint);

    // Cross bar for "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(w * 0.45, h * 0.40, w * 0.98, h * 0.60),
      barPaint,
    );

    // Top-right cutout
    final cutoutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final cutoutPath = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..lineTo(w, h * 0.5)
      ..lineTo(w, 0)
      ..lineTo(w * 0.5, 0)
      ..close();
    canvas.drawPath(cutoutPath, cutoutPaint);

    // Re-draw Blue bar across
    canvas.drawRect(
      Rect.fromLTRB(w * 0.48, h * 0.40, w * 0.96, h * 0.60),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
