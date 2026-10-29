import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load saved theme mode and language code
  final prefs = await SharedPreferences.getInstance();
  final savedThemeIndex =
      prefs.getInt('fileease_theme_mode') ?? ThemeMode.system.index;
  final initialThemeMode = ThemeMode.values[savedThemeIndex];

  final savedLangCode = prefs.getString('fileease_language_code');

  runApp(FileEaseApp(
    initialThemeMode: initialThemeMode,
    initialLanguageCode: savedLangCode,
  ));
}

class FileEaseApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final String? initialLanguageCode;

  const FileEaseApp({
    super.key,
    required this.initialThemeMode,
    this.initialLanguageCode,
  });

  @override
  State<FileEaseApp> createState() => _FileEaseAppState();
}

class _FileEaseAppState extends State<FileEaseApp> {
  late ThemeMode _themeMode;
  Locale? _locale;
  String _currentLanguageCode = 'system';

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    if (widget.initialLanguageCode != null &&
        widget.initialLanguageCode != 'system') {
      _currentLanguageCode = widget.initialLanguageCode!;
      _locale = Locale(widget.initialLanguageCode!);
    } else {
      _currentLanguageCode = 'system';
      _locale = null; // Automatically follows the device's system locale
    }
  }

  @override
  void didUpdateWidget(FileEaseApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialThemeMode != oldWidget.initialThemeMode) {
      _themeMode = widget.initialThemeMode;
    }
    if (widget.initialLanguageCode != oldWidget.initialLanguageCode) {
      if (widget.initialLanguageCode != null &&
          widget.initialLanguageCode != 'system') {
        _currentLanguageCode = widget.initialLanguageCode!;
        _locale = Locale(widget.initialLanguageCode!);
      } else {
        _currentLanguageCode = 'system';
        _locale = null;
      }
    }
  }

  void _updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fileease_theme_mode', mode.index);
  }

  void _updateLocale(String langCode) async {
    setState(() {
      _currentLanguageCode = langCode;
      if (langCode == 'system') {
        _locale = null; // Defaults to phone system language
      } else {
        _locale = Locale(langCode);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fileease_language_code', langCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileEase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(
        currentThemeMode: _themeMode,
        onThemeModeChanged: _updateThemeMode,
        currentLanguageCode: _currentLanguageCode,
        onLocaleChanged: _updateLocale,
      ),
    );
  }
}
