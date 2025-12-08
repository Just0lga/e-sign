import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  /// Picks a PDF file from the device storage.
  /// Returns a [File] object if a file is selected, otherwise returns null.
  Future<File?> pickPdfFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }
}
