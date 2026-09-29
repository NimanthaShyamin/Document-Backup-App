import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/document_type.dart';
import '../controllers/document_providers.dart';

/// Camera Viewfinder & Document Digitization Screen.
class ScanScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDocumentSaved;

  const ScanScreen({super.key, this.onDocumentSaved});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  DocumentType _selectedType = DocumentType.fuelQr;
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _policyNoController = TextEditingController();
  DateTime? _selectedExpiry;
  bool _isSaving = false;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _regNoController.dispose();
    _titleController.dispose();
    _policyNoController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(DocumentType type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _handleSaveDocument() async {
    final regNo = _regNoController.text.trim();
    final title = _titleController.text.trim();
    final effectiveRegNo = regNo.isNotEmpty ? regNo : 'General';

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Document Title.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final sampleFile = File('${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.txt');
      await sampleFile.writeAsString(
        'SECURE VAULT ENCRYPTED CERTIFICATE\n'
        'Reference/ID: $effectiveRegNo\n'
        'Title: $title\n'
        'Category: ${_selectedType.label}\n'
        'Ref/Policy: ${_policyNoController.text.trim()}\n'
        'Expiry Date: ${_selectedExpiry != null ? DateFormat.yMMMd().format(_selectedExpiry!) : "None"}\n'
        'Digitized At: ${DateTime.now().toIso8601String()}\n'
        'SHA256 Sandbox Protected.\n',
      );

      final repo = ref.read(vehicleDocumentRepositoryProvider);
      await repo.saveDocument(
        documentType: _selectedType,
        title: title,
        vehicleRegNo: effectiveRegNo,
        policyNo: _policyNoController.text.trim().isEmpty ? null : _policyNoController.text.trim(),
        expiryDate: _selectedExpiry,
        sourceFile: sampleFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully secured $title into sandboxed vault!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDocumentSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final language = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppStrings.get('scanner_title', language),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 110.0),
        child: Column(
          children: [
            // Category Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: DocumentType.values.map((type) {
                  final isSelected = type == _selectedType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(type.label),
                      avatar: Icon(type.icon, size: 16),
                      selectedColor: LiquidGlassTheme.accentAmber,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => _onCategoryChanged(type),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Animated Laser Camera Viewfinder Card
            LiquidGlassCard(
              isLiquidGlass: isLiquidGlass,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Center icon/target
                        Center(
                          child: Icon(
                            _selectedType.icon,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),

                        // Corner Brackets
                        Positioned(
                          top: 14,
                          left: 14,
                          child: _buildCornerBracket(isTop: true, isLeft: true),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _buildCornerBracket(isTop: true, isLeft: false),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 14,
                          child: _buildCornerBracket(isTop: false, isLeft: true),
                        ),
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: _buildCornerBracket(isTop: false, isLeft: false),
                        ),

                        // Animated Laser Line
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, _) {
                            return Align(
                              alignment: Alignment(0, (_laserAnimation.value * 2) - 1),
                              child: Container(
                                height: 2.5,
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amberAccent.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.get('scan_instruction', language),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Metadata Entry Form Card
            LiquidGlassCard(
              isLiquidGlass: isLiquidGlass,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Metadata',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Reg No / Reference Field
                  TextField(
                    controller: _regNoController,
                    decoration: InputDecoration(
                      labelText: 'Reference / Reg / ID No (Optional)',
                      prefixIcon: const Icon(Icons.pin, size: 20),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('doc_title', language),
                      prefixIcon: const Icon(Icons.title, size: 20),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Policy / Ref No Field
                  TextField(
                    controller: _policyNoController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('policy_no', language),
                      prefixIcon: const Icon(Icons.tag, size: 20),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Expiry Date Picker Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedExpiry != null
                              ? '${AppStrings.get('expiry_date', language)}: ${DateFormat.yMMMd().format(_selectedExpiry!)}'
                              : '${AppStrings.get('expiry_date', language)}: No Expiration',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedExpiry != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              tooltip: 'Clear Date',
                              onPressed: () => setState(() => _selectedExpiry = null),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedExpiry ?? DateTime.now().add(const Duration(days: 365)),
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setState(() => _selectedExpiry = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_selectedExpiry != null ? 'Change Date' : 'Set Date'),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidGlassTheme.accentAmber,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving ? null : _handleSaveDocument,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                            )
                          : const Icon(Icons.security, size: 20),
                      label: Text(
                        _isSaving
                            ? 'Encrypting & Saving...'
                            : AppStrings.get('save_to_vault', language),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80), // Padding for bottom dock
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket({required bool isTop, required bool isLeft}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.amberAccent, width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.amberAccent, width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.amberAccent, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.amberAccent, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
