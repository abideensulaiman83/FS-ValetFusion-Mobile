// Tests for the company Reports screens' pure parts (no network): the query parameters and file
// names each report sends, and the report list in English and Arabic.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_valetfusion/l10n/app_strings.dart';
import 'package:fs_valetfusion/pages/report_detail_page.dart';
import 'package:fs_valetfusion/pages/reports_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

ReportDef _def(String key) => kCompanyReports.firstWhere((d) => d.key == key);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final from = DateTime(2026, 11, 1);
  final to = DateTime(2026, 11, 10);

  test('day reports send date, ops ranges from/to, validations and staff startDate/endDate', () {
    expect(_def('overview').params(from, to), {'date': '2026-11-01'});
    expect(_def('hourly-peak').params(from, to), {'date': '2026-11-01'});
    expect(_def('daily-summary').params(from, to), {'from': '2026-11-01', 'to': '2026-11-10'});
    expect(_def('validations').params(from, to), {'startDate': '2026-11-01', 'endDate': '2026-11-10'});
    expect(_def('staff').params(from, to), {'startDate': '2026-11-01', 'endDate': '2026-11-10'});
  });

  test('report paths match the backend endpoints', () {
    expect(_def('overview').path, '/v1/reports/ops/overview');
    expect(_def('daily-peak').path, '/v1/reports/ops/daily-peak');
    expect(_def('validations').path, '/v1/reports/validations');
    expect(_def('staff').path, '/v1/reports/staff');
  });

  test('export file names carry the period', () {
    expect(_def('overview').fileBaseName(from, to), 'overview-2026-11-01');
    expect(_def('revenue').fileBaseName(from, to), 'revenue-2026-11-01-to-2026-11-10');
    expect(_def('revenue').fileBaseName(from, from), 'revenue-2026-11-01');
  });

  testWidgets('the report list shows all nine reports', (tester) async {
    await tester.pumpWidget(_app(const ReportsPage(), const Locale('en')));
    expect(kCompanyReports.length, 9);
    for (final t in ['Overview', 'Daily Summary', 'Vehicle Activity', 'Revenue', 'Service Time']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('the report list is translated in Arabic', (tester) async {
    await tester.pumpWidget(_app(const ReportsPage(), const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('نظرة عامة'), findsOneWidget);
    expect(find.text('الملخص اليومي'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('نظرة عامة'))), TextDirection.rtl);
  });

  testWidgets('every report title and subtitle has an Arabic translation', (tester) async {
    await tester.pumpWidget(_app(Builder(builder: (c) {
      final missing = <String>[
        for (final d in kCompanyReports) ...[
          if (tr(c, d.title) == d.title) d.title,
          if (tr(c, d.subtitle) == d.subtitle) d.subtitle,
        ],
      ];
      return Text(missing.join('|'), textDirection: TextDirection.ltr);
    }), const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text(''), findsOneWidget);
  });
}
