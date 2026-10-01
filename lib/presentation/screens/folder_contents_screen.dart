import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';

import '../../domain/entities/vehicle_document.dart';

import '../controllers/document_providers.dart';
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
  final List<SmartFolder>? subFolders;

  const SmartFolder({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.documents,
    this.subCategories,
    this.subFolders,
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

class _FolderContentsScreenState extends ConsumerState<FolderContentsScreen> {
  double _dragOffsetY = 0.0;
  bool _isDragging = false;

  void _showDocumentActionSheet(BuildContext context, VehicleDocument doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(doc.documentType.icon, color: const Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (doc.vehicleRegNo.isNotEmpty && doc.vehicleRegNo != 'General')
                              Text(
                                'Ref: ${doc.vehicleRegNo}',
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
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined, color: Color(0xFF2563EB)),
                  title: const Text('View Document', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(document: doc),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  title: const Text('Delete Document',
                      style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await DocumentActionHelper.confirmAndDeleteDocument(
                      context: context,
                      ref: ref,
                      document: doc,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final docsAsync = ref.watch(vehicleDocumentsStreamProvider);
    final allLiveDocs = docsAsync.value ?? [];
    final liveDocIds = allLiveDocs.map((d) => d.id).toSet();

    // Dynamically filter active documents so deleted items immediately vanish from folder view
    final liveFolderDocs = widget.folder.documents
        .where((d) => liveDocIds.contains(d.id))
        .map((d) => allLiveDocs.firstWhere((live) => live.id == d.id, orElse: () => d))
        .toList();

    // Dynamically filter subFolders
    final liveSubFolders = widget.folder.subFolders?.map((sub) {
      final subDocs = sub.documents
          .where((d) => liveDocIds.contains(d.id))
          .map((d) => allLiveDocs.firstWhere((live) => live.id == d.id, orElse: () => d))
          .toList();
      return SmartFolder(
        id: sub.id,
        title: sub.title,
        subtitle: sub.subtitle,
        icon: sub.icon,
        accentColor: sub.accentColor,
        documents: subDocs,
        subCategories: sub.subCategories,
        subFolders: sub.subFolders,
      );
    }).where((sub) => sub.documents.isNotEmpty).toList();

    // Dynamically filter subCategories
    final Map<String, List<VehicleDocument>>? liveSubCategories;
    if (widget.folder.subCategories != null) {
      final map = <String, List<VehicleDocument>>{};
      widget.folder.subCategories!.forEach((k, list) {
        final filtered = list
            .where((d) => liveDocIds.contains(d.id))
            .map((d) => allLiveDocs.firstWhere((live) => live.id == d.id, orElse: () => d))
            .toList();
        if (filtered.isNotEmpty) map[k] = filtered;
      });
      liveSubCategories = map;
    } else {
      liveSubCategories = null;
    }

    final totalCount = liveSubFolders != null && liveSubFolders.isNotEmpty
        ? liveSubFolders.length
        : liveFolderDocs.length;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        final delta = details.primaryDelta ?? 0;
        if (delta > 0 || _dragOffsetY > 0) {
          setState(() {
            _isDragging = true;
            _dragOffsetY = (_dragOffsetY + delta).clamp(0.0, 400.0);
          });
        }
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragOffsetY > 80 || velocity > 400) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _isDragging = false;
            _dragOffsetY = 0.0;
          });
        }
      },
      onVerticalDragCancel: () {
        setState(() {
          _isDragging = false;
          _dragOffsetY = 0.0;
        });
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is OverscrollNotification) {
            if (notification.overscroll < 0) {
              setState(() {
                _isDragging = true;
                _dragOffsetY = (_dragOffsetY - notification.overscroll).clamp(0.0, 400.0);
              });
            }
          } else if (notification is ScrollUpdateNotification) {
            if (_dragOffsetY > 0 && notification.scrollDelta != null) {
              setState(() {
                _isDragging = true;
                _dragOffsetY = (_dragOffsetY - notification.scrollDelta!).clamp(0.0, 400.0);
              });
            }
          } else if (notification is ScrollEndNotification) {
            if (_dragOffsetY > 0) {
              if (_dragOffsetY > 80) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _isDragging = false;
                  _dragOffsetY = 0.0;
                });
              }
            }
          }
          return false;
        },
        child: AnimatedContainer(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, _dragOffsetY, 0.0),
          child: Opacity(
            opacity: (1.0 - (_dragOffsetY / 300.0)).clamp(0.0, 1.0),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: LiquidGlassBackground(
                isLiquidGlass: isLiquidGlass,
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(isDark, totalCount, liveSubFolders != null && liveSubFolders.isNotEmpty),
                      Expanded(
                        child: liveSubFolders != null && liveSubFolders.isNotEmpty
                            ? _buildSubFolders(liveSubFolders, isLiquidGlass, isDark)
                            : (liveSubCategories != null
                                ? _buildSubCategorizedWithDocs(liveSubCategories, isLiquidGlass, isDark)
                                : _buildFlat(liveFolderDocs, isLiquidGlass, isDark)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, int count, bool isSubFolder) {
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
                  isSubFolder
                      ? '$count vehicle folder${count == 1 ? '' : 's'}'
                      : '$count document${count == 1 ? '' : 's'}',
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

  Widget _buildSubFolders(
      List<SmartFolder> subFolders, bool isLiquidGlass, bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        children: subFolders
            .map((sub) => _buildFolderTile(
                  context: context,
                  folder: sub,
                  isDark: isDark,
                  isLiquidGlass: isLiquidGlass,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFolderTile({
    required BuildContext context,
    required SmartFolder folder,
    required bool isDark,
    required bool isLiquidGlass,
  }) {
    final body = Row(
      children: [
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
              color: folder.accentColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Icon(folder.icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                folder.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                folder.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: folder.accentColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${folder.documents.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: folder.accentColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: isDark ? Colors.white30 : Colors.black26),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isLiquidGlass
          ? LiquidGlassCard(
              isLiquidGlass: true,
              radius: 18,
              padding: const EdgeInsets.all(16),
              color: isDark
                  ? folder.accentColor.withValues(alpha: 0.12)
                  : folder.accentColor.withValues(alpha: 0.08),
              border: Border.all(
                color: folder.accentColor.withValues(alpha: isDark ? 0.40 : 0.30),
                width: 1.2,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FolderContentsScreen(folder: folder),
                ),
              ),
              child: body,
            )
          : GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FolderContentsScreen(folder: folder),
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
                child: body,
              ),
            ),
    );
  }

  Widget _buildSubCategorizedWithDocs(
      Map<String, List<VehicleDocument>> subCats, bool isLiquidGlass, bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
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
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isLiquidGlass
          ? LiquidGlassCard(
              isLiquidGlass: true,
              radius: 16,
              padding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(document: doc),
                ));
              },
              child: _cardContent(doc, isDark, true),
            )
          : GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DocumentViewerScreen(document: doc),
                ));
              },
              onLongPress: () => _showDocumentActionSheet(context, doc),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: _cardContent(doc, isDark, false),
              ),
            ),
    );
  }

  Widget _cardContent(VehicleDocument doc, bool isDark, [bool isLiquidGlass = false]) {
    final isExpired = doc.isExpired;
    return Container(
      decoration: isLiquidGlass
          ? null
          : BoxDecoration(
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
