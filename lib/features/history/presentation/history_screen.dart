import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';
import '../../../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    HistoryService.instance.init();
  }

  Future<void> _confirmClearAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('history_clear')),
        content: Text(l10n.t('history_subtitle')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.t('close')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.t('history_clear')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryService.instance.clearAll();
      await FileService.cleanTemporaryFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('history_clear')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('history_title')),
        actions: [
          AnimatedBuilder(
            animation: HistoryService.instance,
            builder: (context, _) {
              if (HistoryService.instance.entries.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: l10n.t('history_clear'),
                onPressed: _confirmClearAll,
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: HistoryService.instance,
        builder: (context, _) {
          final entries = HistoryService.instance.entries;
          final totalSaved = HistoryService.instance.totalBytesSaved;

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 64,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.borderLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('history_empty'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('history_subtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Space Saved Banner
              if (totalSaved > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.nightBlue, AppColors.primaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('history_saved_total'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.formatBytes(totalSaved),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    final dateStr = DateFormat(
                      'dd MMM yyyy • HH:mm',
                    ).format(item.timestamp);
                    final reduction = Formatters.calculateReductionPercentage(
                      item.originalBytes,
                      item.resultBytes,
                    );
                    final isPdf = item.fileName.toLowerCase().endsWith('.pdf');

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPdf
                              ? AppColors.errorLight
                              : AppColors.skyLight,
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                            color: isPdf
                                ? AppColors.error
                                : AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${item.toolTitle} • $dateStr',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  Formatters.formatBytes(item.resultBytes),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue,
                                    fontSize: 12,
                                  ),
                                ),
                                if (reduction > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '-${reduction.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 20),
                              tooltip: l10n.t('share'),
                              onPressed: () async {
                                final f = File(item.filePath);
                                if (await f.exists()) {
                                  await FileService.shareFile(
                                    filePath: f.path,
                                    mimeType: isPdf
                                        ? 'application/pdf'
                                        : 'image/jpeg',
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_red_eye_outlined,
                                size: 20,
                              ),
                              tooltip: l10n.t('open'),
                              onPressed: () async {
                                final f = File(item.filePath);
                                if (await f.exists()) {
                                  await FileService.openFile(f.path);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
    );
  }
}
