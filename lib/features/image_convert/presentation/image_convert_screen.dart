import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/result_bottom_sheet.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/image_service.dart';

class ImageConvertScreen extends StatefulWidget {
  final SelectedFileItem? initialFile;

  const ImageConvertScreen({super.key, this.initialFile});

  @override
  State<ImageConvertScreen> createState() => _ImageConvertScreenState();
}

class _ImageConvertScreenState extends State<ImageConvertScreen> {
  SelectedFileItem? _selectedFile;
  ImageMetadataInfo? _metadata;
  bool _isProcessing = false;

  ImageFormatType _targetFormat = ImageFormatType.png;
  double _quality = 90.0;

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
    });

    final meta = await ImageService.extractMetadata(file.bytes);

    if (mounted) {
      setState(() {
        _metadata = meta;
        if (file.name.toLowerCase().endsWith('.png')) {
          _targetFormat = ImageFormatType.jpg;
        } else {
          _targetFormat = ImageFormatType.png;
        }
      });
    }
  }

  Future<void> _executeConvert() async {
    if (_selectedFile == null || _isProcessing) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ImageService.convertFormat(
        bytes: _selectedFile!.bytes,
        targetFormat: _targetFormat,
        quality: _quality.round(),
      );

      final baseName = _selectedFile!.name.replaceAll(
        RegExp(r'\.[a-zA-Z0-9]+$'),
        '',
      );
      final ext = _targetFormat.name;
      final outputName = '${baseName}_converted.$ext';

      final savedFile = await FileService.saveExportFile(
        bytes: result.bytes,
        fileName: outputName,
      );

      await HistoryService.instance.addEntry(
        toolTitle: '${l10n.t('tool_convert')} ${_targetFormat.name.toUpperCase()}',
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
          extraInfo:
              '${result.formatName} • ${result.width} × ${result.height} px',
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
        title: Text(l10n.t('convert_title')),
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
                Icons.transform_rounded,
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
              l10n.t('tool_convert_desc'),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          if (_metadata != null)
                            Text(
                              '${_metadata!.width} × ${_metadata!.height} px',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        Formatters.formatBytes(_selectedFile!.sizeInBytes),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
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

          Text(
            l10n.t('target_format'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ImageFormatType>(
              segments: const [
                ButtonSegment(
                  value: ImageFormatType.jpg,
                  label: Text('JPG'),
                  icon: Icon(Icons.photo_rounded),
                ),
                ButtonSegment(
                  value: ImageFormatType.png,
                  label: Text('PNG'),
                  icon: Icon(Icons.image_outlined),
                ),
                ButtonSegment(
                  value: ImageFormatType.bmp,
                  label: Text('BMP'),
                  icon: Icon(Icons.grid_on_rounded),
                ),
                ButtonSegment(
                  value: ImageFormatType.gif,
                  label: Text('GIF'),
                  icon: Icon(Icons.gif_rounded),
                ),
                ButtonSegment(
                  value: ImageFormatType.ico,
                  label: Text('ICO'),
                  icon: Icon(Icons.web_rounded),
                ),
              ],
              selected: {_targetFormat},
              onSelectionChanged: (val) {
                setState(() {
                  _targetFormat = val.first;
                });
              },
            ),
          ),
          const SizedBox(height: 20),

          // Quality Slider (if not PNG)
          if (_targetFormat != ImageFormatType.png) ...[
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
              min: 30,
              max: 100,
              divisions: 14,
              activeColor: AppColors.primaryBlue,
              label: '${_quality.round()}%',
              onChanged: (val) {
                setState(() {
                  _quality = val;
                });
              },
            ),
          ],

          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _isProcessing ? null : _executeConvert,
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
                : Text('${l10n.t('convert_action')} (${_targetFormat.name.toUpperCase()})'),
          ),
        ],
      ),
    );
  }
}
