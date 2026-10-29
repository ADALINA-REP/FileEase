import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/result_bottom_sheet.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/image_service.dart';
import '../../image_compress/presentation/image_compress_screen.dart';
import '../../image_resize/presentation/image_resize_screen.dart';

enum CropRatioPreset { free, square, passport, landscape16_9 }

enum _CropHandle {
  none,
  center,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class ImageCropScreen extends StatefulWidget {
  final SelectedFileItem? initialFile;

  const ImageCropScreen({super.key, this.initialFile});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  SelectedFileItem? _selectedFile;
  ImageMetadataInfo? _metadata;
  bool _isProcessing = false;

  CropRatioPreset _selectedRatio = CropRatioPreset.free;
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _flipH = false;

  // Normalized crop bounds relative to the rotated/flipped image [0.0 - 1.0]
  double _cropLeft = 0.05;
  double _cropTop = 0.05;
  double _cropWidth = 0.90;
  double _cropHeight = 0.90;

  _CropHandle _activeHandle = _CropHandle.none;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  Future<void> _pickImage() async {
    final picked = await FileService.pickSingleImage();
    if (picked != null) {
      _loadFile(picked);
    }
  }

  Future<void> _loadFile(SelectedFileItem file) async {
    setState(() {
      _selectedFile = file;
      _rotationAngle = 0;
      _flipH = false;
      _cropLeft = 0.05;
      _cropTop = 0.05;
      _cropWidth = 0.90;
      _cropHeight = 0.90;
    });

    final meta = await ImageService.extractMetadata(file.bytes);
    if (mounted) {
      setState(() {
        _metadata = meta;
      });
    }
  }

  int get _effectiveWidth {
    if (_metadata == null) return 100;
    return (_rotationAngle == 90 || _rotationAngle == 270)
        ? _metadata!.height
        : _metadata!.width;
  }

  int get _effectiveHeight {
    if (_metadata == null) return 100;
    return (_rotationAngle == 90 || _rotationAngle == 270)
        ? _metadata!.width
        : _metadata!.height;
  }

  double? get _targetAspectRatio {
    switch (_selectedRatio) {
      case CropRatioPreset.free:
        return null;
      case CropRatioPreset.square:
        return 1.0;
      case CropRatioPreset.passport:
        return 3.0 / 4.0;
      case CropRatioPreset.landscape16_9:
        return 16.0 / 9.0;
    }
  }

  void _applyRatioPreset(CropRatioPreset preset) {
    setState(() {
      _selectedRatio = preset;
      if (_metadata == null) return;

      if (preset == CropRatioPreset.free) {
        return; // Keep current rect in Free mode
      }

      final targetRatio = _targetAspectRatio!;
      final imgRatio = _effectiveWidth / _effectiveHeight;

      if (imgRatio > targetRatio) {
        final newNormW = (targetRatio / imgRatio).clamp(0.2, 0.95);
        _cropWidth = newNormW;
        _cropHeight = 0.90;
        _cropLeft = (1.0 - newNormW) / 2;
        _cropTop = 0.05;
      } else {
        final newNormH = (imgRatio / targetRatio).clamp(0.2, 0.95);
        _cropWidth = 0.90;
        _cropHeight = newNormH;
        _cropLeft = 0.05;
        _cropTop = (1.0 - newNormH) / 2;
      }
    });
  }

  void _showCustomDimensionsDialog() {
    if (_metadata == null) return;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final curW = (_cropWidth * _effectiveWidth).round();
    final curH = (_cropHeight * _effectiveHeight).round();

    final widthController = TextEditingController(text: '$curW');
    final heightController = TextEditingController(text: '$curH');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.straighten_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                l10n.t('custom_dimensions'),
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Max: $_effectiveWidth × $_effectiveHeight px',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.t('resize_width'),
                          prefixIcon: const Icon(Icons.swap_horiz_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.t('resize_height'),
                          prefixIcon: const Icon(Icons.swap_vert_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Quick preset buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: Text(l10n.t('crop_full')),
                      onPressed: () {
                        widthController.text = '$_effectiveWidth';
                        heightController.text = '$_effectiveHeight';
                      },
                    ),
                    ActionChip(
                      label: const Text('1:1 Square'),
                      onPressed: () {
                        final side = math.min(_effectiveWidth, _effectiveHeight);
                        widthController.text = '$side';
                        heightController.text = '$side';
                      },
                    ),
                    ActionChip(
                      label: const Text('3:4 Passport'),
                      onPressed: () {
                        final maxH = (_effectiveWidth * 4 / 3).round();
                        if (maxH <= _effectiveHeight) {
                          widthController.text = '$_effectiveWidth';
                          heightController.text = '$maxH';
                        } else {
                          final maxW = (_effectiveHeight * 3 / 4).round();
                          widthController.text = '$maxW';
                          heightController.text = '$_effectiveHeight';
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            ElevatedButton(
              onPressed: () {
                final inputW = int.tryParse(widthController.text.trim()) ?? curW;
                final inputH = int.tryParse(heightController.text.trim()) ?? curH;

                final validW = inputW.clamp(30, _effectiveWidth);
                final validH = inputH.clamp(30, _effectiveHeight);

                final normW = (validW / _effectiveWidth).clamp(0.02, 1.0);
                final normH = (validH / _effectiveHeight).clamp(0.02, 1.0);

                setState(() {
                  _cropWidth = normW;
                  _cropHeight = normH;
                  _cropLeft = ((1.0 - normW) / 2).clamp(0.0, 1.0 - normW);
                  _cropTop = ((1.0 - normH) / 2).clamp(0.0, 1.0 - normH);
                  _selectedRatio = CropRatioPreset.free;
                });

                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _onPanStart(Offset localPos, Rect imageRect) {
    if (imageRect.width <= 0 || imageRect.height <= 0) {
      _activeHandle = _CropHandle.none;
      return;
    }

    final cropRect = Rect.fromLTWH(
      imageRect.left + _cropLeft * imageRect.width,
      imageRect.top + _cropTop * imageRect.height,
      _cropWidth * imageRect.width,
      _cropHeight * imageRect.height,
    );

    // Large 44px comfortable touch target for mobile fingertips
    const touchRadius = 44.0;

    // Control point candidates: 4 corners + 4 edge midpoints
    final handles = <_CropHandle, Offset>{
      _CropHandle.topLeft: cropRect.topLeft,
      _CropHandle.topRight: cropRect.topRight,
      _CropHandle.bottomLeft: cropRect.bottomLeft,
      _CropHandle.bottomRight: cropRect.bottomRight,
      _CropHandle.top: Offset(cropRect.center.dx, cropRect.top),
      _CropHandle.bottom: Offset(cropRect.center.dx, cropRect.bottom),
      _CropHandle.left: Offset(cropRect.left, cropRect.center.dy),
      _CropHandle.right: Offset(cropRect.right, cropRect.center.dy),
    };

    _CropHandle bestHandle = _CropHandle.none;
    double minDistance = touchRadius;

    handles.forEach((handle, pos) {
      final d = (localPos - pos).distance;
      if (d < minDistance) {
        minDistance = d;
        bestHandle = handle;
      }
    });

    // If not close to a handle point, check proximity to the 4 edges
    if (bestHandle == _CropHandle.none) {
      const edgeThreshold = 32.0;
      final insideX = localPos.dx >= (cropRect.left - edgeThreshold) &&
          localPos.dx <= (cropRect.right + edgeThreshold);
      final insideY = localPos.dy >= (cropRect.top - edgeThreshold) &&
          localPos.dy <= (cropRect.bottom + edgeThreshold);

      if (insideX && (localPos.dy - cropRect.top).abs() <= edgeThreshold) {
        bestHandle = _CropHandle.top;
      } else if (insideX &&
          (localPos.dy - cropRect.bottom).abs() <= edgeThreshold) {
        bestHandle = _CropHandle.bottom;
      } else if (insideY &&
          (localPos.dx - cropRect.left).abs() <= edgeThreshold) {
        bestHandle = _CropHandle.left;
      } else if (insideY &&
          (localPos.dx - cropRect.right).abs() <= edgeThreshold) {
        bestHandle = _CropHandle.right;
      } else if (cropRect.inflate(18.0).contains(localPos)) {
        // Center drag: moves entire crop box
        bestHandle = _CropHandle.center;
      }
    }

    _activeHandle = bestHandle;
  }

  void _onPanUpdate(DragUpdateDetails details, Rect imageRect) {
    if (_activeHandle == _CropHandle.none || imageRect.width <= 0) return;

    final dx = details.delta.dx / imageRect.width;
    final dy = details.delta.dy / imageRect.height;
    // Allow resizing freely down to ~25 pixels
    final minW = (25.0 / _effectiveWidth).clamp(0.01, 0.08);
    final minH = (25.0 / _effectiveHeight).clamp(0.01, 0.08);

    setState(() {
      switch (_activeHandle) {
        case _CropHandle.center:
          _cropLeft = (_cropLeft + dx).clamp(0.0, 1.0 - _cropWidth);
          _cropTop = (_cropTop + dy).clamp(0.0, 1.0 - _cropHeight);
          break;

        case _CropHandle.topLeft:
          if (_selectedRatio == CropRatioPreset.free) {
            final newLeft =
                (_cropLeft + dx).clamp(0.0, _cropLeft + _cropWidth - minW);
            final newTop =
                (_cropTop + dy).clamp(0.0, _cropTop + _cropHeight - minH);
            _cropWidth += (_cropLeft - newLeft);
            _cropHeight += (_cropTop - newTop);
            _cropLeft = newLeft;
            _cropTop = newTop;
          } else {
            final newLeft =
                (_cropLeft + dx).clamp(0.0, _cropLeft + _cropWidth - minW);
            double newW = _cropWidth + (_cropLeft - newLeft);
            double newH = (newW * _effectiveWidth) /
                (_effectiveHeight * _targetAspectRatio!);
            double newTop = _cropTop + _cropHeight - newH;
            if (newTop < 0.0) {
              newTop = 0.0;
              newH = _cropTop + _cropHeight;
              newW = (newH * _effectiveHeight * _targetAspectRatio!) /
                  _effectiveWidth;
              final maxLeft = _cropLeft + _cropWidth - newW;
              if (maxLeft >= 0.0) {
                _cropLeft = maxLeft;
                _cropWidth = newW;
                _cropTop = newTop;
                _cropHeight = newH;
              }
            } else if (newW >= minW && newH >= minH) {
              _cropLeft = newLeft;
              _cropWidth = newW;
              _cropTop = newTop;
              _cropHeight = newH;
            }
          }
          break;

        case _CropHandle.topRight:
          if (_selectedRatio == CropRatioPreset.free) {
            final newRight =
                (_cropLeft + _cropWidth + dx).clamp(_cropLeft + minW, 1.0);
            final newTop =
                (_cropTop + dy).clamp(0.0, _cropTop + _cropHeight - minH);
            _cropWidth = newRight - _cropLeft;
            _cropHeight += (_cropTop - newTop);
            _cropTop = newTop;
          } else {
            final newRight =
                (_cropLeft + _cropWidth + dx).clamp(_cropLeft + minW, 1.0);
            double newW = newRight - _cropLeft;
            double newH = (newW * _effectiveWidth) /
                (_effectiveHeight * _targetAspectRatio!);
            double newTop = _cropTop + _cropHeight - newH;
            if (newTop < 0.0) {
              newTop = 0.0;
              newH = _cropTop + _cropHeight;
              newW = (newH * _effectiveHeight * _targetAspectRatio!) /
                  _effectiveWidth;
              if (_cropLeft + newW <= 1.0) {
                _cropWidth = newW;
                _cropTop = newTop;
                _cropHeight = newH;
              }
            } else if (newW >= minW && newH >= minH) {
              _cropWidth = newW;
              _cropTop = newTop;
              _cropHeight = newH;
            }
          }
          break;

        case _CropHandle.bottomLeft:
          if (_selectedRatio == CropRatioPreset.free) {
            final newLeft =
                (_cropLeft + dx).clamp(0.0, _cropLeft + _cropWidth - minW);
            final newBottom =
                (_cropTop + _cropHeight + dy).clamp(_cropTop + minH, 1.0);
            _cropWidth += (_cropLeft - newLeft);
            _cropHeight = newBottom - _cropTop;
            _cropLeft = newLeft;
          } else {
            final newLeft =
                (_cropLeft + dx).clamp(0.0, _cropLeft + _cropWidth - minW);
            double newW = _cropWidth + (_cropLeft - newLeft);
            double newH = (newW * _effectiveWidth) /
                (_effectiveHeight * _targetAspectRatio!);
            if (_cropTop + newH > 1.0) {
              newH = 1.0 - _cropTop;
              newW = (newH * _effectiveHeight * _targetAspectRatio!) /
                  _effectiveWidth;
              final maxLeft = _cropLeft + _cropWidth - newW;
              if (maxLeft >= 0.0) {
                _cropLeft = maxLeft;
                _cropWidth = newW;
                _cropHeight = newH;
              }
            } else if (newW >= minW && newH >= minH) {
              _cropLeft = newLeft;
              _cropWidth = newW;
              _cropHeight = newH;
            }
          }
          break;

        case _CropHandle.bottomRight:
          if (_selectedRatio == CropRatioPreset.free) {
            final newRight =
                (_cropLeft + _cropWidth + dx).clamp(_cropLeft + minW, 1.0);
            final newBottom =
                (_cropTop + _cropHeight + dy).clamp(_cropTop + minH, 1.0);
            _cropWidth = newRight - _cropLeft;
            _cropHeight = newBottom - _cropTop;
          } else {
            final newRight =
                (_cropLeft + _cropWidth + dx).clamp(_cropLeft + minW, 1.0);
            double newW = newRight - _cropLeft;
            double newH = (newW * _effectiveWidth) /
                (_effectiveHeight * _targetAspectRatio!);
            if (_cropTop + newH > 1.0) {
              newH = 1.0 - _cropTop;
              newW = (newH * _effectiveHeight * _targetAspectRatio!) /
                  _effectiveWidth;
              if (_cropLeft + newW <= 1.0) {
                _cropWidth = newW;
                _cropHeight = newH;
              }
            } else if (newW >= minW && newH >= minH) {
              _cropWidth = newW;
              _cropHeight = newH;
            }
          }
          break;

        case _CropHandle.top:
          final newTop =
              (_cropTop + dy).clamp(0.0, _cropTop + _cropHeight - minH);
          _cropHeight += (_cropTop - newTop);
          _cropTop = newTop;
          if (_selectedRatio != CropRatioPreset.free) {
            _selectedRatio = CropRatioPreset.free;
          }
          break;

        case _CropHandle.bottom:
          final newBottom =
              (_cropTop + _cropHeight + dy).clamp(_cropTop + minH, 1.0);
          _cropHeight = newBottom - _cropTop;
          if (_selectedRatio != CropRatioPreset.free) {
            _selectedRatio = CropRatioPreset.free;
          }
          break;

        case _CropHandle.left:
          final newLeft =
              (_cropLeft + dx).clamp(0.0, _cropLeft + _cropWidth - minW);
          _cropWidth += (_cropLeft - newLeft);
          _cropLeft = newLeft;
          if (_selectedRatio != CropRatioPreset.free) {
            _selectedRatio = CropRatioPreset.free;
          }
          break;

        case _CropHandle.right:
          final newRight =
              (_cropLeft + _cropWidth + dx).clamp(_cropLeft + minW, 1.0);
          _cropWidth = newRight - _cropLeft;
          if (_selectedRatio != CropRatioPreset.free) {
            _selectedRatio = CropRatioPreset.free;
          }
          break;

        case _CropHandle.none:
          break;
      }
    });
  }

  Future<void> _executeCrop({
    bool thenGoToResize = false,
    bool thenGoToCompress = false,
  }) async {
    if (_selectedFile == null || _isProcessing || _metadata == null) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      final pixelX = (_cropLeft * _effectiveWidth).round();
      final pixelY = (_cropTop * _effectiveHeight).round();
      final pixelW = (_cropWidth * _effectiveWidth).round();
      final pixelH = (_cropHeight * _effectiveHeight).round();

      final result = await ImageService.cropImage(
        bytes: _selectedFile!.bytes,
        x: pixelX,
        y: pixelY,
        width: pixelW,
        height: pixelH,
        rotationAngle: _rotationAngle,
        flipH: _flipH,
        quality: 95,
      );

      final baseName = _selectedFile!.name.replaceAll(
        RegExp(r'\.[a-zA-Z0-9]+$'),
        '',
      );
      final outputName =
          '${baseName}_cropped_${result.width}x${result.height}.jpg';

      final savedFile = await FileService.saveExportFile(
        bytes: result.bytes,
        fileName: outputName,
      );

      await HistoryService.instance.addEntry(
        toolTitle: l10n.t('tool_crop'),
        fileName: outputName,
        filePath: savedFile.path,
        originalBytes: _selectedFile!.sizeInBytes,
        resultBytes: result.sizeInBytes,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        final processedItem = SelectedFileItem(
          path: savedFile.path,
          name: outputName,
          sizeInBytes: result.sizeInBytes,
          bytes: result.bytes,
        );

        if (thenGoToResize) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ImageResizeScreen(initialFile: processedItem),
            ),
          );
        } else if (thenGoToCompress) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ImageCompressScreen(initialFile: processedItem),
            ),
          );
        } else {
          await ResultBottomSheet.show(
            context: context,
            title: l10n.t('success_title'),
            fileName: outputName,
            file: savedFile,
            originalBytes: _selectedFile!.sizeInBytes,
            resultBytes: result.sizeInBytes,
            extraInfo: '${result.width} × ${result.height} px',
            rawInputBytes: _selectedFile!.bytes,
            rawResultBytes: result.bytes,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('tool_crop')),
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n.t('choose_image'),
              onPressed: _isProcessing ? null : _pickImage,
            ),
        ],
      ),
      body: _selectedFile == null
          ? _buildEmptyPicker(context)
          : _buildWorkspace(context),
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
    );
  }

  Widget _buildEmptyPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.skyLight.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.crop_rounded,
                size: 64,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.t('select_photo_prompt'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('tool_crop_desc'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(l10n.t('choose_image')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final currentPixelW = (_cropWidth * _effectiveWidth).round();
    final currentPixelH = (_cropHeight * _effectiveHeight).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Measurements Badge (Interactive with edit hint)
          Center(
            child: InkWell(
              onTap: _showCustomDimensionsDialog,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.nightBlue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.cyanAccent.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.straighten_rounded,
                      color: AppColors.cyanAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentPixelW × $currentPixelH px',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit_rounded,
                      color: AppColors.cyanAccent,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Interactive Touch Crop Area
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 380,
              color: Colors.black,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final containerWidth = constraints.maxWidth;
                  final containerHeight = constraints.maxHeight;

                  final imgAspect = _effectiveWidth / _effectiveHeight;
                  final containerAspect = containerWidth / containerHeight;

                  double renderW, renderH, renderX, renderY;
                  if (containerAspect > imgAspect) {
                    renderH = containerHeight;
                    renderW = containerHeight * imgAspect;
                    renderX = (containerWidth - renderW) / 2;
                    renderY = 0.0;
                  } else {
                    renderW = containerWidth;
                    renderH = containerWidth / imgAspect;
                    renderX = 0.0;
                    renderY = (containerHeight - renderH) / 2;
                  }

                  final imageRect =
                      Rect.fromLTWH(renderX, renderY, renderW, renderH);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) =>
                        _onPanStart(details.localPosition, imageRect),
                    onPanUpdate: (details) =>
                        _onPanUpdate(details, imageRect),
                    onPanEnd: (_) => _activeHandle = _CropHandle.none,
                    onPanCancel: () => _activeHandle = _CropHandle.none,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Displayed Image precisely fitted within imageRect
                        Positioned.fromRect(
                          rect: imageRect,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(_rotationAngle * math.pi / 180)
                              ..scaleByDouble(
                                  _flipH ? -1.0 : 1.0, 1.0, 1.0, 1.0),
                            child: Image.memory(
                              _selectedFile!.bytes,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),

                        // Interactive Crop Mask & Handles Painter
                        CustomPaint(
                          painter: _InteractiveCropPainter(
                            imageRect: imageRect,
                            cropLeft: _cropLeft,
                            cropTop: _cropTop,
                            cropWidth: _cropWidth,
                            cropHeight: _cropHeight,
                            isFreeMode: _selectedRatio == CropRatioPreset.free,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick guide hint for user
          Center(
            child: Text(
              _selectedRatio == CropRatioPreset.free
                  ? 'Faites glisser le cadre ou étirez les angles et bords'
                  : 'Faites glisser pour déplacer ou étirez les coins',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Frame Sizing & Alignment Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cropLeft = ((1.0 - _cropWidth) / 2)
                        .clamp(0.0, 1.0 - _cropWidth);
                    _cropTop = ((1.0 - _cropHeight) / 2)
                        .clamp(0.0, 1.0 - _cropHeight);
                  });
                },
                icon: const Icon(Icons.filter_center_focus_rounded, size: 16),
                label: Text(l10n.t('crop_center')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cropLeft = 0.0;
                    _cropTop = 0.0;
                    _cropWidth = 1.0;
                    _cropHeight = 1.0;
                    _selectedRatio = CropRatioPreset.free;
                  });
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: Text(l10n.t('crop_full')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showCustomDimensionsDialog,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(l10n.t('custom_dimensions')),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Rotation & Mirror Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _rotationAngle = (_rotationAngle + 90) % 360;
                    // Reset crop to full
                    _cropLeft = 0.05;
                    _cropTop = 0.05;
                    _cropWidth = 0.90;
                    _cropHeight = 0.90;
                  });
                },
                icon: const Icon(Icons.rotate_right_rounded, size: 18),
                label: Text(l10n.t('rotate_90')),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _flipH = !_flipH;
                  });
                },
                icon: const Icon(Icons.flip_rounded, size: 18),
                label: Text(l10n.t('mirror')),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ratio Presets Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRatioChip(l10n.t('crop_free'), CropRatioPreset.free),
                const SizedBox(width: 8),
                _buildRatioChip(
                    l10n.t('crop_passport'), CropRatioPreset.passport),
                const SizedBox(width: 8),
                _buildRatioChip(l10n.t('crop_square'), CropRatioPreset.square),
                const SizedBox(width: 8),
                _buildRatioChip(
                    l10n.t('crop_landscape'), CropRatioPreset.landscape16_9),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Action
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _executeCrop(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.crop_rounded),
            label: Text(
              _isProcessing ? l10n.t('processing') : l10n.t('crop_action'),
            ),
          ),
          const SizedBox(height: 10),

          // Direct Workflow Next-Step Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _executeCrop(thenGoToResize: true),
                  icon: const Icon(Icons.aspect_ratio_rounded, size: 18),
                  label: Text(l10n.t('next_resize')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _executeCrop(thenGoToCompress: true),
                  icon: const Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: Colors.amber,
                  ),
                  label: Text(l10n.t('next_compress')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioChip(String label, CropRatioPreset preset) {
    final isSelected = _selectedRatio == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => _applyRatioPreset(preset),
    );
  }
}

class _InteractiveCropPainter extends CustomPainter {
  final Rect imageRect;
  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;
  final bool isFreeMode;

  _InteractiveCropPainter({
    required this.imageRect,
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
    required this.isFreeMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cropPixelRect = Rect.fromLTWH(
      imageRect.left + cropLeft * imageRect.width,
      imageRect.top + cropTop * imageRect.height,
      cropWidth * imageRect.width,
      cropHeight * imageRect.height,
    );

    // 1. Dark overlay outside the crop rect
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropPixelRect)
      ..fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = Colors.black.withAlpha(160)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // 2. White border around crop rect
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(cropPixelRect, borderPaint);

    // 3. Rule of Thirds Grid Lines
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final thirdW = cropPixelRect.width / 3;
    final thirdH = cropPixelRect.height / 3;

    canvas.drawLine(
      Offset(cropPixelRect.left + thirdW, cropPixelRect.top),
      Offset(cropPixelRect.left + thirdW, cropPixelRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left + 2 * thirdW, cropPixelRect.top),
      Offset(cropPixelRect.left + 2 * thirdW, cropPixelRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left, cropPixelRect.top + thirdH),
      Offset(cropPixelRect.right, cropPixelRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left, cropPixelRect.top + 2 * thirdH),
      Offset(cropPixelRect.right, cropPixelRect.top + 2 * thirdH),
      gridPaint,
    );

    // 4. Prominent L-shaped Corner Caps with Cyan Accent
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.square;

    final cornerAccent = Paint()
      ..color = AppColors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    const cornerLength = 24.0;

    void drawCorner(Offset origin, Offset dx, Offset dy) {
      canvas.drawLine(origin, origin + dx, cornerPaint);
      canvas.drawLine(origin, origin + dy, cornerPaint);
      canvas.drawLine(origin, origin + (dx * 0.7), cornerAccent);
      canvas.drawLine(origin, origin + (dy * 0.7), cornerAccent);
    }

    drawCorner(cropPixelRect.topLeft, const Offset(cornerLength, 0),
        const Offset(0, cornerLength));
    drawCorner(cropPixelRect.topRight, const Offset(-cornerLength, 0),
        const Offset(0, cornerLength));
    drawCorner(cropPixelRect.bottomLeft, const Offset(cornerLength, 0),
        const Offset(0, -cornerLength));
    drawCorner(cropPixelRect.bottomRight, const Offset(-cornerLength, 0),
        const Offset(0, -cornerLength));

    // 5. Distinct Edge Pills for easy dragging in width & height
    final pillBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pillBorderPaint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const pillLong = 32.0;
    const pillShort = 7.0;

    // Top pill
    final topPill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cropPixelRect.center.dx, cropPixelRect.top),
        width: pillLong,
        height: pillShort,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(topPill, pillBgPaint);
    canvas.drawRRect(topPill, pillBorderPaint);

    // Bottom pill
    final bottomPill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cropPixelRect.center.dx, cropPixelRect.bottom),
        width: pillLong,
        height: pillShort,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(bottomPill, pillBgPaint);
    canvas.drawRRect(bottomPill, pillBorderPaint);

    // Left pill
    final leftPill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cropPixelRect.left, cropPixelRect.center.dy),
        width: pillShort,
        height: pillLong,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(leftPill, pillBgPaint);
    canvas.drawRRect(leftPill, pillBorderPaint);

    // Right pill
    final rightPill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cropPixelRect.right, cropPixelRect.center.dy),
        width: pillShort,
        height: pillLong,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(rightPill, pillBgPaint);
    canvas.drawRRect(rightPill, pillBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _InteractiveCropPainter oldDelegate) {
    return oldDelegate.cropLeft != cropLeft ||
        oldDelegate.cropTop != cropTop ||
        oldDelegate.cropWidth != cropWidth ||
        oldDelegate.cropHeight != cropHeight ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.isFreeMode != isFreeMode;
  }
}
