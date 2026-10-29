import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum ImageFormatType { jpg, png, bmp, gif, ico }
enum WatermarkStyle { tiled, banner, stamp }

class ImageProcessingResult {
  final Uint8List bytes;
  final int width;
  final int height;
  final int sizeInBytes;
  final String formatName;
  final int appliedQuality;

  const ImageProcessingResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.sizeInBytes,
    required this.formatName,
    required this.appliedQuality,
  });
}

class ImageMetadataInfo {
  final int width;
  final int height;
  final int sizeInBytes;
  final String format;

  const ImageMetadataInfo({
    required this.width,
    required this.height,
    required this.sizeInBytes,
    required this.format,
  });
}

class ImageService {
  /// Extract quick metadata without full render
  static Future<ImageMetadataInfo?> extractMetadata(Uint8List bytes) async {
    return compute(_extractMetadataInternal, bytes);
  }

  static ImageMetadataInfo? _extractMetadataInternal(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return ImageMetadataInfo(
      width: decoded.width,
      height: decoded.height,
      sizeInBytes: bytes.lengthInBytes,
      format: decoded.hasAlpha ? 'PNG/Alpha' : 'JPEG/RGB',
    );
  }

  /// Compress image by quality percentage (1 - 100)
  static Future<ImageProcessingResult> compressByQuality({
    required Uint8List bytes,
    required int quality,
    ImageFormatType targetFormat = ImageFormatType.jpg,
  }) async {
    return compute(_compressByQualityInternal, {
      'bytes': bytes,
      'quality': quality.clamp(5, 100),
      'format': targetFormat.name,
    });
  }

  static ImageProcessingResult _compressByQualityInternal(
    Map<String, dynamic> params,
  ) {
    final bytes = params['bytes'] as Uint8List;
    final quality = params['quality'] as int;
    final formatStr = params['format'] as String;

    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image sélectionnée.');
    }

    // Correct EXIF orientation so phone camera pictures are not rotated sideways
    image = img.bakeOrientation(image);

    Uint8List encoded;
    String formatName;

    if (formatStr == ImageFormatType.png.name) {
      encoded = Uint8List.fromList(img.encodePng(image, level: 6));
      formatName = 'PNG';
    } else {
      // JPEG default - fill alpha background with white if source was transparent
      if (image.hasAlpha) {
        final whiteBg = img.Image(
          width: image.width,
          height: image.height,
          numChannels: 3,
        );
        img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(whiteBg, image);
        image = whiteBg;
      }
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      formatName = 'JPEG';
    }

    return ImageProcessingResult(
      bytes: encoded,
      width: image.width,
      height: image.height,
      sizeInBytes: encoded.lengthInBytes,
      formatName: formatName,
      appliedQuality: quality,
    );
  }

  /// Compress image targeting an exact byte size (e.g. 200 KB = 204800 bytes)
  /// Uses binary search on JPEG quality and smart scaling fallback if necessary.
  static Future<ImageProcessingResult> compressToTargetSize({
    required Uint8List bytes,
    required int targetSizeInBytes,
  }) async {
    return compute(_compressToTargetSizeInternal, {
      'bytes': bytes,
      'targetBytes': targetSizeInBytes,
    });
  }

  static ImageProcessingResult _compressToTargetSizeInternal(
    Map<String, dynamic> params,
  ) {
    final bytes = params['bytes'] as Uint8List;
    final targetBytes = params['targetBytes'] as int;

    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image.');
    }
    image = img.bakeOrientation(image);

    // If already smaller than target, return at high quality
    if (bytes.lengthInBytes <= targetBytes) {
      final highRes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
      if (highRes.lengthInBytes <= targetBytes) {
        return ImageProcessingResult(
          bytes: highRes,
          width: image.width,
          height: image.height,
          sizeInBytes: highRes.lengthInBytes,
          formatName: 'JPEG',
          appliedQuality: 92,
        );
      }
    }

    // Binary search on quality factor (10 to 95)
    int lowQ = 10;
    int highQ = 92;
    int bestQ = 80;
    Uint8List? bestBytes;
    var currentImg = image;

    for (int iter = 0; iter < 6; iter++) {
      int midQ = (lowQ + highQ) ~/ 2;
      final encoded = Uint8List.fromList(
        img.encodeJpg(currentImg, quality: midQ),
      );

      if (encoded.lengthInBytes <= targetBytes) {
        bestQ = midQ;
        bestBytes = encoded;
        lowQ = midQ + 1; // Try higher quality
      } else {
        highQ = midQ - 1; // Need lower quality
      }
    }

    // If even low quality (10) is still larger than target (e.g. huge 48MP photo targeting 50KB),
    // downscale dimensions progressively while preserving aspect ratio.
    if (bestBytes == null || bestBytes.lengthInBytes > targetBytes) {
      double scale = 0.85;
      while (scale >= 0.25) {
        final scaled = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );

        final testEncoded = Uint8List.fromList(
          img.encodeJpg(scaled, quality: 75),
        );
        if (testEncoded.lengthInBytes <= targetBytes) {
          return ImageProcessingResult(
            bytes: testEncoded,
            width: scaled.width,
            height: scaled.height,
            sizeInBytes: testEncoded.lengthInBytes,
            formatName: 'JPEG',
            appliedQuality: 75,
          );
        }
        scale -= 0.15;
      }

      // Final fallback at smallest reasonable scale
      final minScaled = img.copyResize(
        image,
        width: (image.width * 0.3).round(),
        height: (image.height * 0.3).round(),
      );
      final finalEncoded = Uint8List.fromList(
        img.encodeJpg(minScaled, quality: 50),
      );
      return ImageProcessingResult(
        bytes: finalEncoded,
        width: minScaled.width,
        height: minScaled.height,
        sizeInBytes: finalEncoded.lengthInBytes,
        formatName: 'JPEG',
        appliedQuality: 50,
      );
    }

    return ImageProcessingResult(
      bytes: bestBytes,
      width: currentImg.width,
      height: currentImg.height,
      sizeInBytes: bestBytes.lengthInBytes,
      formatName: 'JPEG',
      appliedQuality: bestQ,
    );
  }

  /// Resize image with exact dimensions or scale percentage
  static Future<ImageProcessingResult> resizeImage({
    required Uint8List bytes,
    int? targetWidth,
    int? targetHeight,
    double? scalePercentage,
    bool keepAspectRatio = true,
    int quality = 95,
    ImageFormatType targetFormat = ImageFormatType.jpg,
  }) async {
    return compute(_resizeImageInternal, {
      'bytes': bytes,
      'width': targetWidth,
      'height': targetHeight,
      'scale': scalePercentage,
      'keepRatio': keepAspectRatio,
      'quality': quality,
      'targetFormat': targetFormat.name,
    });
  }

  static ImageProcessingResult _resizeImageInternal(
    Map<String, dynamic> params,
  ) {
    final bytes = params['bytes'] as Uint8List;
    final widthParam = params['width'] as int?;
    final heightParam = params['height'] as int?;
    final scale = params['scale'] as double?;
    final keepRatio = params['keepRatio'] as bool;
    final quality = params['quality'] as int;
    final formatStr =
        params['targetFormat'] as String? ?? ImageFormatType.jpg.name;

    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image.');
    }
    image = img.bakeOrientation(image);

    int newW = image.width;
    int newH = image.height;

    if (scale != null && scale > 0) {
      newW = (image.width * (scale / 100.0)).round().clamp(10, 8000);
      newH = (image.height * (scale / 100.0)).round().clamp(10, 8000);
    } else if (widthParam != null || heightParam != null) {
      if (keepRatio) {
        if (widthParam != null && heightParam != null) {
          // Fit inside box
          final ratioW = widthParam / image.width;
          final ratioH = heightParam / image.height;
          final finalRatio = ratioW < ratioH ? ratioW : ratioH;
          newW = (image.width * finalRatio).round();
          newH = (image.height * finalRatio).round();
        } else if (widthParam != null) {
          newW = widthParam;
          newH = ((image.height * widthParam) / image.width).round();
        } else if (heightParam != null) {
          newH = heightParam;
          newW = ((image.width * heightParam) / image.height).round();
        }
      } else {
        newW = widthParam ?? image.width;
        newH = heightParam ?? image.height;
      }
    }

    // Downscaling requires area-averaging (box filter) to avoid moire/pixelation artifacts.
    // Upscaling uses cubic interpolation for smooth edge reconstruction.
    final isDownscaling = newW < image.width || newH < image.height;
    final interpolation = isDownscaling
        ? img.Interpolation.average
        : img.Interpolation.cubic;

    final resized = img.copyResize(
      image,
      width: newW,
      height: newH,
      interpolation: interpolation,
    );

    Uint8List encoded;
    String formatName;

    if (formatStr == ImageFormatType.png.name) {
      encoded = Uint8List.fromList(img.encodePng(resized, level: 6));
      formatName = 'PNG';
    } else {
      encoded = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality.clamp(1, 100)),
      );
      formatName = 'JPEG';
    }

    return ImageProcessingResult(
      bytes: encoded,
      width: resized.width,
      height: resized.height,
      sizeInBytes: encoded.lengthInBytes,
      formatName: formatName,
      appliedQuality: quality,
    );
  }

  /// Convert image between formats (JPG, PNG, WebP)
  static Future<ImageProcessingResult> convertFormat({
    required Uint8List bytes,
    required ImageFormatType targetFormat,
    int quality = 90,
  }) async {
    return compute(_convertFormatInternal, {
      'bytes': bytes,
      'targetFormat': targetFormat.name,
      'quality': quality,
    });
  }

  static ImageProcessingResult _convertFormatInternal(
    Map<String, dynamic> params,
  ) {
    final bytes = params['bytes'] as Uint8List;
    final formatStr = params['targetFormat'] as String;
    final quality = params['quality'] as int;

    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image.');
    }
    image = img.bakeOrientation(image);

    Uint8List encoded;
    String formatName;

    if (formatStr == ImageFormatType.png.name) {
      encoded = Uint8List.fromList(img.encodePng(image, level: 6));
      formatName = 'PNG';
    } else if (formatStr == ImageFormatType.bmp.name) {
      encoded = Uint8List.fromList(img.encodeBmp(image));
      formatName = 'BMP';
    } else if (formatStr == ImageFormatType.gif.name) {
      encoded = Uint8List.fromList(img.encodeGif(image));
      formatName = 'GIF';
    } else if (formatStr == ImageFormatType.ico.name) {
      var icoImg = image;
      if (image.width > 256 || image.height > 256) {
        icoImg = img.copyResize(
          image,
          width: 256,
          height: 256,
          interpolation: img.Interpolation.average,
        );
      }
      encoded = Uint8List.fromList(img.encodeIco(icoImg));
      formatName = 'ICO';
    } else {
      if (image.hasAlpha) {
        final whiteBg = img.Image(
          width: image.width,
          height: image.height,
          numChannels: 3,
        );
        img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(whiteBg, image);
        image = whiteBg;
      }
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      formatName = 'JPEG';
    }

    return ImageProcessingResult(
      bytes: encoded,
      width: image.width,
      height: image.height,
      sizeInBytes: encoded.lengthInBytes,
      formatName: formatName,
      appliedQuality: quality,
    );
  }

  /// Crop image with optional rotation (0, 90, 180, 270) and horizontal flip
  static Future<ImageProcessingResult> cropImage({
    required Uint8List bytes,
    required int x,
    required int y,
    required int width,
    required int height,
    int rotationAngle = 0,
    bool flipH = false,
    int quality = 95,
  }) async {
    return compute(_cropImageInternal, {
      'bytes': bytes,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotationAngle': rotationAngle,
      'flipH': flipH,
      'quality': quality,
    });
  }

  static ImageProcessingResult _cropImageInternal(Map<String, dynamic> params) {
    final bytes = params['bytes'] as Uint8List;
    final x = params['x'] as int;
    final y = params['y'] as int;
    final width = params['width'] as int;
    final height = params['height'] as int;
    final rotationAngle = params['rotationAngle'] as int;
    final flipH = params['flipH'] as bool;
    final quality = params['quality'] as int;

    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image.');
    }
    image = img.bakeOrientation(image);

    // Apply rotation if any
    if (rotationAngle != 0) {
      image = img.copyRotate(image, angle: rotationAngle);
    }

    // Apply horizontal flip if requested
    if (flipH) {
      image = img.flipHorizontal(image);
    }

    // Clamp crop bounds to image geometry
    final clampedX = x.clamp(0, image.width - 1);
    final clampedY = y.clamp(0, image.height - 1);
    final clampedW = width.clamp(1, image.width - clampedX);
    final clampedH = height.clamp(1, image.height - clampedY);

    final cropped = img.copyCrop(
      image,
      x: clampedX,
      y: clampedY,
      width: clampedW,
      height: clampedH,
    );

    final encoded = Uint8List.fromList(
      img.encodeJpg(cropped, quality: quality.clamp(1, 100)),
    );

    return ImageProcessingResult(
      bytes: encoded,
      width: cropped.width,
      height: cropped.height,
      sizeInBytes: encoded.lengthInBytes,
      formatName: 'JPEG',
      appliedQuality: quality,
    );
  }

  /// Applies an anti-fraud security watermark on image with selectable style, opacity and color
  static Future<ImageProcessingResult> applyWatermark({
    required Uint8List bytes,
    required String watermarkText,
    WatermarkStyle style = WatermarkStyle.tiled,
    double opacity = 0.50,
    int colorValue = 0xFFD32F2F, // Security Red default
    int fontSize = 48,
    double customX = 0.5,
    double customY = 0.5,
    int quality = 95,
  }) async {
    return compute(_applyWatermarkInternal, {
      'bytes': bytes,
      'text': watermarkText,
      'style': style.name,
      'opacity': opacity,
      'colorValue': colorValue,
      'fontSize': fontSize,
      'customX': customX,
      'customY': customY,
      'quality': quality,
    });
  }

  static ImageProcessingResult _applyWatermarkInternal(
    Map<String, dynamic> params,
  ) {
    final bytes = params['bytes'] as Uint8List;
    final text = params['text'] as String;
    final styleStr = params['style'] as String;
    final opacity = (params['opacity'] as num).toDouble();
    final colorValue = params['colorValue'] as int;
    final fontSize = params['fontSize'] as int;
    final customX = (params['customX'] as num).toDouble();
    final customY = (params['customY'] as num).toDouble();
    final quality = params['quality'] as int;

    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Impossible de décoder l\'image.');
    }
    image = img.bakeOrientation(image);

    final safeText = text.isEmpty ? 'COPIE CONFORME' : text;
    final font = fontSize >= 48 ? img.arial48 : img.arial24;

    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    final alpha = (opacity * 255).round().clamp(10, 255);
    final textColor = img.ColorRgba8(r, g, b, alpha);

    if (styleStr == WatermarkStyle.tiled.name) {
      // 1. Tiled / Staggered Grid anti-fraud pattern across entire document with guaranteed NO overlap
      final approxCharWidth = (font.size * 0.58).round().clamp(8, 40);
      final textWidth = safeText.length * approxCharWidth;
      final textHeight = font.lineHeight;

      // Horizontal spacing: full text width plus guaranteed padding
      final gapX = (image.width * 0.12).round().clamp(60, 350);
      final stepX = textWidth + gapX;

      // Vertical spacing: at least 3.2x font height so successive rows have ample space
      final lineSpacing = (textHeight * 3.2)
          .round()
          .clamp(64, (image.height / 3).round().clamp(64, 400));

      final startY = (lineSpacing * 0.5).round();
      int rowIndex = 0;
      for (int y = startY; y < image.height; y += lineSpacing) {
        final startX = (rowIndex % 2 == 0) ? 20 : (20 - (stepX ~/ 2));
        for (int x = startX; x < image.width + stepX; x += stepX) {
          img.drawString(
            image,
            safeText,
            font: font,
            x: x,
            y: y,
            color: textColor,
          );
        }
        rowIndex++;
      }
    } else if (styleStr == WatermarkStyle.banner.name) {
      // 2. Translucent Diagonal / Central Security Banner
      final bannerH = (font.lineHeight * 2.2).round();
      final bannerY = (image.height - bannerH) ~/ 2;
      final bannerBgColor = img.ColorRgba8(r, g, b, (alpha * 0.4).round());

      img.fillRect(
        image,
        x1: 0,
        y1: bannerY,
        x2: image.width,
        y2: bannerY + bannerH,
        color: bannerBgColor,
      );

      final textX = (image.width - (safeText.length * font.size * 0.55).round()) ~/ 2;
      final textY = bannerY + (bannerH - font.lineHeight) ~/ 2;

      img.drawString(
        image,
        safeText,
        font: font,
        x: textX.clamp(20, image.width - 100),
        y: textY,
        color: textColor,
      );
    } else {
      // 3. Stamp / Free Placement
      final posX = (customX * image.width - (safeText.length * font.size * 0.25)).round();
      final posY = (customY * image.height - (font.lineHeight / 2)).round();

      img.drawString(
        image,
        safeText,
        font: font,
        x: posX.clamp(10, image.width - 50),
        y: posY.clamp(10, image.height - 50),
        color: textColor,
      );
    }

    final encoded = Uint8List.fromList(
      img.encodeJpg(image, quality: quality.clamp(1, 100)),
    );

    return ImageProcessingResult(
      bytes: encoded,
      width: image.width,
      height: image.height,
      sizeInBytes: encoded.lengthInBytes,
      formatName: 'JPEG',
      appliedQuality: quality,
    );
  }
}
