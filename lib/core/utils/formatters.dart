import 'dart:math';

class Formatters {
  /// Formats byte size into human-readable string (e.g. 1.25 MB, 184 KB)
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, clampedIndex);
    return '${size.toStringAsFixed(decimals)} ${suffixes[clampedIndex]}';
  }

  /// Calculates percentage reduction between original and compressed size
  static double calculateReductionPercentage(int originalBytes, int newBytes) {
    if (originalBytes <= 0) return 0.0;
    if (newBytes >= originalBytes) return 0.0;
    return ((originalBytes - newBytes) / originalBytes) * 100.0;
  }

  /// Formats resolution dimensions (e.g. 1920 × 1080 px)
  static String formatDimensions(int width, int height) {
    return '$width × $height px';
  }
}
