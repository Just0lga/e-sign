import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../widgets/signature_pad_widget.dart';
import '../services/pdf_service.dart';

class PdfEditorScreen extends StatefulWidget {
  final File file;

  const PdfEditorScreen({Key? key, required this.file}) : super(key: key);

  @override
  _PdfEditorScreenState createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final PdfService _pdfService = PdfService();

  // _currentFile: The clean, signed PDF (Source of Truth)
  late File _currentFile;
  // _viewFile: TEMPORARY PDF with visual boxes (Displayed)
  File? _viewFile;
  
  bool _isLoading = true;
  List<Size>? _pageSizes;
  int? _jumpToPageOnLoad;
  Map<int, int> _pageRotations = {}; // Cache for rotations

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Generate visual layer with boxes
      final viewFile = await _pdfService.generateViewDataWithBoxes(_currentFile);
      
      // 2. Cache page sizes for hit-testing
      final sizes = await _pdfService.getAllPageSizes(_currentFile);

      setState(() {
        _viewFile = viewFile;
        _pageSizes = sizes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing PDF screen: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshView() async {
      // Regenerate view file after signing
      setState(() => _isLoading = true);
      try {
          final viewFile = await _pdfService.generateViewDataWithBoxes(_currentFile);
          setState(() {
              _viewFile = viewFile;
              _isLoading = false;
          });
      } catch (e) {
          setState(() => _isLoading = false);
      }
  }

  // Helper to get the Box Rect for a specific page configuration
  // MUST match the logic in PdfService.generateViewDataWithBoxes
  Rect _getBoxRect(Size pageSize, int rotation) {
    const double boxWidth = 100.0;
    const double boxHeight = 50.0;
    const double padding = 20.0;
    
    double x = 0;
    double y = 0;

    switch (rotation) {
        case 0:
            x = pageSize.width - padding - boxWidth;
            y = pageSize.height - padding - boxHeight;
            break;
        case 90:
            x = pageSize.width - padding - boxWidth;
            y = padding; 
            break;
        case 180:
            x = padding;
            y = padding;
            break;
        case 270:
            x = padding;
            y = pageSize.height - padding - boxHeight;
            break;
         default:
            x = pageSize.width - padding - boxWidth;
            y = pageSize.height - padding - boxHeight;
            break;
    }
    return Rect.fromLTWH(x, y, boxWidth, boxHeight);
  }

  void _onPdfTap(PdfGestureDetails details) async {
    if (_pageSizes == null) return;
    
    final int pageIndex = details.pageNumber - 1; // 1-based to 0-based
    if (pageIndex < 0 || pageIndex >= _pageSizes!.length) return;

    final Size pageSize = _pageSizes![pageIndex];
    final Offset tapPos = details.pagePosition;

    // Fetch rotation if not cached
    if (!_pageRotations.containsKey(pageIndex)) {
        final int rotation = await _pdfService.getPageRotation(_currentFile, pageIndex);
        _pageRotations[pageIndex] = rotation;
    }
    final int rotation = _pageRotations[pageIndex] ?? 0;

    final Rect boxRect = _getBoxRect(pageSize, rotation);

    // Hit Test
    if (boxRect.inflate(10).contains(tapPos)) {
        _openSignaturePad(pageIndex: pageIndex);
    }
  }

  void _openSignaturePad({int? pageIndex}) async {
    // 1. Determine Target Page and Properties
    final int targetPageIndex = pageIndex ?? (_pdfViewerController.pageNumber - 1);
    
    // Ensure we have size/rotation for target
    if (_pageSizes == null || targetPageIndex >= _pageSizes!.length) return;
    final Size pageSize = _pageSizes![targetPageIndex];
    
    if (!_pageRotations.containsKey(targetPageIndex)) {
        _pageRotations[targetPageIndex] = await _pdfService.getPageRotation(_currentFile, targetPageIndex);
    }
    final int rotation = _pageRotations[targetPageIndex] ?? 0;

    // 2. Open Pad
    final signatureBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SignaturePadWidget(),
    );

    if (signatureBytes != null && mounted) {
      // 3. Direct Save (Skip Placement Screen)
      setState(() => _isLoading = true);

      try {
          // Calculate Target Position (Center of the Box)
          final Rect boxRect = _getBoxRect(pageSize, rotation);
          final Offset targetCenter = boxRect.center;
          
          // Use box size for signature or default? 
          // Previous logic was fixed 100x50 anyway.
          final Size signatureSize = Size(100, 50);

          final File signedFile = await _pdfService.addSignatureToPdf(
            _currentFile,
            signatureBytes,
            targetPageIndex,
            targetCenter, // Service centers it around this point
            signatureSize,
          );

          setState(() {
            _currentFile = signedFile;
            // Stay on the same page
            _jumpToPageOnLoad = targetPageIndex + 1; 
            _pageRotations.clear(); // Clear cache
          });

          await _refreshView();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('İmza başarıyla eklendi!')),
            );
          }
      } catch (e) {
          debugPrint('Error signing: $e');
          setState(() => _isLoading = false);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e')),
            );
          }
      }
    }
  }

  void _shareFile() async {
    // Share the CLEAN file
    await Share.shareXFiles([
      XFile(_currentFile.path),
    ], text: 'İşte imzalı belgem.');
  }

  Future<void> _downloadFile() async {
    // ... (Existing download logic using _currentFile) ...
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) status = await Permission.storage.request();

        if (!status.isGranted) {
            // ... permission logic ...
        }

        if (status.isGranted) {
          final directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists())
            await directory.create(recursive: true);

          final fileName =
              'signed_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final newPath = '${directory.path}/$fileName';
          await _currentFile.copy(newPath); // Copy CLEAN file

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('İndirilenlere kaydedildi: $fileName'),
              ),
            );
          }
        } 
        // ...
      } else {
        _shareFile(); 
      }
    } catch (e) {
      // ...
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _viewFile == null) {
        return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
        );
    }
  
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context), 
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
            tooltip: 'Paylaş',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadFile,
            tooltip: 'İndir',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _openSignaturePad(), // Main FAB still works
            tooltip: 'İmza Ekle',
          ),
        ],
      ),
      // Show VIEW file
      body: SfPdfViewer.file(
        _viewFile!,
        key: ValueKey(_viewFile!.path), 
        controller: _pdfViewerController,
        onTap: _onPdfTap, // Handle touches
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          if (_jumpToPageOnLoad != null) {
            Future.delayed(const Duration(milliseconds: 100), () {
              _pdfViewerController.jumpToPage(_jumpToPageOnLoad!);
              _jumpToPageOnLoad = null;
            });
          }
        },
      ),
    );
  }
}
