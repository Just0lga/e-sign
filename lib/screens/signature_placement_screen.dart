import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/pdf_service.dart';

class SignaturePlacementScreen extends StatefulWidget {
  final File pdfFile;
  final Uint8List signatureBytes;
  final int initialPage;

  const SignaturePlacementScreen({
    Key? key,
    required this.pdfFile,
    required this.signatureBytes,
    this.initialPage = 1,
  }) : super(key: key);

  @override
  _SignaturePlacementScreenState createState() =>
      _SignaturePlacementScreenState();
}

class _SignaturePlacementScreenState extends State<SignaturePlacementScreen> {
  final PdfService _pdfService = PdfService();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isSaving = false;
  bool _isLoadingSizes = true;

  // State for draggable signature
  Offset? _signaturePosition; // Screen coordinates relative to the PDF view
  double _signatureWidth = 100.0;
  double _signatureHeight = 50.0; // Initial aspect ratio will be set on load
  double _aspectRatio = 2.0;
  double _initialSignatureWidth = 100.0;

  List<Size>? _allPageSizes;
  GlobalKey _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _calculateAspectRatio();
    _loadPageSizes();
  }

  void _calculateAspectRatio() async {
    final image = await decodeImageFromList(widget.signatureBytes);
    setState(() {
      _aspectRatio = image.width / image.height;
      _signatureHeight = _signatureWidth / _aspectRatio;
    });
  }

  Future<void> _loadPageSizes() async {
    try {
      _allPageSizes = await _pdfService.getAllPageSizes(widget.pdfFile);
    } catch (e) {
      debugPrint('Error loading page sizes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSizes = false;
        });
      }
    }
  }

  void _handleTap(PdfGestureDetails details) {
    if (_isSaving || _signaturePosition != null || _isLoadingSizes) return;

    setState(() {
      // Initial position based on tap - center the signature
      _signaturePosition = details.position;
    });
  }

  void _onSave() async {
    if (_signaturePosition == null || _allPageSizes == null) return;

    setState(() {
      _isSaving = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Calculate final PDF position based on scroll offset and page sizes
      final double viewportWidth = MediaQuery.of(context).size.width;
      final double zoomLevel = _pdfViewerController.zoomLevel;
      final double scrollOffset = _pdfViewerController.scrollOffset.dy;

      // Absolute Y position in the rendered document (center of the signature)
      double absoluteY = scrollOffset + _signaturePosition!.dy;

      int targetPage = 0;
      Offset finalPdfPosition = Offset.zero;

      // Default spacing for SfPdfViewer is usually around 4 logical pixels
      const double pageSpacing = 4.0;

      for (int i = 0; i < _allPageSizes!.length; i++) {
        final Size pageSize = _allPageSizes![i];

        // Calculate rendered dimensions for this page
        final double scale = (viewportWidth / pageSize.width) * zoomLevel;
        final double renderedHeight = pageSize.height * scale;

        if (absoluteY <= renderedHeight) {
          // Found the target page
          targetPage = i;

          // Calculate PDF coordinates
          final double scrollOffsetX = _pdfViewerController.scrollOffset.dx;
          final double absoluteX = scrollOffsetX + _signaturePosition!.dx;

          final double pdfX = absoluteX / scale;
          final double pdfY = absoluteY / scale;

          finalPdfPosition = Offset(pdfX, pdfY);
          break;
        } else {
          // Move to next page
          absoluteY -= (renderedHeight + (pageSpacing * zoomLevel));
        }
      }

      // If we went past the last page (e.g. bottom margin), clamp to last page
      if (targetPage >= _allPageSizes!.length) {
        targetPage = _allPageSizes!.length - 1;
      }

      // Calculate the size in PDF units
      // We need the scale factor of the target page
      final Size targetPageSize = _allPageSizes![targetPage];
      final double scale = (viewportWidth / targetPageSize.width) * zoomLevel;
      final Size pdfSignatureSize = Size(
        _signatureWidth / scale,
        _signatureHeight / scale,
      );

      final File newFile = await _pdfService.addSignatureToPdf(
        widget.pdfFile,
        widget.signatureBytes,
        targetPage,
        finalPdfPosition,
        pdfSignatureSize,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        Navigator.of(context).pop({
          'file': newFile,
          'page': targetPage + 1, // Return 1-indexed page for UI
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İmza ekleme hatası: $e'),
          ),
        );
      }
    }
  }

  void _deleteSignature() {
    setState(() {
      _signaturePosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'İmzayı Yerleştir',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          if (_signaturePosition != null)
            IconButton(icon: const Icon(Icons.check), onPressed: _onSave),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(
            widget.pdfFile,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            enableDoubleTapZooming: false, // Disable double tap zoom
            maxZoomLevel: 1.0, // Disable pinch zoom by setting max zoom to 1.0
            onTap: (details) {
              if (_signaturePosition == null) {
                _handleTap(details);
              }
            },
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              _pdfViewerController.jumpToPage(widget.initialPage);
            },
          ),
          if (_isLoadingSizes) const Center(child: CircularProgressIndicator()),
          if (_signaturePosition == null && !_isLoadingSizes)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'İmzanızı yerleştirmek için PDF üzerinde herhangi bir yere dokunun',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (_signaturePosition != null)
            Positioned(
              left: _signaturePosition!.dx - (_signatureWidth / 2),
              top: _signaturePosition!.dy - (_signatureHeight / 2),
              child: GestureDetector(
                onScaleStart: (details) {
                  _initialSignatureWidth = _signatureWidth;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    // Update position
                    _signaturePosition = Offset(
                      _signaturePosition!.dx + details.focalPointDelta.dx,
                      _signaturePosition!.dy + details.focalPointDelta.dy,
                    );

                    // Update size
                    double newWidth = _initialSignatureWidth * details.scale;
                    double maxWidth = MediaQuery.of(context).size.width;

                    if (newWidth < 50) newWidth = 50;
                    if (newWidth > maxWidth) newWidth = maxWidth;

                    _signatureWidth = newWidth;
                    _signatureHeight = _signatureWidth / _aspectRatio;
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _signatureWidth,
                      height: _signatureHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Image.memory(
                        widget.signatureBytes,
                        fit: BoxFit.fill,
                      ),
                    ),
                    // Delete Button
                    Positioned(
                      top: -20, // Increased hit area
                      right: -20, // Increased hit area
                      child: GestureDetector(
                        onTap: _deleteSignature,
                        child: Container(
                          color: Colors.transparent, // Hit test target
                          padding: const EdgeInsets.all(
                            8,
                          ), // Larger touch target
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 20, // Slightly larger icon
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
