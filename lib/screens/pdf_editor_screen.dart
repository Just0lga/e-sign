import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../widgets/signature_pad_widget.dart';
import 'signature_placement_screen.dart';

class PdfEditorScreen extends StatefulWidget {
  final File file;

  const PdfEditorScreen({Key? key, required this.file}) : super(key: key);

  @override
  _PdfEditorScreenState createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  // Dosya değişebileceği için (imzalanınca) state içinde tutuyoruz
  late File _currentFile;
  int? _jumpToPageOnLoad;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
  }

  void _openSignaturePad() async {
    final int currentPage = _pdfViewerController.pageNumber;

    final signatureBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SignaturePadWidget(),
    );

    if (signatureBytes != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignaturePlacementScreen(
            pdfFile: _currentFile,
            signatureBytes: signatureBytes,
            initialPage: currentPage,
          ),
        ),
      );

      if (result != null && result is Map) {
        final File signedFile = result['file'];
        final int targetPage = result['page'];

        setState(() {
          _currentFile = signedFile;
          _jumpToPageOnLoad = targetPage;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İmza başarıyla eklendi!'),
            ),
          );
        }
      }
    }
  }

  void _shareFile() async {
    await Share.shareXFiles([
      XFile(_currentFile.path),
    ], text: 'İşte imzalı belgem.');
  }

  Future<void> _downloadFile() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) status = await Permission.storage.request();

        if (!status.isGranted) {
          var manageStatus = await Permission.manageExternalStorage.status;
          if (!manageStatus.isGranted)
            manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted) status = PermissionStatus.granted;
        }

        if (status.isGranted) {
          final directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists())
            await directory.create(recursive: true);

          final fileName =
              'signed_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final newPath = '${directory.path}/$fileName';
          await _currentFile.copy(newPath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('İndirilenlere kaydedildi: $fileName'),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Depolama izni reddedildi.'),
              ),
            );
          }
        }
      } else {
        _shareFile(); // iOS için
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme hatası: $e'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context), // Ana sayfaya dön
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
            onPressed: _openSignaturePad,
            tooltip: 'İmza Ekle',
          ),
        ],
      ),
      body: SfPdfViewer.file(
        _currentFile,
        controller: _pdfViewerController,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          if (_jumpToPageOnLoad != null) {
            _pdfViewerController.jumpToPage(_jumpToPageOnLoad!);
            _jumpToPageOnLoad = null;
          }
        },
      ),
    );
  }
}
