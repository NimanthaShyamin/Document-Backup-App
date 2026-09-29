import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/localization/app_language.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';
import '../utils/document_action_helper.dart';
import '../widgets/import_document_metadata_sheet.dart';
import 'document_viewer_screen.dart';
import 'folder_contents_screen.dart';

/// Vault Catalog Home Screen — folder-based categorized view with smart cross-linking,
/// iOS-style popup delete, beautiful app-bar search, and keyboard dismiss on tap-outside.
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Search ──────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // ── Flat-view popup-delete ──────────────────────────────────────────
  String? _popupDocId;
  late final AnimationController _popupAnimCtrl;
  late final Animation<double> _popupAnim;

  // ── UI state ────────────────────────────────────────────────────────
  String? _statusFilter;
  bool _isStatsExpanded = true;
  bool _isImporting = false;

  static const int _maxFileSizeBytes = 5 * 1024 * 1024;
  static const List<String> _allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  @override
  void initState() {
    super.initState();
    _popupAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _popupAnim = CurvedAnimation(
        parent: _popupAnimCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _popupAnimCtrl.dispose();
    super.dispose();
  }

  void _enterPopup(String docId) {
    setState(() => _popupDocId = docId);
    _popupAnimCtrl.forward(from: 0);
  }

  void _exitPopup() {
    _popupAnimCtrl.reverse().then((_) {
      if (mounted) setState(() => _popupDocId = null);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(vehicleDocumentsStreamProvider);
    final syncAsync = ref.watch(syncEngineStateProvider);
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isCategorized = ref.watch(categorizedViewProvider);
    final language = ref.watch(appLanguageProvider);
    final searchVisible = ref.watch(searchVisibleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync search focus when search becomes visible
    if (searchVisible && !_searchFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted && ref.read(searchVisibleProvider)) {
          _searchFocusNode.requestFocus();
        }
      });
    } else if (!searchVisible) {
      if (_searchFocusNode.hasFocus) _searchFocusNode.unfocus();
      if (_searchQuery.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _searchController.clear();
            setState(() => _searchQuery = '');
          }
        });
      }
    }

    return GestureDetector(
      onTap: () {
        if (_popupDocId != null) _exitPopup();
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 76, right: 6),
          child: FloatingActionButton.extended(
            heroTag: 'home_fab_import_doc',
            elevation: 6,
            backgroundColor:
                isDark ? LiquidGlassTheme.accentElectricBlue : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            onPressed: () => _handleManualImport(context),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Import Document',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2),
            ),
          ),
        ),
        appBar: _buildAppBar(searchVisible, isLiquidGlass, language, isDark),
        body: docsAsync.when(
          data: (docs) {
            final realDocs = docs
                .where((d) =>
                    !d.vehicleRegNo.startsWith('VERIFY-') &&
                    !d.title.toLowerCase().contains('probe'))
                .toList();

            final filteredDocs = _applyFilters(realDocs);

            return Column(
              children: [
                // Stats header
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _isStatsExpanded
                      ? Padding(
                          padding:
                              const EdgeInsets.fromLTRB(18, 4, 18, 10),
                          child: _buildStatsRow(
                              realDocs, isLiquidGlass, language, isDark),
                        )
                      : const SizedBox.shrink(),
                ),

                // Document content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(18, 4, 18, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSyncStatusBar(
                            syncAsync.value, isLiquidGlass, language),
                        const SizedBox(height: 14),

                        if (_statusFilter != null) ...[
                          _buildActiveFilterBadge(isDark),
                          const SizedBox(height: 12),
                        ],

                        if (realDocs.isEmpty)
                          _buildEmptyState(isLiquidGlass, language, isDark)
                        else if (filteredDocs.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No documents match "$_searchQuery"'
                                    : 'No documents in "${_statusFilter!.toUpperCase()}" category',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else if (isCategorized)
                          _buildFolderGrid(
                              context,
                              filteredDocs,
                              realDocs,
                              isLiquidGlass,
                              language,
                              isDark)
                        else
                          _buildFlatList(
                              context, filteredDocs, isLiquidGlass, isDark),

                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: LiquidGlassTheme.accentAmber),
          ),
          error: (err, _) => Center(
            child: Text('Error: $err',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool searchVisible, bool isLiquidGlass,
      AppLanguage language, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: searchVisible
            ? _buildSearchField(isDark, isLiquidGlass, language)
            : _buildAppBarTitle(language, isDark),
      ),
      actions: [
        if (!searchVisible) ...[
          // Search icon (also activated by dock swipe-down)
          IconButton(
            tooltip: 'Search Documents',
            icon: Icon(Icons.search_rounded,
                size: 22,
                color: isDark ? Colors.white70 : Colors.black87),
            onPressed: () {
              ref.read(searchVisibleProvider.notifier).state = true;
            },
          ),
          // Stats toggle
          IconButton(
            tooltip: _isStatsExpanded ? 'Hide Stats' : 'Show Stats',
            icon: Icon(
              _isStatsExpanded
                  ? Icons.bar_chart
                  : Icons.bar_chart_outlined,
              size: 22,
              color: _isStatsExpanded
                  ? (isDark
                      ? LiquidGlassTheme.accentElectricBlue
                      : const Color(0xFF2563EB))
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            onPressed: () =>
                setState(() => _isStatsExpanded = !_isStatsExpanded),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildAppBarTitle(AppLanguage language, bool isDark) {
    return Padding(
      key: const ValueKey('app_title'),
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark
                  ? LiquidGlassTheme.accentElectricBlue.withValues(alpha: 0.18)
                  : const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? LiquidGlassTheme.accentElectricBlue.withValues(alpha: 0.35)
                    : const Color(0xFF2563EB).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: isDark
                  ? LiquidGlassTheme.accentElectricBlue
                  : const Color(0xFF2563EB),
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
    );
  }

  Widget _buildSearchField(
      bool isDark, bool isLiquidGlass, AppLanguage language) {
    return Padding(
      key: const ValueKey('search_field'),
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? LiquidGlassTheme.accentElectricBlue.withValues(alpha: 0.4)
                : const Color(0xFF93C5FD),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark
                      ? LiquidGlassTheme.accentElectricBlue
                      : const Color(0xFF2563EB))
                  .withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search_rounded,
              size: 18,
              color: isDark
                  ? LiquidGlassTheme.accentElectricBlue
                  : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.get('search_hint', language),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.close_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45),
              onPressed: () {
                _searchFocusNode.unfocus();
                _searchController.clear();
                setState(() => _searchQuery = '');
                ref.read(searchVisibleProvider.notifier).state = false;
              },
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filtering ────────────────────────────────────────────────────────

  List<VehicleDocument> _applyFilters(List<VehicleDocument> docs) {
    return docs.where((doc) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = doc.vehicleRegNo.toLowerCase().contains(q) ||
            doc.title.toLowerCase().contains(q) ||
            (doc.policyNo?.toLowerCase().contains(q) ?? false) ||
            doc.documentType.label.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_statusFilter == 'valid') return !doc.isExpired;
      if (_statusFilter == 'expiring') {
        if (doc.expiryDate == null || doc.isExpired) return false;
        return doc.expiryDate!.difference(DateTime.now()).inDays <= 30;
      }
      if (_statusFilter == 'expired') return doc.isExpired;
      return true;
    }).toList();
  }

  // ── Smart Folder Grid ─────────────────────────────────────────────────

  /// Builds the smart folder categorization.
  /// - One folder per unique vehicle reg plate (vehicle-specific docs)
  /// - Driving licenses appear in EVERY vehicle folder AND in Personal → Identification
  /// - Personal folder: sub-categories (Identification, Educational, Tax/Financial)
  /// - Travel, General catch-all folders
  Widget _buildFolderGrid(
    BuildContext context,
    List<VehicleDocument> filteredDocs,
    List<VehicleDocument> allRealDocs,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    // Collect all driving license docs (for cross-linking)
    final drivingLicenses = allRealDocs
        .where((d) => d.documentType == DocumentType.drivingLicense)
        .toList();

    // Group vehicle-specific docs by registration plate
    final Map<String, List<VehicleDocument>> vehicleGroups = {};
    for (final doc in filteredDocs) {
      final isVehicleSpecific = _isVehicleSpecificDoc(doc);
      if (isVehicleSpecific) {
        final key = doc.vehicleRegNo.isNotEmpty && doc.vehicleRegNo != 'General'
            ? doc.vehicleRegNo.toUpperCase()
            : 'Vehicle';
        vehicleGroups.putIfAbsent(key, () => []).add(doc);
      }
    }

    // Personal sub-categories
    final List<VehicleDocument> identificationDocs = filteredDocs
        .where((d) =>
            d.documentType == DocumentType.idCard ||
            d.documentType == DocumentType.drivingLicense)
        .toList();

    final List<VehicleDocument> educationalDocs = filteredDocs
        .where((d) =>
            d.documentType == DocumentType.certificate &&
            !_isFinancialCert(d))
        .toList();

    final List<VehicleDocument> taxDocs = filteredDocs
        .where((d) =>
            d.documentType == DocumentType.bill ||
            _isFinancialCert(d))
        .toList();

    final List<VehicleDocument> travelDocs = filteredDocs
        .where((d) => d.documentType == DocumentType.eTicket)
        .toList();

    final List<VehicleDocument> generalDocs = filteredDocs
        .where((d) =>
            d.documentType == DocumentType.custom &&
            !_isVehicleSpecificDoc(d))
        .toList();

    final hasPersonal = identificationDocs.isNotEmpty ||
        educationalDocs.isNotEmpty ||
        taxDocs.isNotEmpty;

    final List<Widget> folders = [];

    // ── Section label: Vehicles ──────────────────────────────────────
    if (vehicleGroups.isNotEmpty) {
      folders.add(_sectionLabel('Vehicles', Icons.directions_car_rounded,
          const Color(0xFF2563EB), isDark));
    }

    vehicleGroups.forEach((regNo, vDocs) {
      // Cross-link: add driving licenses not already in this folder
      final combined = [...vDocs];
      for (final dl in drivingLicenses) {
        if (!combined.any((d) => d.id == dl.id)) combined.add(dl);
      }

      folders.add(_buildFolderTile(
        context: context,
        folder: SmartFolder(
          id: 'vehicle_$regNo',
          title: regNo,
          subtitle: 'Fuel, Insurance, License',
          icon: Icons.directions_car_rounded,
          accentColor: const Color(0xFF2563EB),
          documents: combined,
        ),
        isDark: isDark,
        isLiquidGlass: isLiquidGlass,
      ));
    });

    // ── Section label: Personal ──────────────────────────────────────
    if (hasPersonal) {
      folders.add(_sectionLabel('Personal', Icons.person_outline_rounded,
          const Color(0xFF8B5CF6), isDark));

      final subCats = <String, List<VehicleDocument>>{};
      if (identificationDocs.isNotEmpty) {
        subCats['Identification'] = identificationDocs;
      }
      if (educationalDocs.isNotEmpty) {
        subCats['Educational'] = educationalDocs;
      }
      if (taxDocs.isNotEmpty) {
        subCats['Tax & Financial'] = taxDocs;
      }

      final allPersonal = [
        ...identificationDocs,
        ...educationalDocs,
        ...taxDocs,
      ];

      folders.add(_buildFolderTile(
        context: context,
        folder: SmartFolder(
          id: 'personal_docs',
          title: 'Personal Documents',
          subtitle:
              '${identificationDocs.length} ID · ${educationalDocs.length} Edu · ${taxDocs.length} Tax',
          icon: Icons.badge_rounded,
          accentColor: const Color(0xFF8B5CF6),
          documents: allPersonal,
          subCategories: subCats,
        ),
        isDark: isDark,
        isLiquidGlass: isLiquidGlass,
      ));
    }

    // ── Section label: Other ─────────────────────────────────────────
    if (travelDocs.isNotEmpty || generalDocs.isNotEmpty) {
      folders.add(_sectionLabel('Other', Icons.folder_outlined,
          const Color(0xFF64748B), isDark));
    }

    if (travelDocs.isNotEmpty) {
      folders.add(_buildFolderTile(
        context: context,
        folder: SmartFolder(
          id: 'travel_tickets',
          title: 'Travel & E-Tickets',
          subtitle: 'Flights, Trains, Events',
          icon: Icons.airplane_ticket_rounded,
          accentColor: const Color(0xFF0EA5E9),
          documents: travelDocs,
        ),
        isDark: isDark,
        isLiquidGlass: isLiquidGlass,
      ));
    }

    if (generalDocs.isNotEmpty) {
      folders.add(_buildFolderTile(
        context: context,
        folder: SmartFolder(
          id: 'general_docs',
          title: 'General Documents',
          subtitle: 'Other secured files',
          icon: Icons.folder_shared_rounded,
          accentColor: const Color(0xFF64748B),
          documents: generalDocs,
        ),
        isDark: isDark,
        isLiquidGlass: isLiquidGlass,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: folders,
    );
  }

  bool _isVehicleSpecificDoc(VehicleDocument doc) {
    if (doc.documentType == DocumentType.fuelQr ||
        doc.documentType == DocumentType.insuranceCard ||
        doc.documentType == DocumentType.revenueLicense) {
      return true;
    }
    final reg = doc.vehicleRegNo.toLowerCase();
    return reg.isNotEmpty &&
        reg != 'general' &&
        reg != 'other' &&
        reg != 'personal' &&
        doc.documentType != DocumentType.idCard &&
        doc.documentType != DocumentType.drivingLicense &&
        doc.documentType != DocumentType.eTicket &&
        doc.documentType != DocumentType.bill &&
        doc.documentType != DocumentType.certificate;
  }

  bool _isFinancialCert(VehicleDocument doc) {
    final title = doc.title.toLowerCase();
    return title.contains('tin') ||
        title.contains('tax') ||
        title.contains('invoice') ||
        title.contains('bill') ||
        title.contains('receipt') ||
        title.contains('financial');
  }

  Widget _sectionLabel(
      String text, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.22)),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile({
    required BuildContext context,
    required SmartFolder folder,
    required bool isDark,
    required bool isLiquidGlass,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) =>
                FolderContentsScreen(folder: folder),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 320),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? folder.accentColor.withValues(alpha: 0.10)
                : folder.accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: folder.accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: folder.accentColor.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Folder icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      folder.accentColor.withValues(alpha: isDark ? 0.5 : 0.35),
                      folder.accentColor.withValues(alpha: isDark ? 0.28 : 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: folder.accentColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(folder.icon, color: folder.accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      folder.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: folder.accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${folder.documents.length}',
                      style: TextStyle(
                        color: folder.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                      size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Flat Document List (non-categorized) ─────────────────────────────

  Widget _buildFlatList(BuildContext context, List<VehicleDocument> docs,
      bool isLiquidGlass, bool isDark) {
    return Column(
      children: docs
          .map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDocumentCard(context, doc, isLiquidGlass, isDark),
              ))
          .toList(),
    );
  }

  Widget _buildDocumentCard(BuildContext context, VehicleDocument doc,
      bool isLiquidGlass, bool isDark) {
    final isPopped = _popupDocId == doc.id;
    final isExpired = doc.isExpired;

    Widget card = GestureDetector(
      onTap: () {
        if (_popupDocId != null) {
          _exitPopup();
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => DocumentViewerScreen(document: doc)),
          );
        }
      },
      onLongPress: () => _enterPopup(doc.id),
      child: AnimatedBuilder(
        animation: _popupAnim,
        builder: (ctx, child) {
          final scale =
              isPopped ? (1.0 + 0.045 * _popupAnim.value) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: isPopped
                    ? [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.28),
                          blurRadius: 22,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        )
                      ]
                    : [],
              ),
              child: _buildCardContent(doc, isExpired, isDark),
            ),
            if (isPopped) ...[
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _popupAnim,
                  builder: (_, __) => Opacity(
                    opacity: _popupAnim.value,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626)
                            .withValues(alpha: 0.88),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swipe_left_rounded,
                              color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Swipe left to delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -9,
                right: -9,
                child: AnimatedBuilder(
                  animation: _popupAnim,
                  builder: (_, child) => Transform.scale(
                      scale: _popupAnim.value, child: child),
                  child: GestureDetector(
                    onTap: () async {
                      final ok = await DocumentActionHelper
                          .confirmAndDeleteDocument(
                        context: context,
                        ref: ref,
                        document: doc,
                      );
                      if (ok && mounted) _exitPopup();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isPopped) {
      card = Dismissible(
        key: ValueKey('hs_dismiss_${doc.id}'),
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
              SizedBox(width: 6),
              Text('Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
        confirmDismiss: (_) =>
            DocumentActionHelper.confirmAndDeleteDocument(
              context: context, ref: ref, document: doc),
        onDismissed: (_) => setState(() => _popupDocId = null),
        child: card,
      );
    }

    return card;
  }

  Widget _buildCardContent(
      VehicleDocument doc, bool isExpired, bool isDark) {
    final hasRef = doc.vehicleRegNo.isNotEmpty &&
        doc.vehicleRegNo != 'General' &&
        doc.vehicleRegNo.toLowerCase() != 'other';
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? LiquidGlassTheme.accentElectricBlue
                        .withValues(alpha: 0.2)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? LiquidGlassTheme.accentElectricBlue
                          .withValues(alpha: 0.35)
                      : const Color(0xFF93C5FD),
                  width: 1,
                ),
              ),
              child: Icon(doc.documentType.icon,
                  color: isDark
                      ? LiquidGlassTheme.accentElectricBlue
                      : const Color(0xFF2563EB),
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          doc.title.isNotEmpty ? doc.title : doc.vehicleRegNo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(doc.syncStatus.icon,
                          color: doc.syncStatus.color, size: 16),
                    ],
                  ),
                  if (hasRef && doc.title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Ref: ${doc.vehicleRegNo}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(
                        doc.documentType.label,
                        isDark
                            ? Colors.white12
                            : const Color(0xFFF1F5F9),
                        isDark
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                      if (doc.expiryDate != null)
                        _badge(
                          isExpired
                              ? 'EXPIRED'
                              : 'Expires in ${_daysLeft(doc.expiryDate!)}d',
                          isExpired
                              ? const Color(0xFFEF4444)
                                  .withValues(alpha: 0.18)
                              : const Color(0xFF10B981)
                                  .withValues(alpha: 0.18),
                          isExpired
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: isDark
                    ? Colors.white38
                    : const Color(0xFF94A3B8),
                size: 20),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  int _daysLeft(DateTime expiry) =>
      expiry.difference(DateTime.now()).inDays;

  // ── Sync Status Bar ──────────────────────────────────────────────────

  Widget _buildSyncStatusBar(
      SyncEngineState? state, bool isLiquidGlass, AppLanguage language) {
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

  // ── Stats Row ────────────────────────────────────────────────────────

  Widget _buildStatsRow(List<VehicleDocument> docs, bool isLiquidGlass,
      AppLanguage language, bool isDark) {
    final total = docs.length;
    final expired = docs.where((d) => d.isExpired).length;
    final valid = total - expired;
    final expiring = docs.where((d) {
      if (d.expiryDate == null || d.isExpired) return false;
      return d.expiryDate!.difference(DateTime.now()).inDays <= 30;
    }).length;

    return Row(
      children: [
        _statCard('Total', '$total', Icons.layers_rounded,
            isDark ? LiquidGlassTheme.accentElectricBlue : const Color(0xFF2563EB),
            null, isLiquidGlass, isDark),
        const SizedBox(width: 8),
        _statCard('Valid', '$valid', Icons.verified_rounded,
            const Color(0xFF10B981), 'valid', isLiquidGlass, isDark),
        const SizedBox(width: 8),
        _statCard('Expiring', '$expiring', Icons.access_time_rounded,
            const Color(0xFFF59E0B), 'expiring', isLiquidGlass, isDark),
        const SizedBox(width: 8),
        _statCard('Expired', '$expired', Icons.cancel_rounded,
            const Color(0xFFEF4444), 'expired', isLiquidGlass, isDark),
      ],
    );
  }

  Widget _statCard(String label, String count, IconData icon, Color color,
      String? filterKey, bool isLiquidGlass, bool isDark) {
    final isSelected = _statusFilter == filterKey;
    final borderColor = isSelected
        ? color
        : (isDark
            ? Colors.white.withValues(alpha: 0.16)
            : const Color(0xFFCBD5E1));
    final bgColor = isSelected
        ? color.withValues(alpha: isDark ? 0.22 : 0.14)
        : (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.88));

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _statusFilter = (_statusFilter == filterKey) ? null : filterKey;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: borderColor, width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? color
                      : (isDark
                          ? Colors.white70
                          : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter Badge ─────────────────────────────────────────────────────

  Widget _buildActiveFilterBadge(bool isDark) {
    Color color = Colors.blue;
    String label = '';
    if (_statusFilter == 'valid') {
      label = 'Showing Valid Only';
      color = const Color(0xFF10B981);
    } else if (_statusFilter == 'expiring') {
      label = 'Showing Expiring Soon (<30d)';
      color = const Color(0xFFF59E0B);
    } else if (_statusFilter == 'expired') {
      label = 'Showing Expired Only';
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _statusFilter = null),
            child: Icon(Icons.close_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────

  Widget _buildEmptyState(
      bool isLiquidGlass, AppLanguage language, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
        child: LiquidGlassCard(
          isLiquidGlass: isLiquidGlass,
          padding: const EdgeInsets.all(24),
          radius: 28,
          child: Column(
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 52,
                  color: isDark ? Colors.white38 : Colors.black38),
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
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: widget.onNavigateToScan,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text(
                    AppStrings.get('btn_quick_scan', language),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LiquidGlassTheme.accentAmber,
                    side: const BorderSide(
                        color: LiquidGlassTheme.accentAmber),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _handleManualImport(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text(
                    'Import File (.pdf, .png, .jpg)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── File Import ──────────────────────────────────────────────────────

  Future<void> _handleManualImport(BuildContext context) async {
    if (_isImporting) return;
    try {
      setState(() => _isImporting = true);

      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (pickedFiles.isEmpty) return;

      final pickedFile = pickedFiles.first;
      final filePath = pickedFile.path;
      if (filePath == null) {
        if (context.mounted) {
          _snackError(context, 'Unable to locate file on storage.');
        }
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          _snackError(context, 'Selected file does not exist on disk.');
        }
        return;
      }

      final ext = (pickedFile.extension ?? p.extension(filePath))
          .replaceAll('.', '')
          .toLowerCase();

      if (!_allowedExtensions.contains(ext)) {
        if (context.mounted) {
          _snackError(context,
              'Unsupported format: .$ext. Only .pdf, .png, .jpg files are allowed.');
        }
        return;
      }

      final fileSize =
          pickedFile.lengthSync() ?? (await file.length());
      if (fileSize > _maxFileSizeBytes) {
        final mb = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        if (context.mounted) {
          _snackError(context,
              'File size ($mb MB) exceeds the strict 5 MB limit.');
        }
        return;
      }

      if (context.mounted) {
        await ImportDocumentMetadataSheet.show(
          context: context,
          sourceFile: file,
          originalName: pickedFile.name,
          extension: ext,
          fileSize: fileSize,
          onSaveSuccess: () {
            if (context.mounted) {
              _snackSuccess(
                  context, 'Successfully secured "${pickedFile.name}" into vault!');
            }
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        _snackError(context, 'Document import failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _snackError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 4),
      ));
  }

  void _snackSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.greenAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 3),
      ));
  }
}
