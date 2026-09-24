import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';
import '../widgets/cloud_sync_settings_card.dart';
import 'document_viewer_screen.dart';

/// Offline-first Document Catalog displaying instantly from SQLite WAL storage.
class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  @override
  void initState() {
    super.initState();
    // Non-blocking background reconciliation and silent auth on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(googleAuthServiceProvider).signInSilently();
      ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
    });
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

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.directions_car_filled, color: Colors.amberAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'Vehicle Document Vault',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Google Drive Sync',
            icon: const Icon(Icons.cloud_sync, color: Colors.amberAccent),
            onPressed: () => _showCloudSyncModal(context),
          ),
          IconButton(
            tooltip: 'Force Cloud Reconciliation',
            icon: const Icon(Icons.sync, color: Colors.white70),
            onPressed: () {
              ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: _buildSyncStatusBar(syncStateAsync.value),
        ),
      ),
      body: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            color: Colors.amberAccent,
            backgroundColor: const Color(0xFF1E1E24),
            onRefresh: () async {
              await ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _buildDocumentCard(context, doc);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.amberAccent),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error loading documents: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
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
        color: Colors.amber.withOpacity(0.2),
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
        color: Colors.grey.withOpacity(0.3),
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
        color: Colors.red.withOpacity(0.25),
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

    return InkWell(
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
            color: isExpired ? Colors.redAccent.withOpacity(0.4) : Colors.white10,
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
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                  ),
                  if (doc.policyNo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${doc.policyNo}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMiniBadge(
                        doc.documentType.label,
                        Colors.white.withOpacity(0.1),
                        Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      if (doc.expiryDate != null)
                        _buildMiniBadge(
                          isExpired ? 'EXPIRED' : 'Expires in ${_daysRemaining(doc.expiryDate!)}d',
                          isExpired ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
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

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        children: [
          Icon(Icons.folder_open, size: 56, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 12),
          const Text(
            'No Vehicle Documents Found',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Documents stored locally or synced via Google Drive AppData will appear here instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 24),
          const CloudSyncSettingsCard(),
        ],
      ),
    );
  }
}
