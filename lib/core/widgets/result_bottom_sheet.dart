import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'before_after_slider.dart';
import '../../services/ads_service.dart';
import '../../services/file_service.dart';

class ResultBottomSheet extends StatelessWidget {
  final String title;
  final String fileName;
  final File file;
  final int originalBytes;
  final int resultBytes;
  final Uint8List? rawInputBytes;
  final Uint8List? rawResultBytes;
  final String? extraInfo;

  const ResultBottomSheet({
    super.key,
    required this.title,
    required this.fileName,
    required this.file,
    required this.originalBytes,
    required this.resultBytes,
    this.extraInfo,
    this.rawInputBytes,
    this.rawResultBytes,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String fileName,
    required File file,
    required int originalBytes,
    required int resultBytes,
    String? extraInfo,
    Uint8List? rawInputBytes,
    Uint8List? rawResultBytes,
  }) async {
    // Notify ads service to check frequency cap for non-intrusive interstitial
    AdsService.instance.notifyOperationCompleted();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResultBottomSheet(
        title: title,
        fileName: fileName,
        file: file,
        originalBytes: originalBytes,
        resultBytes: resultBytes,
        extraInfo: extraInfo,
        rawInputBytes: rawInputBytes,
        rawResultBytes: rawResultBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final reduction = Formatters.calculateReductionPercentage(
      originalBytes,
      resultBytes,
    );
    final hasGain = originalBytes > resultBytes && originalBytes > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Success Icon & Badge
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // Metrics Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  context,
                  label: l10n.t('initial_size'),
                  value: Formatters.formatBytes(originalBytes),
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                _buildMetric(
                  context,
                  label: l10n.t('final_size'),
                  value: Formatters.formatBytes(resultBytes),
                  color: AppColors.primaryBlue,
                  isBold: true,
                ),
                if (hasGain) ...[
                  Container(
                    height: 36,
                    width: 1,
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  _buildMetric(
                    context,
                    label: l10n.t('saved_space'),
                    value: '-${reduction.toStringAsFixed(0)}%',
                    color: AppColors.success,
                    isBold: true,
                  ),
                ],
              ],
            ),
          ),

          if (extraInfo != null) ...[
            const SizedBox(height: 12),
            Text(
              extraInfo!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],

          if (rawInputBytes != null && rawResultBytes != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dlgContext) => Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.t('inspect_quality'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      Navigator.of(dlgContext).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 320,
                              child: BeforeAfterSlider(
                                beforeBytes: rawInputBytes!,
                                afterBytes: rawResultBytes!,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () => Navigator.of(dlgContext).pop(),
                              child: Text(l10n.t('close')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.compare_rounded,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
                label: Text(l10n.t('inspect_quality')),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FileService.openFile(file.path);
                  },
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                  label: Text(l10n.t('open')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final isPdf = file.path.toLowerCase().endsWith('.pdf');
                    await FileService.shareFile(
                      filePath: file.path,
                      mimeType: isPdf ? 'application/pdf' : 'image/jpeg',
                      subject: fileName,
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(l10n.t('share')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
