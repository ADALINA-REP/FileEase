import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/ads_service.dart';
import '../../../services/history_service.dart';
import '../../batch_compress/presentation/batch_compress_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../image_compress/presentation/image_compress_screen.dart';
import '../../image_convert/presentation/image_convert_screen.dart';
import '../../image_crop/presentation/image_crop_screen.dart';
import '../../image_resize/presentation/image_resize_screen.dart';
import '../../pdf_tools/presentation/images_to_pdf_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../watermark/presentation/watermark_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String currentLanguageCode;
  final ValueChanged<String> onLocaleChanged;

  const HomeScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.currentLanguageCode,
    required this.onLocaleChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    HistoryService.instance.init();
    AdsService.instance.initialize();
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    const double cardHeight = 146.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.t('app_name'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.t('history_title'),
            onPressed: () => _navigateTo(const HistoryScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.t('settings_title'),
            onPressed: () => _navigateTo(
              SettingsScreen(
                currentThemeMode: widget.currentThemeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
                currentLanguageCode: widget.currentLanguageCode,
                onLocaleChanged: widget.onLocaleChanged,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Bento Card: Priority #1 Tool (Compress Photo to 200 KB)
            InkWell(
              onTap: () => _navigateTo(const ImageCompressScreen()),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.nightBlue, AppColors.primaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withAlpha(70),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Colors.amberAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.t('popular_tool'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('hero_compress_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t('hero_compress_desc'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bento Grid for other essential tools (all 6 cards strictly identical in dimensions)
            Row(
              children: [
                // Photos to PDF Card
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: l10n.t('tool_photos_to_pdf'),
                    subtitle: l10n.t('tool_photos_to_pdf_desc'),
                    icon: Icons.picture_as_pdf_rounded,
                    iconBgColor: AppColors.errorLight,
                    iconColor: AppColors.error,
                    height: cardHeight,
                    onTap: () => _navigateTo(const ImagesToPdfScreen()),
                  ),
                ),
                const SizedBox(width: 14),
                // Resize Card
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: l10n.t('tool_resize'),
                    subtitle: l10n.t('tool_resize_desc'),
                    icon: Icons.aspect_ratio_rounded,
                    iconBgColor: AppColors.skyLight,
                    iconColor: AppColors.primaryBlue,
                    height: cardHeight,
                    onTap: () => _navigateTo(const ImageResizeScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                // Convert Image Card
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: l10n.t('tool_convert'),
                    subtitle: l10n.t('tool_convert_desc'),
                    icon: Icons.transform_rounded,
                    iconBgColor: AppColors.successLight,
                    iconColor: AppColors.success,
                    height: cardHeight,
                    onTap: () => _navigateTo(const ImageConvertScreen()),
                  ),
                ),
                const SizedBox(width: 14),
                // Crop Card
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: l10n.t('tool_crop'),
                    subtitle: l10n.t('tool_crop_desc'),
                    icon: Icons.crop_rounded,
                    iconBgColor: AppColors.skyLight,
                    iconColor: AppColors.primaryBlue,
                    height: cardHeight,
                    onTap: () => _navigateTo(const ImageCropScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                // Batch Compress Card
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: l10n.t('tool_batch'),
                    subtitle: l10n.t('tool_batch_desc'),
                    icon: Icons.dynamic_feed_rounded,
                    iconBgColor: AppColors.skyLight,
                    iconColor: AppColors.cyanAccent,
                    height: cardHeight,
                    onTap: () => _navigateTo(const BatchCompressScreen()),
                  ),
                ),
                const SizedBox(width: 14),
                // Anti-fraud Watermark Card
                Expanded(
                  child: _buildBentoCard(
                    context,
                    title: l10n.t('tool_watermark'),
                    subtitle: l10n.t('tool_watermark_desc'),
                    icon: Icons.verified_user_outlined,
                    iconBgColor: AppColors.errorLight,
                    iconColor: AppColors.error,
                    height: cardHeight,
                    onTap: () => _navigateTo(const WatermarkScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // History Quick Access Bar
            AnimatedBuilder(
              animation: HistoryService.instance,
              builder: (context, _) {
                final count = HistoryService.instance.entries.length;
                return _buildBentoCard(
                  context,
                  title: l10n.t('history_title'),
                  subtitle: count > 0
                      ? '$count ${l10n.t('clean_cache_success')}'
                      : l10n.t('history_subtitle'),
                  icon: Icons.folder_open_rounded,
                  iconBgColor: AppColors.warningLight,
                  iconColor: AppColors.warning,
                  onTap: () => _navigateTo(const HistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            // Privacy Guarantee Badge
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('privacy_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.t('privacy_desc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recent activity snippet (if any)
            AnimatedBuilder(
              animation: HistoryService.instance,
              builder: (context, _) {
                final recent = HistoryService.instance.entries.take(2).toList();
                if (recent.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.t('recent_files'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _navigateTo(const HistoryScreen()),
                          child: Text(l10n.t('view_all')),
                        ),
                      ],
                    ),
                    ...recent.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(item.toolTitle),
                          trailing: Text(
                            Formatters.formatBytes(item.resultBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => _navigateTo(const HistoryScreen()),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
    );
  }

  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
    double? height,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final card = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  height: 1.25,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (height != null) {
      return SizedBox(
        height: height,
        child: card,
      );
    }
    return card;
  }
}
