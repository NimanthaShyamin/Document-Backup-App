import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../data/datasources/remote/gemini_document_extraction_service.dart';
import '../../domain/entities/document_type.dart';
import '../controllers/document_providers.dart';

/// Bottom sheet dialog for reviewing, editing, and confirming imported vehicle document metadata.
/// Supports dynamic Apple Liquid Glass styling (Screenshot 4) and eye-friendly blended theme when off.
/// Features in-sheet validation banners, empty category defaults, and guaranteed sheet dismissal upon save.
class ImportDocumentMetadataSheet extends ConsumerStatefulWidget {
  final File sourceFile;
  final String originalName;
  final String extension;
  final int fileSize;
  final VoidCallback? onSaveSuccess;

  const ImportDocumentMetadataSheet({
    super.key,
    required this.sourceFile,
    required this.originalName,
    required this.extension,
    required this.fileSize,
    this.onSaveSuccess,
  });

  /// Static helper to display the sheet modal.
  static Future<bool?> show({
    required BuildContext context,
    required File sourceFile,
    required String originalName,
    required String extension,
    required int fileSize,
    VoidCallback? onSaveSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportDocumentMetadataSheet(
        sourceFile: sourceFile,
        originalName: originalName,
        extension: extension,
        fileSize: fileSize,
        onSaveSuccess: onSaveSuccess,
      ),
    );
  }

  @override
  ConsumerState<ImportDocumentMetadataSheet> createState() =>
      _ImportDocumentMetadataSheetState();
}

class _ImportDocumentMetadataSheetState
    extends ConsumerState<ImportDocumentMetadataSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _regNoController;
  late final TextEditingController _policyController;

  // Category starts strictly empty (null) - no fake guesses
  DocumentType? _selectedType;
  DateTime? _selectedExpiry;

  bool _isGeminiAnalyzing = true;
  bool _geminiAttempted = false;
  bool _geminiFoundDetails = false;
  String? _geminiStatusMessage;

  String? _validationError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _regNoController = TextEditingController();
    _policyController = TextEditingController();

    // Category strictly null by default until chosen or detected
    _selectedType = null;
    _selectedExpiry = null;

    _titleController.addListener(_clearValidationError);
    _regNoController.addListener(_clearValidationError);
    _policyController.addListener(_clearValidationError);

    // Run Gemini AI extraction in post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeWithGemini();
    });
  }

  void _clearValidationError() {
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_clearValidationError);
    _regNoController.removeListener(_clearValidationError);
    _policyController.removeListener(_clearValidationError);
    _titleController.dispose();
    _regNoController.dispose();
    _policyController.dispose();
    super.dispose();
  }

  Future<void> _analyzeWithGemini() async {
    var geminiService = ref.read(geminiDocumentExtractionServiceProvider);

    if (!geminiService.isConfigured) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedKey = prefs.getString(keyGeminiApiKey);
        if (savedKey != null && savedKey.trim().isNotEmpty) {
          ref.read(geminiApiKeyProvider.notifier).setKey(savedKey.trim());
          geminiService = GeminiDocumentExtractionService(apiKey: savedKey.trim());
        }
      } catch (_) {}
    }

    if (!geminiService.isConfigured) {
      if (mounted) {
        setState(() {
          _isGeminiAnalyzing = false;
          _geminiAttempted = true;
          _geminiFoundDetails = false;
          _geminiStatusMessage =
              'Gemini API key is not configured. Please enter document details manually below, or add your Google AI Studio API key in Settings.';
        });
      }
      return;
    }

    try {
      final details = await geminiService
          .extractDetailsFromFile(widget.sourceFile)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => ExtractedDocumentDetails.error(
              'Gemini AI scan timed out. Please enter details manually below.',
            ),
          );

      if (!mounted) return;

      if (details.hasAnyDetail) {
        setState(() {
          _geminiAttempted = true;
          _geminiFoundDetails = true;

          if (details.title != null && details.title!.isNotEmpty) {
            _titleController.text = details.title!;
          }
          if (details.vehicleRegNo != null && details.vehicleRegNo!.isNotEmpty) {
            _regNoController.text = details.vehicleRegNo!;
          }
          if (details.policyNo != null && details.policyNo!.isNotEmpty) {
            _policyController.text = details.policyNo!;
          }
          if (details.documentType != null) {
            _selectedType = details.documentType!;
          }
          if (details.expiryDate != null) {
            _selectedExpiry = details.expiryDate!;
          }
          _geminiStatusMessage =
              'Gemini AI auto-detected document metadata. You may verify and edit any field below.';
        });
      } else {
        setState(() {
          _geminiAttempted = true;
          _geminiFoundDetails = false;
          _geminiStatusMessage = details.errorMessage ??
              'Gemini could not detect details from this document. Please enter the details manually below.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _geminiAttempted = true;
          _geminiFoundDetails = false;
          _geminiStatusMessage =
              'Gemini scanning encountered an issue ($e). Please manually enter document details below.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeminiAnalyzing = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final regNo = _regNoController.text.trim();
    final effectiveRegNo = regNo.isNotEmpty ? regNo : 'General';

    // In-sheet validation: Only Title and Category required for universal documents
    if (title.isEmpty || _selectedType == null) {
      setState(() {
        if (title.isEmpty && _selectedType == null) {
          _validationError = 'Document Title and Category are required.';
        } else if (title.isEmpty) {
          _validationError = 'Document Title is required.';
        } else {
          _validationError = 'Please select a Document Category.';
        }
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      final repo = ref.read(vehicleDocumentRepositoryProvider);
      await repo.saveDocument(
        documentType: _selectedType!,
        title: title,
        vehicleRegNo: effectiveRegNo,
        policyNo: _policyController.text.trim().isEmpty ? null : _policyController.text.trim(),
        expiryDate: _selectedExpiry,
        sourceFile: widget.sourceFile,
      );

      if (mounted) {
        // Close modal sheet FIRST so it never hangs open
        Navigator.of(context).pop(true);
        // Dispatch success callback to host screen
        widget.onSaveSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationError = 'Failed to save document: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeKb = (widget.fileSize / 1024).toStringAsFixed(1);
    final textColor = isLiquidGlass ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A));
    final subTextColor = isLiquidGlass ? Colors.white70 : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    final hintTextColor = isLiquidGlass ? Colors.white38 : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

    final sheetDecoration = LiquidGlassTheme.modalSheetDecoration(
      context: context,
      isLiquidGlass: isLiquidGlass,
      radius: 28,
    );

    Widget sheetBody = Container(
      decoration: sheetDecoration,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isLiquidGlass
                      ? (isDark ? Colors.white30 : Colors.black26)
                      : (isDark ? const Color(0xFF333E54) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // File Header Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLiquidGlass
                    ? (isDark ? const Color(0x22FFFFFF) : const Color(0x60FFFFFF))
                    : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLiquidGlass
                      ? (isDark ? const Color(0x33FFFFFF) : const Color(0x66FFFFFF))
                      : (isDark ? const Color(0xFF2B3548) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.accentAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.file_present_rounded,
                      color: LiquidGlassTheme.accentAmber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Document Import',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.originalName} • $sizeKb KB • Verified',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Gemini AI Status / Prompt Box
            _buildGeminiStatusBox(isLiquidGlass, isDark),
            const SizedBox(height: 16),

            // Title Field (Required & Fully Editable)
            TextField(
              controller: _titleController,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: LiquidGlassTheme.fieldDecoration(
                context: context,
                isLiquidGlass: isLiquidGlass,
                labelText: 'Document Title *',
                hintText: 'e.g. Annual Revenue License',
                prefixIcon: const Icon(Icons.title, color: LiquidGlassTheme.accentAmber, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Reference / Reg / ID No Field
            TextField(
              controller: _regNoController,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: LiquidGlassTheme.fieldDecoration(
                context: context,
                isLiquidGlass: isLiquidGlass,
                labelText: 'Reference / Reg / ID No (Optional)',
                hintText: 'e.g. NIC-1234, PNR-998, CAB-1234',
                prefixIcon: Icon(Icons.tag, color: isDark ? LiquidGlassTheme.accentElectricBlue : const Color(0xFF2563EB), size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Document Category Selector (Strictly empty default, user or AI picks)
            DropdownButtonFormField<DocumentType?>(
              key: ValueKey(_selectedType),
              initialValue: _selectedType,
              dropdownColor: isLiquidGlass
                  ? const Color(0xFF161A26)
                  : (isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9)),
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
              decoration: LiquidGlassTheme.fieldDecoration(
                context: context,
                isLiquidGlass: isLiquidGlass,
                labelText: 'Document Category *',
                prefixIcon: const Icon(Icons.category_outlined, color: LiquidGlassTheme.accentAmber, size: 20),
              ),
              hint: Text(
                'Select Document Category',
                style: TextStyle(
                  color: hintTextColor,
                  fontSize: 14,
                ),
              ),
              items: DocumentType.values.map((type) {
                return DropdownMenuItem<DocumentType?>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(type.icon, size: 18, color: LiquidGlassTheme.accentAmber),
                      const SizedBox(width: 10),
                      Text(type.label, style: TextStyle(color: textColor)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val;
                  _validationError = null;
                });
              },
            ),
            const SizedBox(height: 12),

            // Policy / Reference No (Optional & Fully Editable)
            TextField(
              controller: _policyController,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: LiquidGlassTheme.fieldDecoration(
                context: context,
                isLiquidGlass: isLiquidGlass,
                labelText: 'Policy / Reference No (Optional)',
                hintText: 'e.g. POL-99281',
                prefixIcon: const Icon(Icons.tag, color: LiquidGlassTheme.accentAmber, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Expiry Date Picker (Fully Editable)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedExpiry ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2045),
                  builder: (pickerContext, child) => Theme(
                    data: (isLiquidGlass || isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: LiquidGlassTheme.accentAmber,
                        brightness: (isLiquidGlass || isDark) ? Brightness.dark : Brightness.light,
                        primary: LiquidGlassTheme.accentAmber,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedExpiry = picked);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isLiquidGlass
                      ? const Color(0x1FFFFFFF)
                      : (isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLiquidGlass
                        ? const Color(0x33FFFFFF)
                        : (isDark ? const Color(0xFF2B3548) : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: LiquidGlassTheme.accentAmber, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expiry Date',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedExpiry != null
                                ? DateFormat.yMMMd().format(_selectedExpiry!)
                                : 'No Expiration',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: _selectedExpiry != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedExpiry != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: subTextColor, size: 18),
                        onPressed: () => setState(() => _selectedExpiry = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // In-Sheet Error Message (Shown in front of the window)
            if (_validationError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.55), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _validationError = null),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close, color: Colors.white60, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidGlassTheme.accentAmber,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: isLiquidGlass ? 4 : 2,
                  shadowColor: LiquidGlassTheme.accentAmber.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                      )
                    : const Icon(Icons.lock_outline, size: 20),
                label: Text(
                  _isSaving ? 'Encrypting & Saving...' : 'Secure & Save to Vault',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isLiquidGlass) {
      sheetBody = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: sheetBody,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: sheetBody,
    );
  }

  /// Builds the Gemini AI loading, success banner, or manual entry prompt box
  Widget _buildGeminiStatusBox(bool isLiquidGlass, bool isDark) {
    if (_isGeminiAnalyzing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Gemini AI is analyzing document details...',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isGeminiAnalyzing = false;
                  _geminiAttempted = true;
                  _geminiStatusMessage = 'Analysis skipped. Please enter details manually.';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_geminiAttempted && _geminiFoundDetails) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gemini AI Auto-Filled Details',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _geminiStatusMessage ??
                        'Details extracted automatically. You can edit any field below.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isKeyError = _geminiStatusMessage != null &&
        (_geminiStatusMessage!.toLowerCase().contains('api key not valid') ||
            _geminiStatusMessage!.toLowerCase().contains('api_key_invalid') ||
            _geminiStatusMessage!.toLowerCase().contains('invalid api key') ||
            _geminiStatusMessage!.toLowerCase().contains('api key is not configured'));

    final boxColor = isKeyError
        ? Colors.redAccent.withValues(alpha: 0.14)
        : Colors.amber.withValues(alpha: 0.12);
    final borderColor = isKeyError
        ? Colors.redAccent.withValues(alpha: 0.45)
        : Colors.amberAccent.withValues(alpha: 0.4);
    final iconColor = isKeyError ? Colors.redAccent : LiquidGlassTheme.accentAmber;
    final titleText = isKeyError ? 'Gemini API Key Issue' : 'Manual Entry Required';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isKeyError ? Icons.key_off_rounded : Icons.edit_note_rounded,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _geminiStatusMessage ??
                      'Gemini AI could not detect document details. Please enter the vehicle and document details manually below.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
