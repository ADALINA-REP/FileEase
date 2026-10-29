import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ads_service.dart';
import '../../../services/file_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String currentLanguageCode;
  final ValueChanged<String> onLocaleChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.currentLanguageCode,
    required this.onLocaleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _deletedCacheFiles = -1;

  Future<void> _cleanCache() async {
    final l10n = AppLocalizations.of(context);
    final count = await FileService.cleanTemporaryFiles();
    if (mounted) {
      setState(() {
        _deletedCacheFiles = count;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count ${l10n.t('clean_cache_success')}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showPrivacyPolicy() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('privacy_modal_title'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('privacy_modal_ondevice_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(l10n.t('privacy_modal_ondevice_body')),
              const SizedBox(height: 14),
              Text(
                l10n.t('privacy_modal_personal_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(l10n.t('privacy_modal_personal_body')),
              const SizedBox(height: 14),
              Text(
                l10n.t('privacy_modal_ads_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(l10n.t('privacy_modal_ads_body')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('privacy_modal_ok')),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          color: AppColors.primaryBlue),
                      const SizedBox(width: 10),
                      Text(
                        l10n.t('language_section'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // System default option
                      ListTile(
                        leading: const Icon(Icons.settings_suggest_rounded,
                            color: AppColors.primaryBlue),
                        title: Text(
                          l10n.t('language_system'),
                          style: TextStyle(
                            fontWeight: widget.currentLanguageCode == 'system'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: widget.currentLanguageCode == 'system'
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.primaryBlue)
                            : null,
                        onTap: () {
                          widget.onLocaleChanged('system');
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(height: 1),
                      // 10 supported languages
                      ...AppLocalizations.supportedLanguages.map((lang) {
                        final isSelected =
                            widget.currentLanguageCode == lang.code;
                        return ListTile(
                          title: Text(
                            lang.nativeName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(lang.name),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primaryBlue)
                              : null,
                          onTap: () {
                            widget.onLocaleChanged(lang.code);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLanguageDisplayName(String code, AppLocalizations l10n) {
    if (code == 'system') {
      return l10n.t('language_system');
    }
    final match = AppLocalizations.supportedLanguages
        .where((l) => l.code == code)
        .firstOrNull;
    if (match != null) {
      return '${match.nativeName} (${match.name})';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section Langue
          Text(
            l10n.t('language_section'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: AppColors.primaryBlue,
              ),
              title: Text(l10n.t('language_section')),
              subtitle: Text(
                _getLanguageDisplayName(widget.currentLanguageCode, l10n),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showLanguageSelector,
            ),
          ),
          const SizedBox(height: 20),

          // Section Apparence
          Text(
            l10n.t('appearance'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.t('theme_system')),
                    icon: const Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.t('theme_light')),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.t('theme_dark')),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {widget.currentThemeMode},
                onSelectionChanged: (val) {
                  widget.onThemeModeChanged(val.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section Confidentialité & Stockage
          Text(
            l10n.t('privacy_section'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.security_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  title: Text(l10n.t('privacy_commitment')),
                  subtitle: Text(l10n.t('privacy_commitment_desc')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.cleaning_services_outlined,
                    color: AppColors.warning,
                  ),
                  title: Text(l10n.t('clean_cache')),
                  subtitle: Text(
                    _deletedCacheFiles >= 0
                        ? '$_deletedCacheFiles ${l10n.t('clean_cache_success')}'
                        : l10n.t('privacy_commitment_desc'),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _cleanCache,
                    child: Text(l10n.t('clean_cache_btn')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section À Propos
          Text(
            l10n.t('about_section'),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                  title: Text(l10n.t('app_name')),
                  subtitle: Text(l10n.t('app_subtitle')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tag_rounded),
                  title: Text(l10n.t('version')),
                  trailing: Text(
                    '1.0.0 (Build 1)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
    );
  }
}
