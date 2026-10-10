import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/vehicle_document.dart';
import '../controllers/document_providers.dart';

/// Screen allowing users to inspect, individually or batch restore,
/// and permanently delete documents in the Recycle Bin, as well as customize
/// the automatic purge retention cycle.
class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  final Set<String> _selectedDocumentIds = <String>{};
  bool _isProcessing = false;

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedDocumentIds.contains(id)) {
        _selectedDocumentIds.remove(id);
      } else {
        _selectedDocumentIds.add(id);
      }
    });
  }

  void _selectAll(List<VehicleDocument> docs) {
    setState(() {
      if (_selectedDocumentIds.length == docs.length) {
        _selectedDocumentIds.clear();
      } else {
        _selectedDocumentIds.addAll(docs.map((d) => d.id));
      }
    });
  }

  Future<void> _restoreSingle(VehicleDocument doc) async {
    final repo = ref.read(vehicleDocumentRepositoryProvider);
    try {
      await repo.restoreFromRecycleBin(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.restore, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Restored "${doc.title}" to vault.')),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteSingle(VehicleDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Permanently Delete?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${doc.title}" (${doc.vehicleRegNo})?\n\nThis will erase the file from device storage and Google Drive AppData forever. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(vehicleDocumentRepositoryProvider);
    try {
      await repo.permanentlyDeleteDocument(doc.id);
      setState(() => _selectedDocumentIds.remove(doc.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Permanently deleted "${doc.title}".')),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _restoreSelected(List<VehicleDocument> allDocs) async {
    final targets = allDocs.where((d) => _selectedDocumentIds.contains(d.id)).toList();
    if (targets.isEmpty) return;

    setState(() => _isProcessing = true);
    final repo = ref.read(vehicleDocumentRepositoryProvider);
    int successCount = 0;
    try {
      for (final doc in targets) {
        await repo.restoreFromRecycleBin(doc.id);
        successCount++;
      }
      setState(() => _selectedDocumentIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $successCount document(s) to vault.'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch restore failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _permanentlyDeleteSelected(List<VehicleDocument> allDocs) async {
    final targets = allDocs.where((d) => _selectedDocumentIds.contains(d.id)).toList();
    if (targets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Selected Items?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${targets.length} document(s)?\n\nThey will be removed from local storage and Google Drive AppData forever.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete (${targets.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final repo = ref.read(vehicleDocumentRepositoryProvider);
    int deletedCount = 0;
    try {
      for (final doc in targets) {
        await repo.permanentlyDeleteDocument(doc.id);
        deletedCount++;
      }
      setState(() => _selectedDocumentIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted $deletedCount document(s).'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch delete error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _emptyRecycleBin(int totalCount) async {
    if (totalCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Empty Recycle Bin?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all $totalCount item(s) in the Recycle Bin?\n\nThis will purge all deleted documents from offline storage and Google Drive AppData.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Empty Bin', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final repo = ref.read(vehicleDocumentRepositoryProvider);
    try {
      await repo.emptyRecycleBin();
      setState(() => _selectedDocumentIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recycle Bin emptied successfully.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error emptying bin: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRetentionPeriodDialog(int currentDays) {
    int selectedDays = currentDays;
    final customController = TextEditingController();
    bool isCustom = ![7, 14, 30, 60, 90].contains(currentDays);
    if (isCustom) {
      customController.text = currentDays.toString();
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_outlined, color: Color(0xFF38BDF8), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Auto-Delete Period',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose how long items stay in the Recycle Bin before being permanently purged:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ...[7, 14, 30, 60, 90].map((days) {
                    final isChecked = !isCustom && selectedDays == days;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setDialogState(() {
                          isCustom = false;
                          selectedDays = days;
                          customController.clear();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isChecked ? const Color(0xFF38BDF8).withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked ? const Color(0xFF38BDF8) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isChecked ? const Color(0xFF38BDF8) : Colors.white38,
                                  width: 2,
                                ),
                              ),
                              child: isChecked
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$days Days${days == 30 ? ' (Default)' : ''}',
                              style: TextStyle(
                                color: isChecked ? Colors.white : Colors.white70,
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setDialogState(() {
                        isCustom = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isCustom ? const Color(0xFF38BDF8).withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCustom ? const Color(0xFF38BDF8) : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCustom ? const Color(0xFF38BDF8) : Colors.white38,
                                width: 2,
                              ),
                            ),
                            child: isCustom
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Custom Period (Days)',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isCustom)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, right: 12, top: 4),
                      child: TextField(
                        controller: customController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Enter number of days (e.g. 45)',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          suffixText: 'Days',
                          suffixStyle: const TextStyle(color: Color(0xFF38BDF8)),
                          filled: true,
                          fillColor: const Color(0x33000000),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  int finalDays = selectedDays;
                  if (isCustom) {
                    final parsed = int.tryParse(customController.text.trim());
                    if (parsed == null || parsed <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid number of days (> 0).'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }
                    finalDays = parsed;
                  }
                  ref.read(recycleBinRetentionDaysProvider.notifier).setDays(finalDays);
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Save Period', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retentionDays = ref.watch(recycleBinRetentionDaysProvider);
    final recycledAsync = ref.watch(recycleBinDocumentsStreamProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Recycle Bin',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          recycledAsync.when(
            data: (docs) {
              if (docs.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _selectedDocumentIds.length == docs.length ? const Color(0xFF38BDF8) : Colors.white70,
                    ),
                    icon: Icon(
                      _selectedDocumentIds.length == docs.length ? Icons.deselect : Icons.select_all,
                      size: 18,
                    ),
                    label: Text(
                      _selectedDocumentIds.length == docs.length ? 'Deselect All' : 'Select All',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _selectAll(docs),
                  ),
                  IconButton(
                    tooltip: 'Empty Bin',
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 22),
                    onPressed: () => _emptyRecycleBin(docs.length),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Retention Period Header Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildRetentionCard(context, retentionDays, isLiquidGlass, isDark),
              ),

              // 2. Documents List
              Expanded(
                child: recycledAsync.when(
                  data: (docs) {
                    if (docs.isEmpty) {
                      return _buildEmptyState(isDark);
                    }
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, _selectedDocumentIds.isNotEmpty ? 100 : 32),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final isSelected = _selectedDocumentIds.contains(doc.id);
                        return _buildDocumentCard(context, doc, isSelected, retentionDays, isLiquidGlass, isDark);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
                  error: (err, _) => Center(
                    child: Text('Failed to load recycle bin: $err', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ),
            ],
          ),

          // 3. Multi-Select Floating Action Dock
          if (_selectedDocumentIds.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildBatchActionDock(recycledAsync.value ?? [], isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildRetentionCard(BuildContext context, int retentionDays, bool isLiquidGlass, bool isDark) {
    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_delete_outlined, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Auto-Delete Cycle: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$retentionDays Days',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Items older than $retentionDays days will be purged automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change Period',
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF38BDF8), size: 20),
            onPressed: () => _showRetentionPeriodDialog(retentionDays),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                size: 64,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Recycle Bin is Empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleted documents are stored here safely before permanent removal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    VehicleDocument doc,
    bool isSelected,
    int retentionDays,
    bool isLiquidGlass,
    bool isDark,
  ) {
    final deletedDate = doc.deletedAt ?? doc.lastModifiedTimestamp;
    final purgeDate = deletedDate.add(Duration(days: retentionDays));
    final daysRemaining = purgeDate.difference(DateTime.now()).inDays;
    final remainingLabel = daysRemaining <= 0 ? 'Purges soon' : 'Purges in $daysRemaining d';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _toggleSelect(doc.id),
      child: LiquidGlassCard(
        isLiquidGlass: isLiquidGlass,
        padding: const EdgeInsets.all(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF38BDF8), width: 1.5)
            : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              activeColor: const Color(0xFF38BDF8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (_) => _toggleSelect(doc.id),
            ),

            // Document Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFF38BDF8), size: 22),
            ),
            const SizedBox(width: 12),

            // Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (doc.vehicleRegNo.isNotEmpty) ...[
                        Text(
                          doc.vehicleRegNo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          remainingLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Deleted ${DateFormat.MMMd().format(deletedDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // Individual Card Action Buttons: Restore & Delete Forever
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Restore Document',
                  icon: const Icon(Icons.restore, color: Colors.greenAccent, size: 20),
                  onPressed: () => _restoreSingle(doc),
                ),
                IconButton(
                  tooltip: 'Permanently Delete',
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                  onPressed: () => _permanentlyDeleteSingle(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionDock(List<VehicleDocument> allDocs, bool isDark) {
    final count = _selectedDocumentIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count Selected',
              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _isProcessing ? null : () => _restoreSelected(allDocs),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _isProcessing ? null : () => _permanentlyDeleteSelected(allDocs),
          ),
        ],
      ),
    );
  }
}
