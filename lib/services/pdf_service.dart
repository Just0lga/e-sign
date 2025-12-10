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
          (await rootBundle.load('assets/certificate.pfx')).buffer.asUint8List(),
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
  /// Adds a signature to a fixed position (Page 4, specific coordinates).
  Future<File> addFixedSignatureToPdf(
    File pdfFile,
    Uint8List signatureData,
  ) async {
    final PdfDocument document =
        PdfDocument(inputBytes: await pdfFile.readAsBytes());

    // Ensure the document has at least 4 pages.
    if (document.pages.count < 4) {
      document.dispose();
      throw Exception('PDF must have at least 4 pages to sign on page 4.');
    }

    // Page 4 is index 3
    final PdfPage page = document.pages[3];
    final PdfBitmap signatureImage = PdfBitmap(signatureData);

    // Fixed coordinates: Left: 150, Top: 550, Width: 100, Height: 50
    page.graphics.drawImage(
      signatureImage,
      const Rect.fromLTWH(150, 550, 100, 50),
    );

    final List<int> bytes = await document.save();
    document.dispose();

    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/signed_fixed_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  /// Adds a signature, attaches the original file as a backup version, and locks the document.
  Future<File> addSecureSignatureWithVersionHistory(
    File pdfFile,
    Uint8List signatureData,
  ) async {
    // 1. Versioning (Backup)
    // Read the original file bytes to keep as an attachment
    final List<int> originalBytes = await pdfFile.readAsBytes();
    
    // Load the document for editing
    final PdfDocument document = PdfDocument(inputBytes: originalBytes);

    // Create the attachment
    final PdfAttachment attachment = PdfAttachment(
      'orijinal_imzasiz_kopyasi.pdf',
      originalBytes,
      description: 'Bu belge imzalanmadan önceki orijinal kopyadır.',
      mimeType: 'application/pdf',
    );
    
    // Add attachment to the document
    document.attachments.add(attachment);

    // 2. Signature Placement
    // Ensure the document has at least 4 pages to sign on index 3.
    if (document.pages.count < 4) {
      document.dispose();
      throw Exception('PDF must have at least 4 pages to sign on page 4.');
    }

    final PdfPage page = document.pages[3];
    final PdfBitmap signatureImage = PdfBitmap(signatureData);

    // Fixed coordinates: Left: 150, Top: 550, Width: 100, Height: 50
    page.graphics.drawImage(
      signatureImage,
      const Rect.fromLTWH(150, 550, 100, 50),
    );

    // 3. Security (Locking)
    final PdfSecurity security = document.security;
    
    // Set Owner Password (random strong string for admin)
    security.ownerPassword = 'AdminSecretPassword123!'; 
    // User Password empty so anyone can open it
    security.userPassword = ''; 
    
    // Restrict permissions
    security.permissions.addAll([
      PdfPermissionsFlags.print,
      PdfPermissionsFlags.copyContent,
    ]);
    // Ensure editing is NOT allowed (it is strictly additive)
    // Note: By default, if we don't add 'editContent', it's restricted once permissions are set.

    // 4. Save
    final List<int> bytes = await document.save();
    document.dispose();

    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/imzali_v2_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  /// Gets the size of a specific page in the PDF.
  Future<Size> getPageSize(File pdfFile, int pageNumber) async {
    final PdfDocument document =
        PdfDocument(inputBytes: await pdfFile.readAsBytes());
    final PdfPage page = document.pages[pageNumber];
    final Size size = page.size;
    document.dispose();
    return size;
  }

  /// Gets the size of all pages in the PDF.
  Future<List<Size>> getAllPageSizes(File pdfFile) async {
    final PdfDocument document =
        PdfDocument(inputBytes: await pdfFile.readAsBytes());
    int count = document.pages.count;
    List<Size> sizes = [];
    for (int i = 0; i < count; i++) {
      sizes.add(document.pages[i].size);
    }
    document.dispose();
    return sizes;
  }
}
