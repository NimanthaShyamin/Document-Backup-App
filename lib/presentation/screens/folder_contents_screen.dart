import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';

import '../../domain/entities/vehicle_document.dart';

import '../utils/document_action_helper.dart';
import 'document_viewer_screen.dart';

/// Data model for a smart folder shown on the home screen.
class SmartFolder {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<VehicleDocument> documents;
  final Map<String, List<VehicleDocument>>? subCategories;

  const SmartFolder({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.documents,
    this.subCategories,
  });
}

/// Full-screen folder contents view — shows all documents within a smart folder.
/// Vehicle folders also show the user's driving licenses cross-linked.
/// Personal folder uses sub-category headers (Identification, Educational, Tax/Financial).
class FolderContentsScreen extends ConsumerStatefulWidget {
  final SmartFolder folder;

  const FolderContentsScreen({super.key, required this.folder});

  @override
  ConsumerState<FolderContentsScreen> createState() =>
      _FolderContentsScreenState();
}

class _FolderContentsScreenState extends ConsumerState<FolderContentsScreen>
    with SingleTickerProviderStateMixin {
  String? _popupDocId;
  late AnimationController _popupAnimController;
  late Animation<double> _popupAnim;

  @override
  void initState() {
    super.initState();
    _popupAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _popupAnim = CurvedAnimation(
      parent: _popupAnimController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _popupAnimController.dispose();
    super.dispose();
  }

  void _enterPopupMode(String docId) {
    setState(() => _popupDocId = docId);
    _popupAnimController.forward(from: 0);
  }

  void _exitPopupMode() {
    _popupAnimController.reverse().then((_) {
      if (mounted) setState(() => _popupDocId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_popupDocId != null) _exitPopupMode();
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LiquidGlassBackground(
          isLiquidGlass: isLiquidGlass,
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(
                  child: widget.folder.subCategories != null
                      ? _buildSubCategorized(isLiquidGlass, isDark)
                      : _buildFlat(widget.folder.documents, isLiquidGlass, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: widget.folder.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(widget.folder.icon,
                color: widget.folder.accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.folder.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${widget.folder.documents.length} document${widget.folder.documents.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategorized(bool isLiquidGlass, bool isDark) {
    final subCats = widget.folder.subCategories!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: subCats.entries.map((entry) {
          if (entry.value.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: widget.folder.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.folder.accentColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: widget.folder.accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
              ...entry.value.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDocumentCard(doc, isLiquidGlass, isDark),
                  )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFlat(
      List<VehicleDocument> docs, bool isLiquidGlass, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        children: docs
            .map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildDocumentCard(doc, isLiquidGlass, isDark),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDocumentCard(
      VehicleDocument doc, bool isLiquidGlass, bool isDark) {
    final isPopped = _popupDocId == doc.id;

    final cardBody = _cardContent(doc, isDark);

    Widget card = GestureDetector(
      onTap: () {
        if (_popupDocId != null) {
          _exitPopupMode();
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(document: doc),
          ));
        }
      },
      onLongPress: () => _enterPopupMode(doc.id),
      child: AnimatedBuilder(
        animation: _popupAnim,
        builder: (context, child) {
          final scale = isPopped ? (1.0 + 0.045 * _popupAnim.value) : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
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
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 22,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        )
                      ]
                    : [],
              ),
              child: cardBody,
            ),
            if (isPopped) ...[
              // Swipe-to-delete hint strip at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _popupAnim,
                  builder: (_, __) => Opacity(
                    opacity: _popupAnim.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.88),
                        borderRadius:
                            const BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swipe_left_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Swipe left to delete',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // iOS-style × badge top-right
              Positioned(
                top: -9,
                right: -9,
                child: AnimatedBuilder(
                  animation: _popupAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _popupAnim.value,
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      final ok =
                          await DocumentActionHelper.confirmAndDeleteDocument(
                        context: context,
                        ref: ref,
                        document: doc,
                      );
                      if (ok && mounted) _exitPopupMode();
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
                              offset: Offset(0, 2))
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
        key: ValueKey('fd_dismiss_${doc.id}'),
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
                      fontSize: 14)),
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

  Widget _cardContent(VehicleDocument doc, bool isDark) {
    final isExpired = doc.isExpired;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.13)
              : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? LiquidGlassTheme.accentElectricBlue.withValues(alpha: 0.18)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? LiquidGlassTheme.accentElectricBlue.withValues(alpha: 0.28)
                      : const Color(0xFF93C5FD),
                  width: 1,
                ),
              ),
              child: Icon(
                doc.documentType.icon,
                color: isDark
                    ? LiquidGlassTheme.accentElectricBlue
                    : const Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (doc.vehicleRegNo.isNotEmpty &&
                      doc.vehicleRegNo != 'General') ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${doc.vehicleRegNo}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _badge(
                        doc.documentType.label,
                        isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                      if (doc.expiryDate != null)
                        _badge(
                          isExpired
                              ? 'EXPIRED'
                              : 'Exp ${doc.expiryDate!.difference(DateTime.now()).inDays}d',
                          isExpired
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          isExpired
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                size: 18),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
