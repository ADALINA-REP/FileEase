import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/result_bottom_sheet.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';
import '../../../services/pdf_service.dart';

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  final List<SelectedFileItem> _images = [];
  bool _isProcessing = false;
  PdfPageSizePreset _pagePreset = PdfPageSizePreset.a4;

  Future<void> _addImages() async {
    final picked = await FileService.pickMultipleImages();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _generatePdf() async {
    if (_images.isEmpty || _isProcessing) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      final entries = _images
          .map((img) => PdfImageEntry(bytes: img.bytes, name: img.name))
          .toList();

      final pdfBytes = await PdfService.imagesToPdf(
        images: entries,
        pageSize: _pagePreset,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'FileEase_Document_$timestamp.pdf';

      final savedFile = await FileService.saveExportFile(
        bytes: pdfBytes,
        fileName: fileName,
      );

      int totalInputBytes = 0;
      for (final img in _images) {
        totalInputBytes += img.sizeInBytes;
      }

      await HistoryService.instance.addEntry(
        toolTitle: '${l10n.t('pdf_title')} (${_images.length})',
        fileName: fileName,
        filePath: savedFile.path,
        originalBytes: totalInputBytes,
        resultBytes: pdfBytes.lengthInBytes,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        await ResultBottomSheet.show(
          context: context,
          title: l10n.t('success_title'),
          fileName: fileName,
          file: savedFile,
          originalBytes: totalInputBytes,
          resultBytes: pdfBytes.lengthInBytes,
          extraInfo:
              '${_images.length} pages • ${_pagePreset.name.toUpperCase()}',
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
        title: Text(l10n.t('pdf_title')),
        actions: [
          if (_images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: l10n.t('choose_images'),
              onPressed: _isProcessing ? null : _addImages,
            ),
        ],
      ),
      body: _images.isEmpty ? _buildEmpty(context) : _buildWorkspace(context),
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
                Icons.picture_as_pdf_rounded,
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
              l10n.t('tool_photos_to_pdf_desc'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addImages,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(l10n.t('choose_images')),
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

    return Column(
      children: [
        // Top Toolbar (Page preset & count)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_images.length} images',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              DropdownButton<PdfPageSizePreset>(
                value: _pagePreset,
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(
                    value: PdfPageSizePreset.a4,
                    child: Text('A4'),
                  ),
                  const DropdownMenuItem(
                    value: PdfPageSizePreset.letter,
                    child: Text('Letter US'),
                  ),
                  DropdownMenuItem(
                    value: PdfPageSizePreset.fitToImage,
                    child: Text(l10n.t('pdf_fit_image')),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _pagePreset = val;
                    });
                  }
                },
              ),
            ],
          ),
        ),

        // Grid of Selected Pages
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final item = _images[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(item.bytes, fit: BoxFit.cover),
                    // Page number badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Page ${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Delete button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => _removeImage(index),
                        ),
                      ),
                    ),
                    // Bottom file info
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.black.withAlpha(140),
                        child: Text(
                          Formatters.formatBytes(item.sizeInBytes),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Action Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _generatePdf,
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
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _isProcessing
                    ? l10n.t('processing')
                    : '${l10n.t('pdf_generate')} (${_images.length})',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
