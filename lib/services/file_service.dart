import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SelectedFileItem {
  final String path;
  final String name;
  final int sizeInBytes;
  final Uint8List bytes;

  const SelectedFileItem({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.bytes,
  });
}

class FileService {
  static const List<String> supportedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'gif',
    'tiff',
    'tif',
    'ico',
    'heic',
    'heif',
    'jfif',
  ];

  /// Pick a single image from storage
  static Future<SelectedFileItem?> pickSingleImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedImageExtensions,
    );

    if (files.isEmpty) return null;
    final file = files.first;

    final bytes = await file.readAsBytes();
    final size = (await file.length()) ?? bytes.lengthInBytes;

    return SelectedFileItem(
      path: file.path ?? '',
      name: file.name,
      sizeInBytes: size,
      bytes: bytes,
    );
  }

  /// Pick multiple images from storage
  static Future<List<SelectedFileItem>> pickMultipleImages() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedImageExtensions,
    );

    if (files.isEmpty) return [];

    final list = <SelectedFileItem>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final size = (await file.length()) ?? bytes.lengthInBytes;
      list.add(
        SelectedFileItem(
          path: file.path ?? '',
          name: file.name,
          sizeInBytes: size,
          bytes: bytes,
        ),
      );
    }
    return list;
  }

  /// Pick multiple PDF files
  static Future<List<SelectedFileItem>> pickMultiplePdfs() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isEmpty) return [];

    final list = <SelectedFileItem>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final size = (await file.length()) ?? bytes.lengthInBytes;
      list.add(
        SelectedFileItem(
          path: file.path ?? '',
          name: file.name,
          sizeInBytes: size,
          bytes: bytes,
        ),
      );
    }
    return list;
  }

  /// Save processed bytes to app's dedicated cache/export directory
  static Future<File> saveExportFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final exportDir = Directory('${dir.path}/FileEase_Exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final filePath = '${exportDir.path}/$sanitizedName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Share file natively via system share sheet
  static Future<void> shareFile({
    required String filePath,
    required String mimeType,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: mimeType)],
        subject: subject ?? 'Partagé via FileEase',
      ),
    );
  }

  /// Open file with default viewer app
  static Future<OpenResult> openFile(String filePath) async {
    return OpenFilex.open(filePath);
  }

  /// Clean temporary export files to preserve privacy and free disk storage
  static Future<int> cleanTemporaryFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final exportDir = Directory('${dir.path}/FileEase_Exports');
      if (await exportDir.exists()) {
        int count = 0;
        final list = exportDir.listSync();
        for (final item in list) {
          if (item is File) {
            await item.delete();
            count++;
          }
        }
        return count;
      }
    } catch (_) {}
    return 0;
  }
}
