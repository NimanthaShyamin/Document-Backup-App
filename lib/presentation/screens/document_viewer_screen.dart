import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/hardware/brightness_controller.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/vehicle_document.dart';
import '../utils/document_action_helper.dart';

/// Enterprise-grade universal document viewer with automated screen luminance elevation.
/// Supports multi-page PDFs, rasterized certificates (PNG/JPG/WEBP), and vector QR codes.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  final VehicleDocument document;

  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  final BrightnessControllerService _brightnessService =
      BrightnessControllerService.instance;
  final TransformationController _transformationController =
      TransformationController();

  PdfControllerPinch? _pdfController;
  int _currentPdfPage = 1;
  int _totalPdfPages = 0;
  bool _isPdfLoading = false;
  String? _pdfLoadError;
  bool _isFullScreen = false;

  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    // Programmatically elevate device screen brightness to 100% (1.0)
    _brightnessService.elevateBrightness();

    if (_isPdfDocument()) {
      _initializePdf();
    }
  }

  bool _isPdfDocument() {
    return widget.document.documentType == DocumentType.revenueLicense ||
        widget.document.localFilePath.toLowerCase().endsWith('.pdf');
  }

  bool _isQrDocument() {
    return widget.document.documentType == DocumentType.fuelQr;
  }

  Future<void> _initializePdf() async {
    setState(() {
      _isPdfLoading = true;
      _pdfLoadError = null;
    });

    try {
      final file = File(widget.document.localFilePath);
      if (!await file.exists()) {
        throw FileSystemException(
            'PDF file does not exist in sandboxed storage', file.path);
      }

      final doc = await PdfDocument.openFile(file.path);
      _pdfController = PdfControllerPinch(
        document: Future.value(doc),
        initialPage: 1,
      );

      setState(() {
        _totalPdfPages = doc.pagesCount;
        _isPdfLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPdfLoading = false;
        _pdfLoadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    // Strictly restore previous system brightness level
    _brightnessService.restoreBrightness();
    _pdfController?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  bool get _canSwipeDismiss {
    // Prevent drag down dismiss if zoomed in
    final scale = _transformationController.value.getMaxScaleOnAxis();
    return scale <= 1.05;
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - (_dragOffsetY / 400.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullScreen
          ? null
          : AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.85),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.document.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.document.vehicleRegNo} • ${_formatDocType(widget.document.documentType)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Reset Zoom',
                  icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                  onPressed: _resetZoom,
                ),
                IconButton(
                  tooltip: 'Full Screen',
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: _toggleFullScreen,
                ),
                IconButton(
                  tooltip: 'Delete Document',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final deleted = await DocumentActionHelper.confirmAndDeleteDocument(
                      context: context,
                      ref: ref,
                      document: widget.document,
                    );
                    if (deleted && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          if (!_canSwipeDismiss) return;
          if (details.delta.dy > 0 || _dragOffsetY > 0) {
            setState(() {
              _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(0.0, 600.0);
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (!_canSwipeDismiss) return;
          if (_dragOffsetY > 110 || (details.primaryVelocity ?? 0) > 600) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              _dragOffsetY = 0.0;
            });
          }
        },
        onVerticalDragCancel: () {
          setState(() {
            _dragOffsetY = 0.0;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, _dragOffsetY, 0.0),
          child: Opacity(
            opacity: opacity,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 1. Swipe Handle & High-Luminance Indicator Banner
                  if (!_isFullScreen) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBrightnessPill(),
                    const SizedBox(height: 10),
                  ],

                  // 2. Core Document Content in an Expanded, balanced container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: _buildDocumentContent(),
                          ),
                          if (_isPdfDocument() && _totalPdfPages > 1)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: _buildPdfPageIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom Information & Metadata Card
                  if (!_isFullScreen)
                    _buildMetadataOverlay(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentContent() {
    if (_isQrDocument()) {
      return _buildQrView();
    } else if (_isPdfDocument()) {
      return _buildPdfView();
    } else {
      return _buildImageView();
    }
  }

  Widget _buildQrView() {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: widget.document.policyNo ?? widget.document.id,
            version: QrVersions.auto,
            size: 260.0,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.document.vehicleRegNo,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Colors.black87,
            ),
          ),
          Text(
            'QUICK FUEL PASS VALIDATED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfView() {
    if (_isPdfLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Decrypting sandboxed PDF...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (_pdfLoadError != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to render PDF: $_pdfLoadError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_pdfController == null) {
      return const SizedBox.shrink();
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() {
          _currentPdfPage = page;
        });
      },
    );
  }

  Widget _buildImageView() {
    final file = File(widget.document.localFilePath);

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 6.0,
      clipBehavior: Clip.none,
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, color: Colors.amber, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Unable to load image from local storage:\n${widget.document.localFilePath}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrightnessPill() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.brightness_high, color: Colors.amber, size: 16),
            SizedBox(width: 8),
            Text(
              '100% Luminance Active (Auto-Restores on Exit)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'Page $_currentPdfPage of $_totalPdfPages',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetadataOverlay(BuildContext context) {
    final expiry = widget.document.expiryDate;
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.document.vehicleRegNo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              _buildExpiryBadge(isExpired, expiry),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.document.policyNo != null)
            Text(
              'Ref/Policy: ${widget.document.policyNo}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                widget.document.syncStatus.icon,
                size: 14,
                color: widget.document.syncStatus.color,
              ),
              const SizedBox(width: 6),
              Text(
                'Cloud: ${widget.document.syncStatus.label}',
                style: TextStyle(
                  color: widget.document.syncStatus.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'SHA-256: ${widget.document.fileChecksumSha256.substring(0, 8)}...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryBadge(bool isExpired, DateTime? expiry) {
    if (expiry == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'NO EXPIRY',
          style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
      );
    }

    final color = isExpired ? Colors.redAccent : Colors.greenAccent;
    final text = isExpired
        ? 'EXPIRED (${_formatDate(expiry)})'
        : 'VALID TILL ${_formatDate(expiry)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDocType(DocumentType type) {
    switch (type) {
      case DocumentType.fuelQr:
        return 'National Fuel Pass';
      case DocumentType.insuranceCard:
        return 'Motor Insurance Certificate';
      case DocumentType.revenueLicense:
        return 'Annual Revenue License';
      case DocumentType.custom:
        return 'Vehicle Document';
    }
  }
}
