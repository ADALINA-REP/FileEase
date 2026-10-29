import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/result_bottom_sheet.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/image_service.dart';

class ImageResizeScreen extends StatefulWidget {
  final SelectedFileItem? initialFile;

  const ImageResizeScreen({super.key, this.initialFile});

  @override
  State<ImageResizeScreen> createState() => _ImageResizeScreenState();
}

class _ImageResizeScreenState extends State<ImageResizeScreen> {
  SelectedFileItem? _selectedFile;
  ImageMetadataInfo? _metadata;
  bool _isProcessing = false;

  // 0 = Pixels, 1 = Percentage, 2 = Presets
  int _resizeMode = 0;

  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  bool _keepAspectRatio = true;
  double _aspectRatio = 1.0;

  double _scalePercent = 50.0;
  ImageFormatType _targetFormat = ImageFormatType.jpg;
  double _quality = 95.0;

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Passport (35×45mm)', 'w': 413, 'h': 531},
    {'name': 'Square Avatar', 'w': 500, 'h': 500},
    {'name': 'Full HD', 'w': 1920, 'h': 1080},
    {'name': 'Web & Blog', 'w': 1200, 'h': 800},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
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
    });

    final meta = await ImageService.extractMetadata(file.bytes);

    if (mounted) {
      setState(() {
        _metadata = meta;
        if (meta != null && meta.width > 0 && meta.height > 0) {
          _aspectRatio = meta.width / meta.height;
          _widthController.text = meta.width.toString();
          _heightController.text = meta.height.toString();
        }
      });
    }
  }

  void _onWidthChanged(String val) {
    if (!_keepAspectRatio) return;
    final w = int.tryParse(val);
    if (w != null && _aspectRatio > 0) {
      final h = (w / _aspectRatio).round();
      _heightController.text = h.toString();
    }
  }

  void _onHeightChanged(String val) {
    if (!_keepAspectRatio) return;
    final h = int.tryParse(val);
    if (h != null && _aspectRatio > 0) {
      final w = (h * _aspectRatio).round();
      _widthController.text = w.toString();
    }
  }

  Future<void> _executeResize() async {
    if (_selectedFile == null || _isProcessing) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      ImageProcessingResult result;

      if (_resizeMode == 0) {
        // Pixels
        final w = int.tryParse(_widthController.text);
        final h = int.tryParse(_heightController.text);
        result = await ImageService.resizeImage(
          bytes: _selectedFile!.bytes,
          targetWidth: w,
          targetHeight: h,
          keepAspectRatio: _keepAspectRatio,
          quality: _quality.round(),
          targetFormat: _targetFormat,
        );
      } else if (_resizeMode == 1) {
        result = await ImageService.resizeImage(
          bytes: _selectedFile!.bytes,
          scalePercentage: _scalePercent,
          quality: _quality.round(),
          targetFormat: _targetFormat,
        );
      } else {
        // Preset
        final w = int.tryParse(_widthController.text);
        final h = int.tryParse(_heightController.text);
        result = await ImageService.resizeImage(
          bytes: _selectedFile!.bytes,
          targetWidth: w,
          targetHeight: h,
          keepAspectRatio: false,
          quality: _quality.round(),
          targetFormat: _targetFormat,
        );
      }

      final baseName = _selectedFile!.name.replaceAll(
        RegExp(r'\.[a-zA-Z0-9]+$'),
        '',
      );
      final ext = _targetFormat == ImageFormatType.png ? 'png' : 'jpg';
      final outputName =
          '${baseName}_resized_${result.width}x${result.height}.$ext';

      final savedFile = await FileService.saveExportFile(
        bytes: result.bytes,
        fileName: outputName,
      );

      await HistoryService.instance.addEntry(
        toolTitle: l10n.t('tool_resize'),
        fileName: outputName,
        filePath: savedFile.path,
        originalBytes: _selectedFile!.sizeInBytes,
        resultBytes: result.sizeInBytes,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

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
        title: Text(l10n.t('resize_title')),
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
                Icons.aspect_ratio_rounded,
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
              l10n.t('tool_resize_desc'),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Image.memory(
                    _selectedFile!.bytes,
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _metadata != null
                            ? '${Formatters.formatDimensions(_metadata!.width, _metadata!.height)} • ${Formatters.formatBytes(_selectedFile!.sizeInBytes)}'
                            : '...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Resize Mode Selector
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(l10n.t('resize_pixels')),
                icon: const Icon(Icons.straighten_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text(l10n.t('resize_percent')),
                icon: const Icon(Icons.zoom_in_rounded),
              ),
              ButtonSegment(
                value: 2,
                label: Text(l10n.t('resize_presets')),
                icon: const Icon(Icons.badge_outlined),
              ),
            ],
            selected: {_resizeMode},
            onSelectionChanged: (val) {
              setState(() {
                _resizeMode = val.first;
              });
            },
          ),
          const SizedBox(height: 20),

          if (_resizeMode == 0) ...[
            // Pixels Mode
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.t('resize_width'),
                      prefixIcon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    onChanged: _onWidthChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.t('resize_height'),
                      prefixIcon: const Icon(Icons.swap_vert_rounded),
                    ),
                    onChanged: _onHeightChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              title: Text(l10n.t('keep_aspect_ratio')),
              value: _keepAspectRatio,
              onChanged: (val) {
                setState(() {
                  _keepAspectRatio = val;
                });
              },
            ),
          ] else if (_resizeMode == 1) ...[
            // Percentage Mode
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.t('resize_percent')),
                Text(
                  '${_scalePercent.round()}%',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Slider(
              value: _scalePercent,
              min: 10,
              max: 200,
              divisions: 19,
              activeColor: AppColors.primaryBlue,
              label: '${_scalePercent.round()}%',
              onChanged: (val) {
                setState(() {
                  _scalePercent = val;
                });
              },
            ),
            if (_metadata != null)
              Text(
                '${(_metadata!.width * (_scalePercent / 100)).round()} × ${(_metadata!.height * (_scalePercent / 100)).round()} px',
                style: theme.textTheme.bodyMedium,
              ),
          ] else ...[
            // Presets Mode
            Column(
              children: _presets.map((preset) {
                final isSelected =
                    _widthController.text == preset['w'].toString() &&
                    _heightController.text == preset['h'].toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    title: Text(
                      preset['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${preset['w']} × ${preset['h']} px'),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryBlue,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _widthController.text = preset['w'].toString();
                        _heightController.text = preset['h'].toString();
                        _keepAspectRatio = false;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // Export Format & Quality Controls
          Text(
            l10n.t('target_format'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ImageFormatType>(
            segments: const [
              ButtonSegment(
                value: ImageFormatType.jpg,
                label: Text('JPG'),
                icon: Icon(Icons.photo_outlined),
              ),
              ButtonSegment(
                value: ImageFormatType.png,
                label: Text('PNG'),
                icon: Icon(Icons.high_quality_rounded),
              ),
            ],
            selected: {_targetFormat},
            onSelectionChanged: (val) {
              setState(() {
                _targetFormat = val.first;
              });
            },
          ),
          if (_targetFormat == ImageFormatType.jpg) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.t('quality_level')),
                Text(
                  '${_quality.round()}%',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _quality,
              min: 70,
              max: 100,
              divisions: 6,
              activeColor: AppColors.primaryBlue,
              label: '${_quality.round()}%',
              onChanged: (val) {
                setState(() {
                  _quality = val;
                });
              },
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isProcessing ? null : _executeResize,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.t('processing')),
                    ],
                  )
                : Text(l10n.t('resize_action')),
          ),
        ],
      ),
    );
  }
}
