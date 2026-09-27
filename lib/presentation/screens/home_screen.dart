import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';
import 'document_viewer_screen.dart';

/// Vault Catalog Home Screen with Apple Liquid Glass styling,
/// Categorized / Flat view switching, and metrics.
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToScan;
  final VoidCallback onNavigateToSettings;

  const HomeScreen({
    super.key,
    required this.onNavigateToScan,
    required this.onNavigateToSettings,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(vehicleDocumentsStreamProvider);
    final syncStateAsync = ref.watch(syncEngineStateProvider);
    final userAsync = ref.watch(googleAuthStateProvider);
    final currentUser = userAsync.value;
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isCategorized = ref.watch(categorizedViewProvider);
    final language = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: LiquidGlassTheme.accentAmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_car_filled,
                color: LiquidGlassTheme.accentAmber,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.get('app_title', language),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Status',
            icon: Icon(
              currentUser != null ? Icons.cloud_done : Icons.cloud_off,
              color: currentUser != null ? Colors.greenAccent : Colors.white38,
              size: 22,
            ),
            onPressed: widget.onNavigateToSettings,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: currentUser != null && currentUser.photoUrl != null
                ? CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(currentUser.photoUrl!),
                  )
                : const Icon(Icons.settings_outlined),
            onPressed: widget.onNavigateToSettings,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: docsAsync.when(
        data: (docs) {
          final filteredDocs = docs.where((doc) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return doc.vehicleRegNo.toLowerCase().contains(query) ||
                doc.title.toLowerCase().contains(query) ||
                (doc.policyNo?.toLowerCase().contains(query) ?? false);
          }).toList();

          return RefreshIndicator(
            color: LiquidGlassTheme.accentAmber,
            onRefresh: () async {
              await ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 110.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sync Status Badge
                  _buildSyncStatusBar(syncStateAsync.value, isLiquidGlass, language),
                  const SizedBox(height: 14),

                  // Quick Stats Row
                  _buildStatsRow(docs, isLiquidGlass, language, isDark),
                  const SizedBox(height: 16),

                  // Search Field
                  _buildSearchBar(isLiquidGlass, language, isDark),
                  const SizedBox(height: 18),

                  if (docs.isEmpty) ...[
                    _buildEmptyState(isLiquidGlass, language, isDark),
                  ] else if (filteredDocs.isEmpty) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No documents match "$_searchQuery"',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ] else if (isCategorized) ...[
                    // Categorized View
                    _buildCategorizedSections(context, filteredDocs, isLiquidGlass, language, isDark),
                  ] else ...[
                    // Flat View
                    _buildFlatDocumentList(context, filteredDocs, isLiquidGlass, isDark),
                  ],

                  const SizedBox(height: 90), // Space for floating bottom dock
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: LiquidGlassTheme.accentAmber),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBar(SyncEngineState? state, bool isLiquidGlass, AppLanguage language) {
    String text = AppStrings.get('cloud_connected', language);
    Color color = Colors.greenAccent;
    IconData icon = Icons.cloud_done;

    if (state is SyncEngineOffline) {
      text = AppStrings.get('cloud_offline', language);
      color = Colors.amberAccent;
      icon = Icons.cloud_off;
    } else if (state is SyncEngineSyncing) {
      text = state.currentAction;
      color = LiquidGlassTheme.accentAmber;
      icon = Icons.sync;
    }

    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    List<VehicleDocument> docs,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    final total = docs.length;
    final expired = docs.where((d) => d.isExpired).length;
    final valid = total - expired;
    final expiringSoon = docs.where((d) {
      if (d.expiryDate == null || d.isExpired) return false;
      return d.expiryDate!.difference(DateTime.now()).inDays <= 30;
    }).length;

    return Row(
      children: [
        _buildStatCard(
          label: AppStrings.get('summary_total', language),
          count: '$total',
          color: LiquidGlassTheme.accentBlue,
          isLiquidGlass: isLiquidGlass,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          label: AppStrings.get('summary_active', language),
          count: '$valid',
          color: Colors.greenAccent,
          isLiquidGlass: isLiquidGlass,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          label: AppStrings.get('summary_expiring', language),
          count: '$expiringSoon',
          color: LiquidGlassTheme.accentAmber,
          isLiquidGlass: isLiquidGlass,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String count,
    required Color color,
    required bool isLiquidGlass,
    required bool isDark,
  }) {
    return Expanded(
      child: LiquidGlassCard(
        isLiquidGlass: isLiquidGlass,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        radius: 16,
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isLiquidGlass, AppLanguage language, bool isDark) {
    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      radius: 16,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          icon: Icon(
            Icons.search,
            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            size: 20,
          ),
          hintText: AppStrings.get('search_hint', language),
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            fontSize: 13,
          ),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategorizedSections(
    BuildContext context,
    List<VehicleDocument> docs,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    final Map<DocumentType, List<VehicleDocument>> grouped = {};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.documentType, () => []).add(doc);
    }

    return Column(
      children: DocumentType.values.map((type) {
        final categoryDocs = grouped[type] ?? [];
        if (categoryDocs.isEmpty) return const SizedBox.shrink();

        String typeLabel = type.label;
        switch (type) {
          case DocumentType.fuelQr:
            typeLabel = AppStrings.get('cat_fuel_qr', language);
            break;
          case DocumentType.insuranceCard:
            typeLabel = AppStrings.get('cat_insurance', language);
            break;
          case DocumentType.revenueLicense:
            typeLabel = AppStrings.get('cat_revenue', language);
            break;
          case DocumentType.custom:
            typeLabel = AppStrings.get('cat_custom', language);
            break;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header
              Row(
                children: [
                  Icon(type.icon, size: 18, color: LiquidGlassTheme.accentAmber),
                  const SizedBox(width: 8),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.accentAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${categoryDocs.length}',
                      style: const TextStyle(
                        color: LiquidGlassTheme.accentAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category Cards
              ...categoryDocs.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: _buildDocumentCard(context, doc, isLiquidGlass, isDark),
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlatDocumentList(
    BuildContext context,
    List<VehicleDocument> docs,
    bool isLiquidGlass,
    bool isDark,
  ) {
    return Column(
      children: docs.map((doc) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDocumentCard(context, doc, isLiquidGlass, isDark),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    VehicleDocument doc,
    bool isLiquidGlass,
    bool isDark,
  ) {
    final isExpired = doc.isExpired;

    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.all(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(document: doc),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              doc.documentType.icon,
              color: LiquidGlassTheme.accentAmber,
              size: 24,
            ),
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
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Icon(doc.syncStatus.icon, color: doc.syncStatus.color, size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  doc.title,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 12,
                  ),
                ),
                if (doc.policyNo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${doc.policyNo}',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniBadge(
                      doc.documentType.label,
                      isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 8),
                    if (doc.expiryDate != null)
                      _buildMiniBadge(
                        isExpired ? 'EXPIRED' : 'Expires in ${_daysRemaining(doc.expiryDate!)}d',
                        isExpired
                            ? Colors.red.withValues(alpha: 0.18)
                            : Colors.green.withValues(alpha: 0.18),
                        isExpired ? Colors.redAccent : Colors.greenAccent,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white24 : Colors.black26,
            size: 20,
          ),
        ],
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

  Widget _buildEmptyState(bool isLiquidGlass, AppLanguage language, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 12),
        child: Column(
          children: [
            LiquidGlassCard(
              isLiquidGlass: isLiquidGlass,
              padding: const EdgeInsets.all(24),
              radius: 28,
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 52,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.get('empty_title', language),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.get('empty_subtitle', language),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidGlassTheme.accentAmber,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: widget.onNavigateToScan,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(
                        AppStrings.get('btn_quick_scan', language),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
