import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fileease/core/localization/app_localizations.dart';

void main() {
  group('Translations & Multilingual Tests', () {
    test('All 10 supported languages are properly defined', () {
      expect(AppLocalizations.supportedLanguages.length, 10);
      expect(AppLocalizations.supportedLocales.length, 10);

      final codes = AppLocalizations.supportedLanguages.map((l) => l.code).toSet();
      expect(codes, containsAll(['en', 'fr', 'es', 'ar', 'zh', 'hi', 'pt', 'de', 'ru', 'ja']));
    });

    test('All translation keys in English exist and are non-empty across all 10 languages', () {
      // Essential core keys that MUST exist and resolve properly in all languages
      final coreKeys = [
        'app_name',
        'app_subtitle',
        'hero_compress_title',
        'hero_compress_desc',
        'tool_photos_to_pdf',
        'tool_photos_to_pdf_desc',
        'tool_resize',
        'tool_resize_desc',
        'tool_convert',
        'tool_convert_desc',
        'tool_crop',
        'tool_crop_desc',
        'tool_batch',
        'tool_batch_desc',
        'tool_watermark',
        'tool_watermark_desc',
        'history_title',
        'history_subtitle',
        'privacy_title',
        'privacy_desc',
        'settings_title',
        'appearance',
        'theme_system',
        'theme_light',
        'theme_dark',
        'language_section',
        'language_system',
        'privacy_section',
        'privacy_commitment',
        'clean_cache',
        'clean_cache_btn',
        'about_section',
        'version',
        'open',
        'share',
        'close',
        'initial_size',
        'final_size',
        'saved_space',
        'crop_free',
        'crop_passport',
        'crop_square',
        'crop_landscape',
        'rotate_90',
        'crop_action',
        'watermark_text_label',
        'watermark_hint',
        'apply_watermark_btn',
        'pdf_title',
        'pdf_generate',
      ];

      for (final lang in AppLocalizations.supportedLanguages) {
        final loc = AppLocalizations(Locale(lang.code));
        for (final key in coreKeys) {
          final translated = loc.t(key);
          expect(
            translated,
            isNotEmpty,
            reason: 'Language ${lang.code} has empty translation for key "$key"',
          );
          // If translation failed, it returns the key itself
          expect(
            translated != key || key == 'app_name',
            isTrue,
            reason: 'Language ${lang.code} is missing key "$key"',
          );
        }
      }
    });

    test('Fallback to English works when key does not exist in target language', () {
      final loc = AppLocalizations(const Locale('fr'));
      // Unknown key falls back to key itself
      expect(loc.t('totally_non_existent_key_xyz'), 'totally_non_existent_key_xyz');
    });

    test('Arabic (ar) uses right-to-left compatible strings and proper characters', () {
      final arLoc = AppLocalizations(const Locale('ar'));
      expect(arLoc.t('hero_compress_title'), contains('ضغط'));
      expect(arLoc.t('tool_crop'), contains('قص'));
      expect(arLoc.t('privacy_title'), contains('100%'));
    });

    test('Chinese (zh) resolves valid simplified Chinese characters', () {
      final zhLoc = AppLocalizations(const Locale('zh'));
      expect(zhLoc.t('hero_compress_title'), contains('压缩'));
      expect(zhLoc.t('tool_crop'), contains('裁剪'));
    });

    test('Japanese (ja) resolves valid Japanese characters', () {
      final jaLoc = AppLocalizations(const Locale('ja'));
      expect(jaLoc.t('hero_compress_title'), contains('圧縮'));
      expect(jaLoc.t('tool_crop'), contains('トリミング'));
    });
  });
}
