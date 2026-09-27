// Tests for the English/Arabic layer (lib/l10n/app_strings.dart). They run without a device.
// (Replaces Flutter's default counter template, which never matched this app.)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_valetfusion/l10n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.locale,
      builder: (context, locale, _) => MaterialApp(
        locale: locale ?? const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController.locale.value = null;
  });

  testWidgets('English by default', (tester) async {
    await tester.pumpWidget(_app(Builder(builder: (c) => Text(tr(c, 'Check Status')))));
    expect(find.text('Check Status'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Check Status'))), TextDirection.ltr);
  });

  testWidgets('Arabic text and right-to-left layout', (tester) async {
    LocaleController.locale.value = const Locale('ar');
    await tester.pumpWidget(_app(Builder(builder: (c) => Text(tr(c, 'Check Status')))));
    await tester.pumpAndSettle();
    expect(find.text('عرض الحالة'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('عرض الحالة'))), TextDirection.rtl);
  });

  testWidgets('placeholders are filled in both languages', (tester) async {
    LocaleController.locale.value = const Locale('ar');
    await tester.pumpWidget(_app(Builder(builder: (c) => Text(tr(c, 'Parked at {place}', {'place': 'B1-12'})))));
    await tester.pumpAndSettle();
    expect(find.text('مصفوفة في B1-12'), findsOneWidget);
  });

  testWidgets('a missing translation falls back to English', (tester) async {
    LocaleController.locale.value = const Locale('ar');
    await tester.pumpWidget(_app(Builder(builder: (c) => Text(tr(c, 'Not in the dictionary')))));
    await tester.pumpAndSettle();
    expect(find.text('Not in the dictionary'), findsOneWidget);
  });

  testWidgets('language switch flips the app and remembers the choice', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      const LanguageToggle(),
      Builder(builder: (c) => Text(tr(c, 'Track Your Vehicle'))),
    ])));
    expect(find.text('Track Your Vehicle'), findsOneWidget);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('تتبّع سيارتك'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vf_locale'), 'ar');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Track Your Vehicle'), findsOneWidget);
  });
}
