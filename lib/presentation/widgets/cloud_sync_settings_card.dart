import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/constants/drive_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/sync_repository.dart';
import '../../domain/entities/sync_status.dart';
import '../controllers/document_providers.dart';

/// Settings & Authentication Card managing Google Drive AppData synchronization.
/// Supports OAuth sign-in/out, manual reconciliation triggers, and E2E verification probes.
class CloudSyncSettingsCard extends ConsumerStatefulWidget {
  final VoidCallback? onSyncCompleted;

  const CloudSyncSettingsCard({
    super.key,
    this.onSyncCompleted,
  });

  @override
  ConsumerState<CloudSyncSettingsCard> createState() => _CloudSyncSettingsCardState();
}

class _CloudSyncSettingsCardState extends ConsumerState<CloudSyncSettingsCard> {
  bool _isAuthLoading = false;
  bool _isManualSyncing = false;
  bool _isVerifyingE2E = false;
  String? _statusBannerMessage;
  bool _statusBannerIsError = false;
  VerificationProbeResult? _lastProbeResult;

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusBannerMessage = message;
      _statusBannerIsError = isError;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : const Color(0xFF2E7D32),
        duration: Duration(seconds: isError ? 5 : 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleConnectGoogle() async {
    setState(() {
      _isAuthLoading = true;
      _statusBannerMessage = null;
    });

    try {
      final authService = ref.read(googleAuthServiceProvider);
      final account = await authService.signIn();
      _showNotification('Connected successfully as ${account.email}');
    } on DriveAuthException catch (e) {
      _showNotification(e.message, isError: true);
    } catch (e) {
      _showNotification('Google Sign-In failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAuthLoading = false);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'Your local document copies will remain safe on your device. '
          'Background cloud synchronization will be paused until you reconnect.',
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
      _isAuthLoading = true;
      _statusBannerMessage = null;
    });

    try {
      final authService = ref.read(googleAuthServiceProvider);
      await authService.signOut();
      _showNotification('Disconnected from Google Drive.');
    } catch (e) {
      _showNotification('Sign-out failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAuthLoading = false);
      }
    }
  }

  Future<void> _handleManualSync() async {
    setState(() {
      _isManualSyncing = true;
      _statusBannerMessage = null;
    });

    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      await syncRepo.reconcile(interactiveAuth: true);
      _showNotification('Google Drive AppData sync completed successfully.');
      widget.onSyncCompleted?.call();
    } on DriveAuthException catch (e) {
      _showNotification(e.message, isError: true);
    } catch (e) {
      _showNotification('Reconciliation error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  Future<void> _handleTriggerE2EVerification() async {
    setState(() {
      _isVerifyingE2E = true;
      _statusBannerMessage = null;
      _lastProbeResult = null;
    });

    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.triggerEndToEndVerification();

      setState(() {
        _lastProbeResult = result;
      });

      if (result.isSuccess) {
        _showNotification(
          'E2E Verification SUCCESS: Dummy file synced to drive.appdata! (Drive ID: ${result.driveFileId})',
        );
        widget.onSyncCompleted?.call();
      } else {
        _showNotification(
          'E2E Verification probe failed: ${result.errorMessage ?? "Unknown error"}',
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('E2E verification exception: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isVerifyingE2E = false);
      }
    }
  }

  Future<void> _handleQueueBackgroundWorkerProbe() async {
    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final probe = await syncRepo.createVerificationProbeOnly();

      // Trigger immediate one-off WorkManager background worker
      await Workmanager().registerOneOffTask(
        'probeTask_${DateTime.now().millisecondsSinceEpoch}',
        DriveConstants.backgroundSyncTaskKey,
        constraints: Constraints(networkType: NetworkType.connected),
      );

      _showNotification(
        'Background probe ${probe.documentId} enqueued for WorkManager worker execution.',
      );
      widget.onSyncCompleted?.call();
    } catch (e) {
      _showNotification('Failed to schedule background task: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(googleAuthStateProvider);
    final syncEngineAsync = ref.watch(syncEngineStateProvider);

    final currentUser = userAsync.value;
    final isConnected = currentUser != null;
    final engineState = syncEngineAsync.value;
    final isSyncing = engineState is SyncEngineSyncing || _isManualSyncing || _isVerifyingE2E;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConnected ? Colors.amberAccent.withValues(alpha: 0.35) : Colors.white10,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.amberAccent.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.cloud_sync,
                  color: isConnected ? Colors.amberAccent : Colors.white60,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Drive Vault Sync',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isConnected
                          ? 'Private AppData Sandbox Active'
                          : 'Silent cloud backup disconnected',
                      style: TextStyle(
                        color: isConnected ? Colors.greenAccent : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(isConnected, isSyncing),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // User Profile or Disconnected Pitch
          if (isConnected) ...[
            _buildConnectedProfile(currentUser),
            const SizedBox(height: 18),
            _buildActionButtons(isSyncing, engineState),
          ] else ...[
            _buildDisconnectedPitch(),
            const SizedBox(height: 18),
            _buildConnectButton(),
          ],

          // Inline Status / Error Message
          if (_statusBannerMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusBannerIsError
                    ? Colors.redAccent.withValues(alpha: 0.15)
                    : Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _statusBannerIsError
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : Colors.greenAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusBannerIsError ? Icons.error_outline : Icons.check_circle_outline,
                    color: _statusBannerIsError ? Colors.redAccent : Colors.greenAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusBannerMessage!,
                      style: TextStyle(
                        color: _statusBannerIsError ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // E2E Verification & Debug Diagnostics Section
          const SizedBox(height: 20),
          _buildE2EVerificationSection(isConnected, isSyncing),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isConnected, bool isSyncing) {
    if (isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
            ),
            SizedBox(width: 6),
            Text(
              'Syncing',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withValues(alpha: 0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.circle_outlined,
            size: 12,
            color: isConnected ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 5),
          Text(
            isConnected ? 'Connected' : 'Offline',
            style: TextStyle(
              color: isConnected ? Colors.greenAccent : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedProfile(dynamic account) {
    final email = account?.email ?? 'Unknown User';
    final displayName = account?.displayName;
    final photoUrl = account?.photoUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.amberAccent.withValues(alpha: 0.25),
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
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayName != null && displayName.isNotEmpty)
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                SelectableText(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 11, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Scope: drive.appdata (Isolated)',
                      style: TextStyle(
                        color: Colors.amberAccent.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Disconnect Account',
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
            onPressed: _isAuthLoading ? null : _handleDisconnect,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedPitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect your Google Account to protect your certificates and licenses against device loss.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 14, color: Colors.amberAccent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hidden AppData sandbox: Invisible in Google Drive UI, safe from accidental user deletion.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isAuthLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.login, size: 20),
        label: Text(
          _isAuthLoading ? 'Connecting Google Account...' : 'Connect Google Drive',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: _isAuthLoading ? null : _handleConnectGoogle,
      ),
    );
  }

  Widget _buildActionButtons(bool isSyncing, SyncEngineState? engineState) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(
                isSyncing ? 'Reconciling...' : 'Sync Now',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: isSyncing ? null : _handleManualSync,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            onPressed: isSyncing
                ? null
                : () {
                    ref.read(googleAuthServiceProvider).signInSilently(reAuthenticate: true);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildE2EVerificationSection(bool isConnected, bool isSyncing) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'OAuth & Drive AppData Verification',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEBUG E2E',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Generates a local sandboxed probe (.txt), flags it as pending_upload, and synchronizes live to drive.appdata to verify REST API scopes & token permissions.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Run E2E Test | Enqueue Background Probe
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E2E38),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: _isVerifyingE2E
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                      )
                    : const Icon(Icons.play_arrow_rounded, color: Colors.amberAccent, size: 18),
                label: Text(
                  _isVerifyingE2E ? 'Verifying E2E Probe...' : 'Verify Live Sync (Foreground)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: (!isConnected || isSyncing) ? null : _handleTriggerE2EVerification,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.schedule, size: 14, color: Colors.white60),
                label: const Text(
                  'Queue Background Worker',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: (!isConnected || isSyncing) ? null : _handleQueueBackgroundWorkerProbe,
              ),
            ],
          ),

          // Probe Result Display Card
          if (_lastProbeResult != null) ...[
            const SizedBox(height: 12),
            _buildProbeResultCard(_lastProbeResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildProbeResultCard(VerificationProbeResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.isSuccess ? const Color(0xFF17281D) : const Color(0xFF2C1919),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result.isSuccess ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isSuccess ? Icons.verified : Icons.cancel_outlined,
                color: result.isSuccess ? Colors.greenAccent : Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                result.isSuccess ? 'End-to-End Verification PASSED' : 'Verification FAILED',
                style: TextStyle(
                  color: result.isSuccess ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildResultField('Document ID', result.documentId),
          _buildResultField('Checksum SHA-256', result.checksum),
          if (result.driveFileId != null)
            _buildResultField('Drive File ID (appDataFolder)', result.driveFileId!),
          if (result.errorMessage != null)
            _buildResultField('Error', result.errorMessage!),
          _buildResultField('Local Sandbox Path', result.localPath),
        ],
      ),
    );
  }

  Widget _buildResultField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10, color: Colors.white70),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
