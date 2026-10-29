import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/result_bottom_sheet.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/image_service.dart';

class ImageCompressScreen extends StatefulWidget {
  final SelectedFileItem? initialFile;

  const ImageCompressScreen({super.key, this.initialFile});

  @override
  State<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _ImageCompressScreenState extends State<ImageCompressScreen> {
  SelectedFileItem? _selectedFile;
  ImageMetadataInfo? _metadata;
  bool _isProcessing = false;

  // Compression mode: 0 = Target Size in KB, 1 = Manual Quality %
  int _compressionMode = 0;

  // Target size options (in KB)
  final List<int> _targetPresets = [50, 100, 200, 500, 1024];
  int _selectedTargetKb = 200;
  final TextEditingController _customKbController = TextEditingController();

  // Manual quality slider
  double _manualQuality = 75;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _customKbController.dispose();
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
      });
    }
  }

  Future<void> _executeCompression() async {
    if (_selectedFile == null || _isProcessing) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      ImageProcessingResult result;

      if (_compressionMode == 0) {
        // Target size in bytes
        final targetBytes = _selectedTargetKb * 1024;
        result = await ImageService.compressToTargetSize(
          bytes: _selectedFile!.bytes,
          targetSizeInBytes: targetBytes,
        );
      } else {
        // Manual quality
        result = await ImageService.compressByQuality(
          bytes: _selectedFile!.bytes,
          quality: _manualQuality.round(),
        );
      }

      // Generate output filename
      final baseName = _selectedFile!.name.replaceAll(
        RegExp(r'\.[a-zA-Z0-9]+$'),
        '',
      );
      final ext = result.formatName.toLowerCase() == 'png' ? 'png' : 'jpg';
      final outputName = '${baseName}_compressed_$ext';

      final savedFile = await FileService.saveExportFile(
        bytes: result.bytes,
        fileName: outputName,
      );

      // Save to local history
      await HistoryService.instance.addEntry(
        toolTitle: l10n.t('compress_photo'),
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
              '${result.appliedQuality}% • ${result.width}×${result.height} px',
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
        title: Text(l10n.t('compress_photo')),
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
                Icons.photo_library_outlined,
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
              l10n.t('hero_compress_desc'),
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
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Preview Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.memory(
                    _selectedFile!.bytes,
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _metadata != null
                                  ? '${Formatters.formatDimensions(_metadata!.width, _metadata!.height)} • ${_metadata!.format}'
                                  : '...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          Formatters.formatBytes(_selectedFile!.sizeInBytes),
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Compression Mode Selector
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(l10n.t('target_size_kb')),
                icon: const Icon(Icons.tune_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text(l10n.t('quality_percent')),
                icon: const Icon(Icons.percent_rounded),
              ),
            ],
            selected: {_compressionMode},
            onSelectionChanged: (newSelection) {
              setState(() {
                _compressionMode = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 20),

          // Mode 0: Target Size Preset Chips
          if (_compressionMode == 0) ...[
            Text(
              l10n.t('target_size_label'),
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _targetPresets.map((kb) {
                final isSelected = _selectedTargetKb == kb;
                return ChoiceChip(
                  label: Text('$kb KB'),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTargetKb = kb;
                        _customKbController.clear();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customKbController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.t('custom_kb_hint'),
                hintText: '150',
                suffixText: 'KB',
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null && parsed > 5) {
                  setState(() {
                    _selectedTargetKb = parsed;
                  });
                }
              },
            ),
          ] else ...[
            // Mode 1: Quality slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.t('quality_level'),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  '${_manualQuality.round()}%',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Slider(
              value: _manualQuality,
              min: 10,
              max: 95,
              divisions: 17,
              activeColor: AppColors.primaryBlue,
              label: '${_manualQuality.round()}%',
              onChanged: (val) {
                setState(() {
                  _manualQuality = val;
                });
              },
            ),
          ],

          const SizedBox(height: 28),

          // Main Action Button
          ElevatedButton(
            onPressed: _isProcessing ? null : _executeCompression,
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
                : Text(
                    _compressionMode == 0
                        ? '${l10n.t('compress_action')} $_selectedTargetKb KB'
                        : '${l10n.t('compress_action')} (${_manualQuality.round()}%)',
                  ),
          ),
        ],
      ),
    );
  }
}
