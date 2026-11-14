// lib/pages/reports_page.dart
//
// Reports for company admins (Admin Console > Reports): the same daily reports as the web
// console - overview, daily summary, vehicle activity, revenue, service time, peak times,
// validations and staff - each with PDF / Excel export. Opens ReportDetailPage.
import 'package:material_ui/material_ui.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'report_detail_page.dart';

const String _ops = '/v1/reports/ops';

const List<ReportDef> kCompanyReports = [
  ReportDef(
    key: 'overview',
    title: 'Overview',
    subtitle: "The day's snapshot, status mix and the last 7 days",
    icon: Icons.dashboard_outlined,
    path: '$_ops/overview',
    period: ReportPeriod.day,
  ),
  ReportDef(
    key: 'daily-summary',
    title: 'Daily Summary',
    subtitle: 'Parked, delivered and revenue per day',
    icon: Icons.calendar_view_week_rounded,
    path: '$_ops/daily-summary',
    defaultDays: 7,
  ),
  ReportDef(
    key: 'vehicle-activity',
    title: 'Vehicle Activity',
    subtitle: 'Every car in the period with times and status',
    icon: Icons.directions_car_filled_outlined,
    path: '$_ops/vehicle-activity',
  ),
  ReportDef(
    key: 'revenue',
    title: 'Revenue',
    subtitle: 'Fees, collection and payment mix',
    icon: Icons.payments_outlined,
    path: '$_ops/revenue',
  ),
  ReportDef(
    key: 'service-time',
    title: 'Service Time',
    subtitle: 'Request-to-delivery time per car',
    icon: Icons.timer_outlined,
    path: '$_ops/service-time',
  ),
  ReportDef(
    key: 'hourly-peak',
    title: 'Hourly Peak',
    subtitle: 'The busiest hours of a day',
    icon: Icons.schedule_rounded,
    path: '$_ops/hourly-peak',
    period: ReportPeriod.day,
  ),
  ReportDef(
    key: 'daily-peak',
    title: 'Daily Peak',
    subtitle: 'The busiest days in a period',
    icon: Icons.event_rounded,
    path: '$_ops/daily-peak',
    defaultDays: 7,
  ),
  ReportDef(
    key: 'validations',
    title: 'Validation Report',
    subtitle: 'Shop validations and charges by shop',
    icon: Icons.verified_outlined,
    path: '/v1/reports/validations',
    startEndParams: true,
  ),
  ReportDef(
    key: 'staff',
    title: 'Staff Report',
    subtitle: 'Cars received and delivered per staff member',
    icon: Icons.badge_outlined,
    path: '/v1/reports/staff',
    startEndParams: true,
  ),
];

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vf = context.vf;
    final colors = [vf.live, vf.brass, vf.live, vf.success, vf.warning, vf.danger, vf.danger, vf.success, vf.brass];
    return Scaffold(
      backgroundColor: vf.page,
      appBar: AppBar(title: Text(tr(context, 'Reports'))),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: kCompanyReports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final def = kCompanyReports[i];
            return _ReportTile(
              def: def,
              color: colors[i % colors.length],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportDetailPage(def: def))),
            );
          },
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ReportDef def;
  final Color color;
  final VoidCallback onTap;
  const _ReportTile({required this.def, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vf = context.vf;
    return Material(
      color: vf.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: vf.line)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(def.icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, def.title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(tr(context, def.subtitle), style: TextStyle(fontSize: 11.5, color: vf.textSecondary)),
              ]),
            ),
            // arrow_forward_ios_rounded mirrors itself in RTL (matchTextDirection).
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: vf.textSecondary),
          ]),
        ),
      ),
    );
  }
}
