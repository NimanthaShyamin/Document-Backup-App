import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/document_type.dart';
import '../controllers/document_providers.dart';

/// Bottom sheet dialog for reviewing, editing, and confirming imported vehicle document metadata.
/// Automatically initiates Gemini AI extraction upon presentation.
/// If Gemini fails or cannot find details, presents a prompt box asking the user to manually enter
/// the details while keeping all fields completely editable.
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

  late DocumentType _selectedType;
  DateTime? _selectedExpiry;

  bool _isGeminiAnalyzing = true;
  bool _geminiAttempted = false;
  bool _geminiFoundDetails = false;
  String? _geminiStatusMessage;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _regNoController = TextEditingController();
    _policyController = TextEditingController();

    // Initial best-effort heuristic based on extension and filename
    if (widget.extension == 'pdf') {
      _selectedType = DocumentType.revenueLicense;
    } else if (widget.originalName.toLowerCase().contains('fuel') ||
        widget.originalName.toLowerCase().contains('qr')) {
      _selectedType = DocumentType.fuelQr;
    } else if (widget.originalName.toLowerCase().contains('insurance')) {
      _selectedType = DocumentType.insuranceCard;
    } else {
      _selectedType = DocumentType.custom;
    }

    _selectedExpiry = null;

    // Run Gemini AI extraction in post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeWithGemini();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regNoController.dispose();
    _policyController.dispose();
    super.dispose();
  }

  Future<void> _analyzeWithGemini() async {
    final geminiService = ref.read(geminiDocumentExtractionServiceProvider);

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
      final details = await geminiService.extractDetailsFromFile(widget.sourceFile);

      if (!mounted) return;

      if (details.hasAnyDetail) {
        setState(() {
          _isGeminiAnalyzing = false;
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
          _isGeminiAnalyzing = false;
          _geminiAttempted = true;
          _geminiFoundDetails = false;
          _geminiStatusMessage = details.errorMessage ??
              'Gemini could not detect details from this document. Please enter the details manually below.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeminiAnalyzing = false;
          _geminiAttempted = true;
          _geminiFoundDetails = false;
          _geminiStatusMessage =
              'Gemini scanning encountered an issue ($e). Please manually enter document details below.';
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final regNo = _regNoController.text.trim();

    if (title.isEmpty || regNo.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document Title and Vehicle Registration No are required.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(vehicleDocumentRepositoryProvider);
      await repo.saveDocument(
        documentType: _selectedType,
        title: title,
        vehicleRegNo: regNo,
        policyNo: _policyController.text.trim().isEmpty ? null : _policyController.text.trim(),
        expiryDate: _selectedExpiry,
        sourceFile: widget.sourceFile,
      );

      if (mounted) {
        widget.onSaveSuccess?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeKb = (widget.fileSize / 1024).toStringAsFixed(1);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File Header Card
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.file_present_rounded,
                      color: Colors.amberAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure Document Import',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.originalName} • $sizeKb KB • Verified Format',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Gemini AI Status / Prompt Box
              _buildGeminiStatusBox(),

              const SizedBox(height: 16),

              // Title Field (Fully Editable)
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Document Title',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.title, color: Colors.amberAccent, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF222228),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Vehicle Reg No Field (Fully Editable)
              TextField(
                controller: _regNoController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Vehicle Registration No',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.pin, color: Colors.amberAccent, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF222228),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Document Category Selector (Fully Editable)
              DropdownButtonFormField<DocumentType>(
                key: ValueKey(_selectedType),
                initialValue: _selectedType,
                dropdownColor: const Color(0xFF222228),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Document Category',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.category, color: Colors.amberAccent, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF222228),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: DocumentType.values.map((type) {
                  return DropdownMenuItem<DocumentType>(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedType = val);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Policy / Reference No (Fully Editable)
              TextField(
                controller: _policyController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Policy / Reference No (Optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.tag, color: Colors.amberAccent, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF222228),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.amberAccent,
                          onPrimary: Colors.black,
                          surface: Color(0xFF1E1E24),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() => _selectedExpiry = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222228),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expiry Date',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedExpiry != null
                                  ? DateFormat.yMMMd().format(_selectedExpiry!)
                                  : 'No Expiration',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedExpiry != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () => setState(() => _selectedExpiry = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
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
      ),
    );
  }

  /// Builds either the Gemini AI loading shimmer, success banner, or manual prompt box.
  Widget _buildGeminiStatusBox() {
    if (_isGeminiAnalyzing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gemini AI is analyzing document details...',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isKeyError = _geminiStatusMessage != null &&
        (_geminiStatusMessage!.toLowerCase().contains('api key') ||
            _geminiStatusMessage!.toLowerCase().contains('invalid') ||
            _geminiStatusMessage!.contains('AIzaSy'));

    final boxColor = isKeyError
        ? Colors.redAccent.withValues(alpha: 0.12)
        : Colors.amber.withValues(alpha: 0.12);
    final borderColor = isKeyError
        ? Colors.redAccent.withValues(alpha: 0.4)
        : Colors.amberAccent.withValues(alpha: 0.4);
    final iconColor = isKeyError ? Colors.redAccent : Colors.amberAccent;
    final titleText = isKeyError ? 'Gemini API Key Issue' : 'Manual Entry Required';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
