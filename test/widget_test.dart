import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fileease/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FileEaseApp renders HomeScreen with French locale', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'fileease_language_code': 'fr'});

    await tester.pumpWidget(
      const FileEaseApp(
        initialThemeMode: ThemeMode.light,
        initialLanguageCode: 'fr',
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Hero Bento card in French
    expect(find.text('FileEase'), findsOneWidget);
    expect(find.text('Compresser Photo à 200 Ko'), findsOneWidget);

    // Verify Bento grid tool cards in French
    expect(find.text('Photos vers PDF'), findsOneWidget);
    expect(find.text('Redimensionner'), findsOneWidget);
    expect(find.text('Convertir Image'), findsOneWidget);

    // Verify Privacy Guarantee badge in French
    expect(find.text('100% Hors-Ligne & Privé'), findsOneWidget);
  });

  testWidgets('FileEaseApp renders HomeScreen with English locale', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'fileease_language_code': 'en'});

    await tester.pumpWidget(
      const FileEaseApp(
        initialThemeMode: ThemeMode.light,
        initialLanguageCode: 'en',
      ),
    );
    await tester.pumpAndSettle();

    // Verify English strings
    expect(find.text('FileEase'), findsOneWidget);
    expect(find.text('Compress Photo to 200 KB'), findsOneWidget);
    expect(find.text('Photos to PDF'), findsOneWidget);
    expect(find.text('Resize'), findsOneWidget);
    expect(find.text('100% Offline & Private'), findsOneWidget);
  });

  testWidgets('FileEaseApp renders HomeScreen with Spanish and Arabic locales', (
    WidgetTester tester,
  ) async {
    // Spanish test
    await tester.pumpWidget(
      const FileEaseApp(
        initialThemeMode: ThemeMode.light,
        initialLanguageCode: 'es',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Comprimir foto a 200 KB'), findsOneWidget);
    expect(find.text('Fotos a PDF'), findsOneWidget);

    // Arabic test
    await tester.pumpWidget(
      const FileEaseApp(
        initialThemeMode: ThemeMode.light,
        initialLanguageCode: 'ar',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ضغط الصورة إلى 200 كيلوبايت'), findsOneWidget);
    expect(find.text('الصور إلى PDF'), findsOneWidget);
  });
}
