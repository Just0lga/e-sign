import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  /// Adds a signature image to the specified page and position in the PDF.
  /// Returns a new [File] containing the signed PDF.
  /// Adds a signature image to the specified page and position in the PDF using digital signing.
  /// This enables incremental updates (versioning).
  Future<File> addSignatureToPdf(
    File pdfFile,
    Uint8List signatureData,
    int pageNumber,
    Offset position,
    Size signatureSize,
  ) async {
    // 1. Load the existing PDF document.
    final RandomAccessFile raf = pdfFile.openSync(mode: FileMode.read);
    final List<int> bytes = raf.readSync(raf.lengthSync());
    raf.closeSync();

    final PdfDocument document = PdfDocument(inputBytes: bytes);

    // 2. Create a signature field.
    final PdfPage page = document.pages[pageNumber];

    // Adjust position to center the signature on the tap point
    final double signatureWidth = signatureSize.width;
    final double signatureHeight = signatureSize.height;
    final double x = position.dx - (signatureWidth / 2);
    final double y = position.dy - (signatureHeight / 2);

    // Create a unique name for the field to allow multiple signatures
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fieldName = 'Signature_$timestamp';

    final PdfSignatureField signatureField = PdfSignatureField(
      page,
      fieldName,
      bounds: Rect.fromLTWH(x, y, signatureWidth, signatureHeight),
      signature: PdfSignature(
        // Load the certificate from assets
        certificate: PdfCertificate(
          (await rootBundle.load(
            'assets/certificate.pfx',
          )).buffer.asUint8List(),
          'password', // Password for the self-signed certificate
        ),
        contactInfo: 'tolga@example.com',
        locationInfo: 'Turkey',
        reason: 'Document Signed via E-Sign App',
        digestAlgorithm: DigestAlgorithm.sha256,
        cryptographicStandard: CryptographicStandard.cms,
      ),
    );

    // 3. Set the visual appearance (the user's signature image)
    final PdfBitmap signatureImage = PdfBitmap(signatureData);
    signatureField.appearance.normal.graphics?.drawImage(
      signatureImage,
      Rect.fromLTWH(0, 0, signatureWidth, signatureHeight),
    );

    // Add the field to the document
    // Add the field to the document

    // Add the field to the document
    document.form.fields.add(signatureField);

    // 4. Save the document incrementally.
    // Syncfusion automatically performs incremental update when fields are signed.
    final List<int> signedBytes = await document.save();
    document.dispose();

    // Overwrite the file or create a NEW file?
    // "Ensure the output file retains the history of all previous saves."
    // Incremental updates work best when appending to the same file structure,
    // but practically we often save to a new file to avoid corruption risks during dev.
    // However, for version history to really "stick" in a chain, we just need the bytes to contain the prev content + delta.

    final Directory dir = await getTemporaryDirectory();
    final String path = '${dir.path}/signed_$timestamp.pdf';
    final File file = File(path);
    await file.writeAsBytes(signedBytes, flush: true);

    return file;
  }

  /// Gets the size of a specific page in the PDF.
  Future<Size> getPageSize(File pdfFile, int pageNumber) async {
    final PdfDocument document = PdfDocument(
      inputBytes: await pdfFile.readAsBytes(),
    );
    final PdfPage page = document.pages[pageNumber];
    final Size size = page.size;
    document.dispose();
    return size;
  }

  /// Gets the size of all pages in the PDF.
  Future<List<Size>> getAllPageSizes(File pdfFile) async {
    final PdfDocument document = PdfDocument(
      inputBytes: await pdfFile.readAsBytes(),
    );
    int count = document.pages.count;
    List<Size> sizes = [];
    for (int i = 0; i < count; i++) {
      sizes.add(document.pages[i].size);
    }
    document.dispose();
    return sizes;
  }

  /// Generates a temporary PDF file with visual "Sign Here" boxes on every page.

  /// This file is for display purposes only and should NOT be used for final saving.
  Future<File> generateViewDataWithBoxes(File pdfFile) async {
    final PdfDocument document = PdfDocument(
      inputBytes: await pdfFile.readAsBytes(),
    );

    // Define box properties
    const double boxWidth = 150.0;
    const double boxHeight = 75.0;
    const double padding = 20.0;

    // Create a brush/pen for drawing
    final PdfPen pen = PdfPen(PdfColor(0, 0, 255), width: 2); // Blue border
    final PdfBrush brush = PdfSolidBrush(
      PdfColor(0, 0, 255, 30),
    ); // Light blue fill
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfBrush textBrush = PdfSolidBrush(PdfColor(0, 0, 0));

    int count = document.pages.count;
    for (int i = 0; i < count; i++) {
      final PdfPage page = document.pages[i];
      final Size pageSize = page.size;

      // Always place at Bottom-Right (Ignoring rotation as app is locked)
      // If the PDF itself has rotation metadata, Syncfusion coordinate system usually handles it relative to the visual top-left of the rotated page?
      // OR the coordinate system is fixed to 0,0 top-left of *unrotated* usually.
      // User asked to REMOVE rotation functions. So we assume standard coordinate behavior.
      // If the page IS rotated, and we draw at (W-pad, H-pad), it might end up at Top-Right (if 90 deg).
      // BUT user explicitly said "rotate ile ilgili fonksiyonları kaldır".
      // They might be assuming all their PDFs are standard or they don't care about the edge cases anymore.
      // We will place it at (Width - Box - padding, Height - Box - padding).

      double x = pageSize.width - padding - boxWidth;
      double y = pageSize.height - padding - boxHeight;

      // Draw the box
      page.graphics.drawRectangle(
        pen: pen,
        brush: brush,
        bounds: Rect.fromLTWH(x, y, boxWidth, boxHeight),
      );

      // Draw text "İmza"
      page.graphics.drawString(
        'Buraya İmzala',
        font,
        brush: textBrush,
        bounds: Rect.fromLTWH(
          x,
          y + 25,
          boxWidth,
          boxHeight,
        ), // Center vertically
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    // Save to temp file
    final List<int> bytes = await document.save();
    document.dispose();

    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/view_layer_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }
}
