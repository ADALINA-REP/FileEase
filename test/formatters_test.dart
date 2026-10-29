import 'package:flutter_test/flutter_test.dart';
import 'package:fileease/core/utils/formatters.dart';

void main() {
  group('Formatters Tests', () {
    test('formatBytes displays appropriate units', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(512), '512.0 B');
      expect(Formatters.formatBytes(204800), '200.0 KB');
      expect(Formatters.formatBytes(1572864), '1.5 MB');
    });

    test('calculateReductionPercentage calculates space saved correctly', () {
      expect(Formatters.calculateReductionPercentage(1000, 200), 80.0);
      expect(Formatters.calculateReductionPercentage(500, 500), 0.0);
      expect(
        Formatters.calculateReductionPercentage(200, 300),
        0.0,
      ); // Negative gain
    });

    test('formatDimensions creates readable resolution string', () {
      expect(Formatters.formatDimensions(1920, 1080), '1920 × 1080 px');
      expect(Formatters.formatDimensions(413, 531), '413 × 531 px');
    });
  });
}
