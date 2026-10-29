import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum PdfPageSizePreset { a4, letter, fitToImage }

class PdfImageEntry {
  final Uint8List bytes;
  final String name;

  const PdfImageEntry({required this.bytes, required this.name});
}

class PdfService {
  /// Converts a list of image bytes into a unified PDF document
  static Future<Uint8List> imagesToPdf({
    required List<PdfImageEntry> images,
    PdfPageSizePreset pageSize = PdfPageSizePreset.a4,
    bool compressImages = true,
  }) async {
    return compute(_imagesToPdfInternal, {
      'images': images.map((e) => e.bytes).toList(),
      'pageSize': pageSize.name,
    });
  }

  static Future<Uint8List> _imagesToPdfInternal(
    Map<String, dynamic> params,
  ) async {
    final imageBytesList = params['images'] as List<Uint8List>;
    final pageSizeStr = params['pageSize'] as String;

    final pdf = pw.Document(
      title: 'Document FileEase',
      author: 'FileEase App',
      creator: 'FileEase Offline Tools',
    );

    PdfPageFormat pageFormat;
    if (pageSizeStr == PdfPageSizePreset.letter.name) {
      pageFormat = PdfPageFormat.letter;
    } else {
      pageFormat = PdfPageFormat.a4;
    }

    for (final bytes in imageBytesList) {
      final imageProvider = pw.MemoryImage(bytes);

      if (pageSizeStr == PdfPageSizePreset.fitToImage.name) {
        // Create page dynamically matching image dimensions
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.undefined,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(imageProvider));
            },
          ),
        );
      } else {
        // Standard A4 / Letter format with professional clean padding
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }
    }

    return pdf.save();
  }
}
