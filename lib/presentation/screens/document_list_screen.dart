import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';
import '../utils/document_action_helper.dart';
import '../widgets/cloud_sync_settings_card.dart';
import '../widgets/import_document_metadata_sheet.dart';
import 'document_viewer_screen.dart';
import 'login_screen.dart';

/// Offline-first Document Catalog displaying directly from SQLite WAL storage
/// with Collapsible Statistics Header, Strict Spam/Storage Protection, and Manual Document Import.
class DocumentListScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onNavigateToSettings;

  const DocumentListScreen({
    super.key,
    this.onNavigateToScan,
    this.onNavigateToSettings,
  });

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen>
    with SingleTickerProviderStateMixin {
  /// Strict file import constraints
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB maximum limit
  static const List<String> _allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  /// Collapsible Stats Header visibility toggle state
  bool _isStatsExpanded = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    // Non-blocking background reconciliation and silent auth on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(googleAuthServiceProvider).signInSilently();
      ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
    });
  }

  /// Secure manual document import using file_picker with strict size and format validation.
  Future<void> _handleManualImport(BuildContext context) async {
    if (_isImporting) return;

    try {
      setState(() => _isImporting = true);

      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );

      if (pickedFiles.isEmpty) {
        // User aborted the file picker dialog
        return;
      }

      final pickedFile = pickedFiles.first;
      final filePath = pickedFile.path;

      if (filePath == null) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Unable to locate file on device storage.');
        }
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Selected file does not exist on disk.');
        }
        return;
      }

      // 1. Strict Allowed Formats Validation: [.pdf, .png, .jpg, .jpeg]
      final fileExtension = (pickedFile.extension ?? p.extension(filePath))
          .replaceAll('.', '')
          .toLowerCase();

      if (!_allowedExtensions.contains(fileExtension)) {
        if (context.mounted) {
          _showErrorSnackBar(
            context,
            'Unsupported format: .$fileExtension. Only .pdf, .png, .jpg, and .jpeg files are allowed.',
          );
        }
        return;
      }

      // 2. Strict Spam/Storage Protection: Maximum 5 MB per file
      final fileSize = pickedFile.lengthSync() ?? (await file.length());
      if (fileSize > _maxFileSizeBytes) {
        final fileSizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        if (context.mounted) {
          _showErrorSnackBar(
            context,
            'File size ($fileSizeMb MB) exceeds the strict 5 MB limit. Import aborted to protect vault storage.',
          );
        }
        return;
      }

      // 3. Open metadata confirmation bottom sheet to finalize import with Gemini auto-fill & editability
      if (context.mounted) {
        await ImportDocumentMetadataSheet.show(
          context: context,
          sourceFile: file,
          originalName: pickedFile.name,
          extension: fileExtension,
          fileSize: fileSize,
          onSaveSuccess: () {
            if (context.mounted) {
              _showSuccessSnackBar(
                context,
                'Successfully secured "${pickedFile.name}" into the vault!',
              );
            }
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Document import failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// Displays a user-friendly error SnackBar with distinct styling.
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Displays a user-friendly success SnackBar.
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCloudSyncModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF16161A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const CloudSyncSettingsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(vehicleDocumentsStreamProvider);
    final syncStateAsync = ref.watch(syncEngineStateProvider);
    final userAsync = ref.watch(googleAuthStateProvider);
    final currentUser = userAsync.value;

    // Filter out probe documents directly at screen level for complete UI fidelity
    final rawDocs = docsAsync.value ?? <VehicleDocument>[];
    final realDocs = rawDocs
        .where((d) =>
            !d.vehicleRegNo.startsWith('VERIFY-') &&
            !d.title.toLowerCase().contains('probe'))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.directions_car_filled, color: Colors.amberAccent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vehicle Document Vault',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          // Toggle mechanism for collapsible statistics header
          IconButton(
            tooltip: _isStatsExpanded ? 'Hide Statistics Header' : 'Show Statistics Header',
            icon: Icon(
              _isStatsExpanded ? Icons.bar_chart : Icons.bar_chart_outlined,
              color: _isStatsExpanded ? Colors.amberAccent : Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _isStatsExpanded = !_isStatsExpanded;
              });
            },
          ),
          // Manual Document Import AppBar Action
          IconButton(
            tooltip: 'Import Document (.pdf, .png, .jpg, .jpeg)',
            icon: const Icon(Icons.file_upload_outlined, color: Colors.amberAccent),
            onPressed: () => _handleManualImport(context),
          ),
          IconButton(
            tooltip: currentUser != null
                ? 'Account (${currentUser.email})'
                : 'Google Login & Cloud Backup',
            icon: currentUser != null
                ? (currentUser.photoUrl != null
                    ? CircleAvatar(
                        radius: 13,
                        backgroundImage: NetworkImage(currentUser.photoUrl!),
                      )
                    : const Icon(Icons.account_circle, color: Colors.greenAccent))
                : const Icon(Icons.account_circle_outlined, color: Colors.amberAccent),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(isOpenedFromSettings: true),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Google Drive Sync Settings',
            icon: const Icon(Icons.cloud_sync, color: Colors.amberAccent),
            onPressed: () => _showCloudSyncModal(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: _buildSyncStatusBar(syncStateAsync.value),
        ),
      ),
      // Manual Document Import Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amberAccent,
        foregroundColor: Colors.black87,
        elevation: 4,
        icon: const Icon(Icons.upload_file_rounded, size: 20),
        label: const Text(
          'Import Document',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => _handleManualImport(context),
      ),
      body: Column(
        children: [
          // Collapsible Statistics Header (extracted from scrollable list to top area)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: _isStatsExpanded
                ? _buildCollapsibleStatsHeader(realDocs)
                : const SizedBox.shrink(),
          ),

          // Main document list feed
          Expanded(
            child: docsAsync.when(
              data: (_) {
                if (realDocs.isEmpty) {
                  return _buildEmptyState(context);
                }
                return RefreshIndicator(
                  color: Colors.amberAccent,
                  backgroundColor: const Color(0xFF1E1E24),
                  onRefresh: () async {
                    await ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: realDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = realDocs[index];
                      return _buildDocumentCard(context, doc);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.amberAccent),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading documents: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsible Statistics Header relocated directly below the navigation/AppBar area.
  /// Contains the three summary metric boxes: "Total Docs", "Valid", and "Expiring Soon".
  Widget _buildCollapsibleStatsHeader(List<VehicleDocument> docs) {
    final total = docs.length;
    final expired = docs.where((d) => d.isExpired).length;
    final valid = total - expired;
    final expiringSoon = docs.where((d) {
      if (d.expiryDate == null || d.isExpired) return false;
      return d.expiryDate!.difference(DateTime.now()).inDays <= 30;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16161A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF26262E), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Metric Box 1: Total Docs
          _buildMetricBox(
            label: 'Total Docs',
            count: '$total',
            color: const Color(0xFF38BDF8),
            icon: Icons.folder_shared_outlined,
          ),
          const SizedBox(width: 10),

          // Metric Box 2: Valid
          _buildMetricBox(
            label: 'Valid',
            count: '$valid',
            color: const Color(0xFF4ADE80),
            icon: Icons.verified_outlined,
          ),
          const SizedBox(width: 10),

          // Metric Box 3: Expiring Soon
          _buildMetricBox(
            label: 'Expiring Soon',
            count: '$expiringSoon',
            color: Colors.amberAccent,
            icon: Icons.access_time_outlined,
          ),
        ],
      ),
    );
  }

  /// Single metric box widget inside the collapsible header.
  Widget _buildMetricBox({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 16),
                Text(
                  count,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusBar(SyncEngineState? state) {
    if (state == null || state is SyncEngineIdle) {
      return Container(
        height: 28,
        color: const Color(0xFF16161A),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_done, color: Colors.greenAccent, size: 12),
            SizedBox(width: 6),
            Text(
              'Drive AppData Synced (Offline Ready)',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      );
    } else if (state is SyncEngineSyncing) {
      return Container(
        height: 28,
        color: Colors.amber.withValues(alpha: 0.2),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
            ),
            const SizedBox(width: 8),
            Text(
              state.currentAction,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else if (state is SyncEngineOffline) {
      return Container(
        height: 28,
        color: Colors.grey.withValues(alpha: 0.3),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white70, size: 12),
            SizedBox(width: 6),
            Text(
              'Operating in Offline Mode',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );
    } else if (state is SyncEngineFailed) {
      return Container(
        height: 28,
        color: Colors.red.withValues(alpha: 0.25),
        alignment: Alignment.center,
        child: Text(
          'Sync Paused: ${state.error}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.redAccent, fontSize: 11),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDocumentCard(BuildContext context, VehicleDocument doc) {
    final isExpired = doc.isExpired;

    final cardContent = InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(document: doc),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpired ? Colors.redAccent.withValues(alpha: 0.4) : Colors.white10,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(doc.documentType.icon, color: Colors.amberAccent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        doc.vehicleRegNo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Icon(doc.syncStatus.icon, color: doc.syncStatus.color, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.title,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                  if (doc.policyNo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${doc.policyNo}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildMiniBadge(
                        doc.documentType.label,
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white70,
                      ),
                      if (doc.expiryDate != null)
                        _buildMiniBadge(
                          isExpired ? 'EXPIRED' : 'Expires in ${_daysRemaining(doc.expiryDate!)}d',
                          isExpired ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                          isExpired ? Colors.redAccent : Colors.greenAccent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('doc_${doc.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await DocumentActionHelper.confirmAndDeleteDocument(
          context: context,
          ref: ref,
          document: doc,
        );
      },
      child: cardContent,
    );
  }

  Widget _buildMiniBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  int _daysRemaining(DateTime expiry) {
    return expiry.difference(DateTime.now()).inDays;
  }

  Widget _buildEmptyState(BuildContext context) {
    final user = ref.watch(googleAuthStateProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        children: [
          Icon(Icons.folder_open, size: 56, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text(
            'No Vehicle Documents Found',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Import a document (.pdf, .png, .jpg, .jpeg) or restore backups from Google Drive AppData.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Import Button in Empty State
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _handleManualImport(context),
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              label: const Text(
                'Import Document Now (.pdf, .png, .jpg)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          if (user == null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(isOpenedFromSettings: true),
                    ),
                  );
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text(
                  'Sign In with Google to Restore Backups',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const CloudSyncSettingsCard(),
        ],
      ),
    );
  }
}
