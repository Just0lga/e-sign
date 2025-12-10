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

  // Fixed signature size
  final double _signatureWidth = 100.0;
  double _signatureHeight = 50.0;
  double _aspectRatio = 2.0;

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
    if (mounted) {
      setState(() {
        _aspectRatio = image.width / image.height;
        _signatureHeight = _signatureWidth / _aspectRatio;
      });
    }
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

  void _onSave() async {
    if (_allPageSizes == null) return;

    setState(() {
      _isSaving = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get current page number (1-based)
      final int currentPage = _pdfViewerController.pageNumber;
      // Convert to 0-based index
      final int targetPageIndex = currentPage - 1;

      // Validate page index
      if (targetPageIndex < 0 || targetPageIndex >= _allPageSizes!.length) {
        throw Exception('Geçersiz sayfa numarası: $currentPage');
      }

      final Size pageSize = _allPageSizes![targetPageIndex];

      // Calculate size in PDF units
      // We'll use a fixed width relative to page width or fixed points?
      // existing code used screen-to-pdf scaling.
      // Let's assume a reasonable size on PDF. E.g., 100-150 points width.
      // Or we can try to respect the visual aspect ratio.
      // Let's define a fixed PDF width for the signature, say 150 points.
      // Or calculate based on the screen visualization?
      // The previous code mapped screen pixels to PDF pixels based on zoom.
      // Here we don't have a specific "screen" size mapping because we aren't dragging.
      // Let's give it a standard size, e.g., 20% of page width.

      final double pdfSignatureWidth =
          pageSize.width * 0.25; // 25% of page width
      final double pdfSignatureHeight = pdfSignatureWidth / _aspectRatio;

      // Calculate position (Bottom Right)
      // PdfService expects the CENTER point of the signature.
      // We want the bounding box to be at Bottom-Right with padding.
      // Bounding Box Left = PageWidth - Padding - Width
      // Bounding Box Top = PageHeight - Padding - Height
      // Center X = Left + Width/2 = PageWidth - Padding - Width/2
      // Center Y = Top + Height/2 = PageHeight - Padding - Height/2

      const double padding = 20.0;

      final double pdfX = pageSize.width - padding - (pdfSignatureWidth / 2);
      final double pdfY = pageSize.height - padding - (pdfSignatureHeight / 2);

      final Offset finalPdfPosition = Offset(pdfX, pdfY);
      final Size pdfSignatureSize = Size(pdfSignatureWidth, pdfSignatureHeight);

      final File newFile = await _pdfService.addSignatureToPdf(
        widget.pdfFile,
        widget.signatureBytes,
        targetPageIndex,
        finalPdfPosition,
        pdfSignatureSize,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        Navigator.of(context).pop({
          'file': newFile,
          'page': currentPage, // Return 1-indexed page
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İmza ekleme hatası: $e')));
      }
    }
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
          IconButton(icon: const Icon(Icons.check), onPressed: _onSave),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(
            widget.pdfFile,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            enableDoubleTapZooming: true,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              _pdfViewerController.jumpToPage(widget.initialPage);
            },
          ),
          if (_isLoadingSizes) const Center(child: CircularProgressIndicator()),

          // Fixed Bottom-Right Preview
          if (!_isLoadingSizes)
            Positioned(
              bottom: 100,
              right: 10,
              child: Container(
                width: _signatureWidth,
                height: _signatureHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  color: Colors.white.withOpacity(
                    0.1,
                  ), // Slight background for visibility
                ),
                child: Image.memory(widget.signatureBytes, fit: BoxFit.contain),
              ),
            ),

          // Info text at top
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
                'İmza sayfanın sağ altına eklenecektir.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
