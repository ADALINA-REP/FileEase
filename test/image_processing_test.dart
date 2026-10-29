import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fileease/services/image_service.dart';

void main() {
  group('ImageService Unit Tests', () {
    late Uint8List testImageBytes;

    setUp(() {
      // Create a test 800x600 image in memory
      final testImg = img.Image(width: 800, height: 600);
      img.fill(testImg, color: img.ColorRgb8(30, 80, 200));
      testImageBytes = Uint8List.fromList(img.encodeJpg(testImg, quality: 90));
    });

    test('extractMetadata correctly reads resolution and format', () async {
      final meta = await ImageService.extractMetadata(testImageBytes);
      expect(meta, isNotNull);
      expect(meta!.width, 800);
      expect(meta.height, 600);
      expect(meta.sizeInBytes, testImageBytes.lengthInBytes);
    });

    test('compressByQuality reduces file size at lower quality', () async {
      final highQ = await ImageService.compressByQuality(
        bytes: testImageBytes,
        quality: 90,
      );
      final lowQ = await ImageService.compressByQuality(
        bytes: testImageBytes,
        quality: 30,
      );

      expect(lowQ.sizeInBytes, lessThan(highQ.sizeInBytes));
      expect(lowQ.width, 800);
      expect(lowQ.height, 600);
    });

    test('compressToTargetSize stays within target bounds', () async {
      const targetSize = 25 * 1024; // 25 KB
      final result = await ImageService.compressToTargetSize(
        bytes: testImageBytes,
        targetSizeInBytes: targetSize,
      );

      expect(result.sizeInBytes, lessThanOrEqualTo(targetSize));
      expect(result.formatName, 'JPEG');
    });

    test('resizeImage with aspect ratio lock scales properly', () async {
      final result = await ImageService.resizeImage(
        bytes: testImageBytes,
        targetWidth: 400,
        keepAspectRatio: true,
      );

      expect(result.width, 400);
      expect(result.height, 300); // 800x600 scaled to width 400 gives height 300
    });

    test('convertFormat converts JPEG to PNG, BMP and GIF', () async {
      final pngResult = await ImageService.convertFormat(
        bytes: testImageBytes,
        targetFormat: ImageFormatType.png,
      );
      expect(pngResult.formatName, 'PNG');
      expect(pngResult.width, 800);
      expect(pngResult.height, 600);

      final bmpResult = await ImageService.convertFormat(
        bytes: testImageBytes,
        targetFormat: ImageFormatType.bmp,
      );
      expect(bmpResult.formatName, 'BMP');
      expect(bmpResult.width, 800);
      expect(bmpResult.height, 600);

      final gifResult = await ImageService.convertFormat(
        bytes: testImageBytes,
        targetFormat: ImageFormatType.gif,
      );
      expect(gifResult.formatName, 'GIF');
      expect(gifResult.width, 800);
      expect(gifResult.height, 600);
    });

    test('cropImage correctly extracts region and handles 90° rotation', () async {
      // Crop 400x300 from center
      final cropped = await ImageService.cropImage(
        bytes: testImageBytes,
        x: 200,
        y: 150,
        width: 400,
        height: 300,
        rotationAngle: 0,
      );
      expect(cropped.width, 400);
      expect(cropped.height, 300);

      // Crop with 90° rotation: image is rotated, then cropped to specified region
      final rotated = await ImageService.cropImage(
        bytes: testImageBytes,
        x: 100,
        y: 100,
        width: 400,
        height: 300,
        rotationAngle: 90,
      );
      expect(rotated.width, 400);
      expect(rotated.height, 300);
    });

    test('applyWatermark correctly applies anti-fraud watermarks in all styles', () async {
      // 1. Tiled style
      final tiled = await ImageService.applyWatermark(
        bytes: testImageBytes,
        watermarkText: 'COPIE CONFORME',
        style: WatermarkStyle.tiled,
        opacity: 0.40,
        colorValue: 0xFFD32F2F,
      );
      expect(tiled.bytes.isNotEmpty, isTrue);
      expect(tiled.width, 800);
      expect(tiled.height, 600);

      // 2. Banner style
      final banner = await ImageService.applyWatermark(
        bytes: testImageBytes,
        watermarkText: 'DOSSIER LOCATION',
        style: WatermarkStyle.banner,
        opacity: 0.60,
        colorValue: 0xFF00E5FF,
      );
      expect(banner.bytes.isNotEmpty, isTrue);
      expect(banner.width, 800);
      expect(banner.height, 600);

      // 3. Stamp style
      final stamp = await ImageService.applyWatermark(
        bytes: testImageBytes,
        watermarkText: 'USAGE BANCAIRE',
        style: WatermarkStyle.stamp,
        opacity: 0.50,
        colorValue: 0xFFFFFFFF,
      );
      expect(stamp.bytes.isNotEmpty, isTrue);
      expect(stamp.width, 800);
      expect(stamp.height, 600);
    });
  });
}
