import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/image_service.dart';

class BatchCompressScreen extends StatefulWidget {
  const BatchCompressScreen({super.key});

  @override
  State<BatchCompressScreen> createState() => _BatchCompressScreenState();
}

class _BatchCompressScreenState extends State<BatchCompressScreen> {
  final List<SelectedFileItem> _selectedFiles = [];
  bool _isProcessing = false;
  int _processedCount = 0;

  int _selectedTargetKb = 200;
  final List<int> _targetPresets = [50, 100, 200, 500, 1024];

  final List<File> _exportedFiles = [];
  int _totalOriginalBytes = 0;
  int _totalResultBytes = 0;

  Future<void> _pickImages() async {
    final picked = await FileService.pickMultipleImages();
    if (picked.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(picked);
        _exportedFiles.clear();
      });
    }
  }

  Future<void> _executeBatch() async {
    if (_selectedFiles.isEmpty || _isProcessing) return;

    if (AdsService.adsEnabled) {
      AdsService.instance.showRewardedAd(
        onUserEarnedReward: () {
          _runBatchProcessing();
        },
      );
    } else {
      _runBatchProcessing();
    }
  }

  Future<void> _runBatchProcessing() async {
    if (!mounted || _selectedFiles.isEmpty || _isProcessing) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
      _processedCount = 0;
      _exportedFiles.clear();
      _totalOriginalBytes = 0;
      _totalResultBytes = 0;
    });

    try {
      final targetBytes = _selectedTargetKb * 1024;

      for (int i = 0; i < _selectedFiles.length; i++) {
        final item = _selectedFiles[i];
        final result = await ImageService.compressToTargetSize(
          bytes: item.bytes,
          targetSizeInBytes: targetBytes,
        );

        final baseName = item.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        final outputName = '${baseName}_batch_${_selectedTargetKb}k.jpg';

        final saved = await FileService.saveExportFile(
          bytes: result.bytes,
          fileName: outputName,
        );

        _exportedFiles.add(saved);
        _totalOriginalBytes += item.sizeInBytes;
        _totalResultBytes += result.sizeInBytes;

        await HistoryService.instance.addEntry(
          toolTitle: l10n.t('tool_batch'),
          fileName: outputName,
          filePath: saved.path,
          originalBytes: item.sizeInBytes,
          resultBytes: result.sizeInBytes,
        );

        if (mounted) {
          setState(() {
            _processedCount = i + 1;
          });
        }
      }

      AdsService.instance.notifyOperationCompleted();

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_exportedFiles.length} ${l10n.t('success_title')}',
            ),
            backgroundColor: AppColors.success,
          ),
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
        title: Text(l10n.t('tool_batch')),
        actions: [
          if (_selectedFiles.isNotEmpty && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: l10n.t('choose_images'),
              onPressed: _pickImages,
            ),
        ],
      ),
      body: _selectedFiles.isEmpty
          ? _buildEmpty(context)
          : _buildWorkspace(context),
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
    );
  }

  Widget _buildEmpty(BuildContext context) {
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
                Icons.dynamic_feed_rounded,
                size: 64,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.t('select_photos_prompt'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('tool_batch_desc'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.collections_rounded),
              label: Text(l10n.t('choose_images')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final reduction = Formatters.calculateReductionPercentage(
      _totalOriginalBytes,
      _totalResultBytes,
    );

    return Column(
      children: [
        // Target Preset Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('batch_target_label'),
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _targetPresets.map((kb) {
                  final isSelected = _selectedTargetKb == kb;
                  return ChoiceChip(
                    label: Text('$kb KB'),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: _isProcessing
                        ? null
                        : (_) {
                            setState(() {
                              _selectedTargetKb = kb;
                            });
                          },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Processing Progress Banner (if active)
        if (_isProcessing)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.t('processing')} ($_processedCount / ${_selectedFiles.length})',
                    ),
                    Text(
                      '${((_processedCount / _selectedFiles.length) * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _processedCount / _selectedFiles.length,
                  backgroundColor: AppColors.borderLight,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ),

        // Summary Card if Completed
        if (_exportedFiles.isNotEmpty && !_isProcessing)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('saved_space'),
                      style: const TextStyle(color: Colors.black87, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-${Formatters.formatBytes(_totalOriginalBytes - _totalResultBytes)} (-${reduction.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  onPressed: () async {
                    for (final file in _exportedFiles) {
                      await FileService.shareFile(
                        filePath: file.path,
                        mimeType: 'image/jpeg',
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(l10n.t('share_all')),
                ),
              ],
            ),
          ),

        // Selected files list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _selectedFiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = _selectedFiles[index];
              final isDone = index < _processedCount;

              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.memory(item.bytes, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(Formatters.formatBytes(item.sizeInBytes)),
                  trailing: isDone
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : (_isProcessing && index == _processedCount
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                  });
                                },
                              )),
                ),
              );
            },
          ),
        ),

        // Bottom Action Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeBatch,
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
                  : const Icon(Icons.bolt_rounded),
              label: Text(
                _isProcessing
                    ? '${l10n.t('processing')} ($_processedCount/${_selectedFiles.length})'
                    : '${l10n.t('batch_compress_btn')} (${_selectedFiles.length})',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
