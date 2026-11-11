// lib/pages/report_detail_page.dart
//
// One company report (see ReportsPage for the list): a date or From/To picker, the report's KPI
// tiles, its peak / chart section where it has one, the rows as a scrollable table (first 200 -
// the export carries the rest), and PDF / Excel buttons that download the file and open the share
// sheet. Every field is read defensively - a report the backend has not finished yet shows "-"
// instead of breaking the screen.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../components/premium.dart';
import '../l10n/app_strings.dart';
import '../services/plan_service.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';

enum ReportPeriod { day, range }

/// One entry of the Reports list.
class ReportDef {
  /// Stable id: the ops report name (overview, daily-summary, ...), validations or staff.
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Under the API base, e.g. /v1/reports/ops/overview. Exports are {path}/export/{pdf|excel}.
  final String path;
  final ReportPeriod period;

  /// startDate/endDate (validations, staff) instead of from/to (ops reports).
  final bool startEndParams;

  /// Range reports open on the last [defaultDays] days (1 = today).
  final int defaultDays;

  const ReportDef({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.path,
    this.period = ReportPeriod.range,
    this.startEndParams = false,
    this.defaultDays = 1,
  });

  static String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Map<String, String> params(DateTime from, DateTime to) {
    if (period == ReportPeriod.day) return {'date': ymd(from)};
    return startEndParams ? {'startDate': ymd(from), 'endDate': ymd(to)} : {'from': ymd(from), 'to': ymd(to)};
  }

  String fileBaseName(DateTime from, DateTime to) =>
      period == ReportPeriod.day || ymd(from) == ymd(to) ? '$key-${ymd(from)}' : '$key-${ymd(from)}-to-${ymd(to)}';
}

enum _Fmt { text, count, money, dateTime, date, minutes, percent, status }

class _Col {
  final String key;
  final String label;
  final _Fmt fmt;
  const _Col(this.key, this.label, [this.fmt = _Fmt.text]);
  bool get numeric => fmt == _Fmt.count || fmt == _Fmt.money || fmt == _Fmt.minutes || fmt == _Fmt.percent;
}

class ReportDetailPage extends StatefulWidget {
  final ReportDef def;
  const ReportDetailPage({super.key, required this.def});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  static const int _rowCap = 200;

  final _service = ReportService();
  late DateTime _from;
  late DateTime _to;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  PlanRequiredException? _blocked;
  ReportFileFormat? _exporting;
  int _seq = 0;

  ReportDef get _def => widget.def;

  @override
  void initState() {
    super.initState();
    final today = _today();
    _to = today;
    _from = _def.period == ReportPeriod.day ? today : today.subtract(Duration(days: math.max(0, _def.defaultDays - 1)));
    _load();
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
      _blocked = null;
    });
    try {
      final data = await _service.fetch(_def.path, _def.params(_from, _to));
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on PlanRequiredException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _blocked = e;
        _data = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = reportErrorMessage(e);
        _data = null;
        _loading = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final today = _today();
    final first = DateTime(2020);
    if (_def.period == ReportPeriod.day) {
      final d = await showDatePicker(
        context: context,
        initialDate: _from.isAfter(today) ? today : _from,
        firstDate: first,
        lastDate: today,
      );
      if (d == null || !mounted) return;
      setState(() {
        _from = d;
        _to = d;
      });
    } else {
      final r = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(start: _from.isAfter(today) ? today : _from, end: _to.isAfter(today) ? today : _to),
        firstDate: first,
        lastDate: today,
      );
      if (r == null || !mounted) return;
      setState(() {
        _from = DateTime(r.start.year, r.start.month, r.start.day);
        _to = DateTime(r.end.year, r.end.month, r.end.day);
      });
    }
    _load();
  }

  Future<void> _export(ReportFileFormat format, BuildContext buttonContext) async {
    if (_exporting != null) return;
    // iPad needs an anchor for the share popover - take it before any await.
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    final title = tr(context, _def.title);
    setState(() => _exporting = format);
    try {
      final file = await _service.download(_def.path, _def.params(_from, _to), format, _def.fileBaseName(_from, _to));
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: format.mimeType)],
        title: title,
        subject: title,
        sharePositionOrigin: origin,
      ));
    } on PlanRequiredException {
      // The Premium sheet is already on screen (PlanController.onBlocked).
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, reportErrorMessage(e)))));
      }
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  // ── Formatting ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};
  static List<Map<String, dynamic>> _rows(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
  static num? _n(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);

  String _count(dynamic v) {
    final n = _n(v);
    return n == null ? '-' : NumberFormat('#,##0').format(n.round());
  }

  String _money(dynamic v) {
    final n = _n(v);
    return n == null ? '-' : tr(context, 'AED {amount}', {'amount': NumberFormat('#,##0.00').format(n)});
  }

  String _minutes(dynamic v) {
    final n = _n(v);
    if (n == null) return '-';
    final text = n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
    return tr(context, '{n} min', {'n': text});
  }

  String _dateTime(dynamic v) {
    if (v == null) return '-';
    final d = DateTime.tryParse(v.toString());
    return d == null ? v.toString() : DateFormat('d MMM, HH:mm').format(d.isUtc ? d.toLocal() : d);
  }

  String _date(dynamic v) {
    if (v == null) return '-';
    final d = DateTime.tryParse(v.toString());
    return d == null ? v.toString() : DateFormat('EEE d MMM yyyy').format(d);
  }

  String _hour(dynamic v) {
    final n = _n(v);
    return n == null ? '-' : '${n.round().toString().padLeft(2, '0')}:00';
  }

  static const Map<String, String> _statusLabels = {
    'RECEIVED': 'Received',
    'PARKED': 'Parked',
    'REQUESTED': 'Requested',
    'ONTHEWAY': 'On the way',
    'ON_THE_WAY': 'On the way',
    'ARRIVED': 'Arrived',
    'DELIVERED': 'Delivered',
  };

  String _status(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    final label = _statusLabels[s.toUpperCase()];
    return label == null ? s : tr(context, label);
  }

  String _text(dynamic v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  String _fmt(dynamic v, _Fmt f) {
    switch (f) {
      case _Fmt.count:
        return _count(v);
      case _Fmt.money:
        return _money(v);
      case _Fmt.dateTime:
        return _dateTime(v);
      case _Fmt.date:
        return _date(v);
      case _Fmt.minutes:
        return _minutes(v);
      case _Fmt.percent:
        final n = _n(v);
        return n == null ? '-' : '${n > 0 ? '+' : ''}${n.toStringAsFixed(1)}%';
      case _Fmt.status:
        return _status(v);
      case _Fmt.text:
        return _text(v);
    }
  }

  String get _periodLabel {
    final f = DateFormat('d MMM yyyy');
    if (_def.period == ReportPeriod.day || ReportDef.ymd(_from) == ReportDef.ymd(_to)) return f.format(_from);
    return '${f.format(_from)} - ${f.format(_to)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vf.page,
      appBar: AppBar(title: Text(tr(context, _def.title))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _periodBar(),
              const SizedBox(height: 10),
              _exportBar(),
              const SizedBox(height: 18),
              ..._content(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodBar() {
    final vf = context.vf;
    return Material(
      color: vf.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickPeriod,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: vf.line)),
          child: Row(children: [
            Icon(_def.period == ReportPeriod.day ? Icons.today_rounded : Icons.date_range_rounded, color: vf.brass),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, _def.period == ReportPeriod.day ? 'Date' : 'From - To'),
                    style: TextStyle(fontSize: 11.5, color: vf.textSecondary)),
                Text(_periodLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: vf.textPrimary)),
              ]),
            ),
            Text(tr(context, 'Change'), style: TextStyle(fontWeight: FontWeight.w700, color: vf.brass)),
          ]),
        ),
      ),
    );
  }

  Widget _exportBar() {
    Widget button(ReportFileFormat format, String label, IconData icon) {
      final busy = _exporting == format;
      return Expanded(
        child: Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            onPressed: _exporting != null ? null : () => _export(format, buttonContext),
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, size: 18),
            label: Text(tr(context, label)),
          ),
        ),
      );
    }

    return Row(children: [
      button(ReportFileFormat.pdf, 'PDF', Icons.picture_as_pdf_outlined),
      const SizedBox(width: 10),
      button(ReportFileFormat.excel, 'Excel', Icons.table_chart_outlined),
    ]);
  }

  List<Widget> _content() {
    if (_loading) {
      return const [Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))];
    }
    if (_blocked != null) return [_blockedState(_blocked!)];
    if (_error != null) return [_errorState(_error!)];
    final d = _data ?? const <String, dynamic>{};
    switch (_def.key) {
      case 'overview':
        return _overview(d);
      case 'daily-summary':
        return _dailySummary(d);
      case 'vehicle-activity':
        return _vehicleActivity(d);
      case 'revenue':
        return _revenue(d);
      case 'service-time':
        return _serviceTime(d);
      case 'hourly-peak':
        return _hourlyPeak(d);
      case 'daily-peak':
        return _dailyPeak(d);
      case 'validations':
        return _validations(d);
      case 'staff':
        return _staff(d);
      default:
        return [_table('Rows', _rows(d['rows']), const [])];
    }
  }

  // ── Reports ────────────────────────────────────────────────────────────

  List<Widget> _overview(Map<String, dynamic> d) {
    final vf = context.vf;
    final status = _map(d['statusDistribution']);
    final days = _rows(d['last7Days']);
    final weeks = _rows(d['weekOverWeek']);
    return [
      _kpis([
        _Kpi('Checked in', _count(d['checkedIn']), Icons.login_rounded, vf.brass),
        _Kpi('Requested', _count(d['requested']), Icons.notifications_active_outlined, vf.warning),
        _Kpi('On the way', _count(d['onTheWay']), Icons.directions_car_outlined, vf.live),
        _Kpi('Dispatched', _count(d['dispatched']), Icons.check_circle_outline, vf.success),
        _Kpi('Total parked', _count(d['totalParked']), Icons.local_parking, vf.warning),
        _Kpi('Revenue today', _money(d['revenueToday']), Icons.payments_outlined, vf.success),
        _Kpi('Vehicles handled', _count(d['vehiclesHandled']), Icons.swap_horiz_rounded, vf.live),
      ]),
      if (status.isNotEmpty) ...[
        _sectionTitle('Status distribution'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: status.entries
              .map((e) => Chip(
                    label: Text('${_status(e.key)}: ${_count(e.value)}'),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
      _sectionTitle('Last 7 days'),
      days.isEmpty ? _emptyNote() : _dayBars(days),
      if (weeks.isNotEmpty) ...[
        _sectionTitle('Week over week'),
        _table('Week over week', weeks, const [
          _Col('weekStart', 'Week start', _Fmt.date),
          _Col('weekEnd', 'Week end', _Fmt.date),
          _Col('checkIns', 'Check-ins', _Fmt.count),
          _Col('requests', 'Requests', _Fmt.count),
          _Col('dispatches', 'Dispatches', _Fmt.count),
          _Col('avgServiceMinutes', 'Avg. service time', _Fmt.minutes),
          _Col('growthPct', 'Growth', _Fmt.percent),
        ], showTitle: false),
      ],
    ];
  }

  List<Widget> _dailySummary(Map<String, dynamic> d) {
    final vf = context.vf;
    final t = _map(d['totals']);
    return [
      _kpis([
        _Kpi('Parked', _count(t['parked']), Icons.local_parking, vf.brass),
        _Kpi('Delivered', _count(t['delivered']), Icons.check_circle_outline, vf.success),
        _Kpi('Total handled', _count(t['totalHandled']), Icons.swap_horiz_rounded, vf.live),
        _Kpi('Revenue', _money(t['revenue']), Icons.payments_outlined, vf.success),
      ]),
      _table('Days', _rows(d['rows']), const [
        _Col('date', 'Date', _Fmt.date),
        _Col('parked', 'Parked', _Fmt.count),
        _Col('delivered', 'Delivered', _Fmt.count),
        _Col('totalHandled', 'Total handled', _Fmt.count),
        _Col('revenue', 'Revenue', _Fmt.money),
      ]),
    ];
  }

  List<Widget> _vehicleActivity(Map<String, dynamic> d) {
    final rows = _rows(d['rows']);
    return [
      _kpis([_Kpi('Vehicles', _count(rows.length), Icons.directions_car_filled_outlined, context.vf.live)]),
      _table('Vehicles', rows, const [
        _Col('plateNo', 'Plate'),
        _Col('ticketNo', 'Ticket'),
        _Col('make', 'Make'),
        _Col('color', 'Colour'),
        _Col('bayNo', 'Bay'),
        _Col('status', 'Status', _Fmt.status),
        _Col('checkIn', 'Check-in', _Fmt.dateTime),
        _Col('durationMinutes', 'Duration', _Fmt.minutes),
        _Col('requestedBy', 'Requested by'),
        _Col('dispatchTime', 'Dispatched', _Fmt.dateTime),
      ]),
    ];
  }

  List<Widget> _revenue(Map<String, dynamic> d) {
    final vf = context.vf;
    final t = _map(d['totals']);
    // complimentary = fee waived (AED); complimentaryCount = how many tickets.
    final comp = t['complimentary'];
    final compCount = t['complimentaryCount'];
    return [
      _kpis([
        _Kpi('Vehicles', _count(t['vehicles']), Icons.directions_car_filled_outlined, vf.live),
        _Kpi('Total fee', _money(t['totalFee']), Icons.receipt_long_outlined, vf.brass),
        _Kpi('Total collection', _money(t['totalCollection']), Icons.payments_outlined, vf.success),
        _Kpi('Cash', _money(t['cash']), Icons.money_rounded, vf.success),
        _Kpi('Card', _money(t['card']), Icons.credit_card_rounded, vf.live),
        _Kpi(compCount == null ? 'Complimentary' : '${tr(context, 'Complimentary')} (${_count(compCount)})', _money(comp),
            Icons.card_giftcard_outlined, vf.warning),
      ]),
      _table('Transactions', _rows(d['rows']), const [
        _Col('plateNo', 'Plate'),
        _Col('ticketNo', 'Ticket'),
        _Col('fee', 'Fee', _Fmt.money),
        _Col('discount', 'Discount', _Fmt.money),
        _Col('finalAmount', 'Amount', _Fmt.money),
        _Col('payment', 'Payment'),
        _Col('voucher', 'Voucher'),
        _Col('approver', 'Approver'),
        _Col('requestedBy', 'Requested by'),
        _Col('parkInTime', 'Park-in', _Fmt.dateTime),
        _Col('requestTime', 'Requested', _Fmt.dateTime),
        _Col('validatedBy', 'Validated by'),
        _Col('validatedTime', 'Validated', _Fmt.dateTime),
        _Col('remarks', 'Remarks'),
      ]),
    ];
  }

  List<Widget> _serviceTime(Map<String, dynamic> d) {
    final vf = context.vf;
    return [
      _kpis([
        _Kpi('Average service time', _minutes(d['averageMinutes']), Icons.timer_outlined, vf.warning),
        _Kpi('Completed', _count(d['totalCompleted']), Icons.check_circle_outline, vf.success),
      ]),
      _table('Deliveries', _rows(d['rows']), const [
        _Col('plateNo', 'Plate'),
        _Col('site', 'Site'),
        _Col('requestTime', 'Requested', _Fmt.dateTime),
        _Col('deliveredTime', 'Delivered', _Fmt.dateTime),
        _Col('serviceMinutes', 'Service time', _Fmt.minutes),
      ]),
    ];
  }

  List<Widget> _peakTotals(Map<String, dynamic> t) {
    final vf = context.vf;
    return [
      _Kpi('Check-ins', _count(t['checkIns']), Icons.login_rounded, vf.brass),
      _Kpi('Requests', _count(t['requests']), Icons.notifications_active_outlined, vf.warning),
      _Kpi('Dispatches', _count(t['dispatches']), Icons.check_circle_outline, vf.success),
    ];
  }

  List<Widget> _hourlyPeak(Map<String, dynamic> d) {
    final vf = context.vf;
    final hours = _rows(d['hours']).where((h) => _activity(h) > 0).toList();
    final peak = _n(d['peakHour'])?.round();
    return [
      _kpis([
        _Kpi('Peak hour', d['peakHour'] == null ? '-' : _hour(d['peakHour']), Icons.schedule_rounded, vf.danger),
        _Kpi('Activities at peak', _count(d['peakActivities']), Icons.trending_up_rounded, vf.danger),
        ..._peakTotals(_map(d['totals'])),
      ]),
      _sectionTitle('By hour'),
      hours.isEmpty
          ? _emptyNote()
          : _barList([
              for (final h in hours)
                _Bar(
                  _hour(h['hour']),
                  _activity(h),
                  _peakDetail(h),
                  peak != null && _n(h['hour'])?.round() == peak,
                ),
            ]),
    ];
  }

  List<Widget> _dailyPeak(Map<String, dynamic> d) {
    final vf = context.vf;
    final days = _rows(d['days']);
    final busiest = d['busiestDay']?.toString();
    return [
      _kpis([
        _Kpi('Busiest day', busiest == null ? '-' : _date(busiest), Icons.event_rounded, vf.danger),
        _Kpi('Activities that day', _count(d['busiestActivities']), Icons.trending_up_rounded, vf.danger),
        ..._peakTotals(_map(d['totals'])),
      ]),
      _sectionTitle('By day'),
      days.isEmpty
          ? _emptyNote()
          : _barList([
              for (final day in days.take(_rowCap))
                _Bar(
                  _date(day['date']),
                  _n(day['total']) ?? _activity(day),
                  _peakDetail(day),
                  busiest != null && day['date']?.toString() == busiest,
                ),
            ]),
      if (days.length > _rowCap) _capNote(days.length),
    ];
  }

  num _activity(Map<String, dynamic> m) => (_n(m['checkIns']) ?? 0) + (_n(m['requests']) ?? 0) + (_n(m['dispatches']) ?? 0);

  String _peakDetail(Map<String, dynamic> m) => tr(context, 'In {in} · Requests {req} · Out {out}',
      {'in': _count(m['checkIns']), 'req': _count(m['requests']), 'out': _count(m['dispatches'])});

  List<Widget> _validations(Map<String, dynamic> d) {
    final vf = context.vf;
    final t = _map(d['totals']);
    final byShop = _rows(t['byShop']);
    return [
      _kpis([
        _Kpi('Validations', _count(t['count']), Icons.verified_outlined, vf.live),
        _Kpi('Total charged', _money(t['totalCharged']), Icons.payments_outlined, vf.success),
      ]),
      if (byShop.isNotEmpty)
        _table('By shop', byShop, const [
          _Col('shopName', 'Shop'),
          _Col('count', 'Validations', _Fmt.count),
          _Col('totalCharged', 'Total charged', _Fmt.money),
        ]),
      _table('Validations', _rows(d['rows']), const [
        _Col('ticketNo', 'Ticket'),
        _Col('plateNo', 'Plate'),
        _Col('shopName', 'Shop'),
        _Col('validatedBy', 'Validated by'),
        _Col('validatedTime', 'Validated', _Fmt.dateTime),
        _Col('normalCharge', 'Normal charge', _Fmt.money),
        _Col('parkingCharge', 'Charged', _Fmt.money),
        _Col('paymentMethod', 'Payment'),
        _Col('status', 'Status', _Fmt.status),
      ]),
    ];
  }

  List<Widget> _staff(Map<String, dynamic> d) {
    final vf = context.vf;
    final staff = _rows(d['staff']);
    num sum(String k) => staff.fold<num>(0, (a, s) => a + (_n(s[k]) ?? 0));
    return [
      _kpis([
        _Kpi('Staff', _count(staff.length), Icons.badge_outlined, vf.live),
        _Kpi('Received', _count(sum('received')), Icons.login_rounded, vf.brass),
        _Kpi('Delivered', _count(sum('delivered')), Icons.check_circle_outline, vf.success),
      ]),
      _table('Staff', staff, const [
        _Col('employeeId', 'Employee ID'),
        _Col('name', 'Name'),
        _Col('received', 'Received', _Fmt.count),
        _Col('delivered', 'Delivered', _Fmt.count),
        _Col('avgServiceMinutes', 'Avg. service time', _Fmt.minutes),
      ]),
      _table('Tickets', _rows(d['rows']), const [
        _Col('ticketNo', 'Ticket'),
        _Col('plateNo', 'Plate'),
        _Col('bayNo', 'Bay'),
        _Col('make', 'Make'),
        _Col('color', 'Colour'),
        _Col('parkingInTime', 'Park-in', _Fmt.dateTime),
        _Col('vpaIn', 'Received by'),
        _Col('requestedTime', 'Requested', _Fmt.dateTime),
        _Col('vpaOut', 'Delivered by'),
        _Col('vpaOutTime', 'Dispatched', _Fmt.dateTime),
        _Col('deliveredTime', 'Delivered', _Fmt.dateTime),
        _Col('parkingCharge', 'Charge', _Fmt.money),
        _Col('status', 'Status', _Fmt.status),
      ]),
    ];
  }

  // ── Building blocks ────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(tr(context, text),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: context.vf.textSecondary)),
      );

  Widget _kpis(List<Widget> tiles) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tiles.map((t) => SizedBox(width: w, child: t)).toList(),
      );
    });
  }

  Widget _emptyNote([String text = 'No data for this period']) => Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
        decoration: BoxDecoration(color: context.vf.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.vf.line)),
        child: Column(children: [
          Icon(Icons.inbox_outlined, color: context.vf.textSecondary),
          const SizedBox(height: 6),
          Text(tr(context, text), textAlign: TextAlign.center, style: TextStyle(color: context.vf.textSecondary)),
        ]),
      );

  Widget _capNote(int total) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          tr(context, 'Showing the first {cap} of {total}. Export to PDF or Excel for all of them.',
              {'cap': _rowCap, 'total': NumberFormat('#,##0').format(total)}),
          style: TextStyle(fontSize: 11.5, color: context.vf.textSecondary),
        ),
      );

  Widget _table(String title, List<Map<String, dynamic>> rows, List<_Col> cols, {bool showTitle = true}) {
    final vf = context.vf;
    final header = showTitle ? _sectionTitle('${tr(context, title)} (${NumberFormat('#,##0').format(rows.length)})') : null;
    if (rows.isEmpty || cols.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [?header, _emptyNote()]);
    }
    final shown = rows.take(_rowCap).toList();
    final cellStyle = TextStyle(fontSize: 12.5, color: vf.textBody);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        Container(
          decoration: BoxDecoration(color: vf.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: vf.line)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 44,
              horizontalMargin: 12,
              columnSpacing: 18,
              headingRowColor: WidgetStatePropertyAll(vf.card2),
              headingTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: vf.textSecondary),
              columns: [for (final c in cols) DataColumn(label: Text(tr(context, c.label)), numeric: c.numeric)],
              rows: [
                for (final r in shown)
                  DataRow(cells: [
                    for (final c in cols) DataCell(Text(_fmt(r[c.key], c.fmt), style: cellStyle)),
                  ]),
              ],
            ),
          ),
        ),
        if (rows.length > _rowCap) _capNote(rows.length),
      ],
    );
  }

  /// Last 7 days: check-ins and dispatches side by side per day.
  Widget _dayBars(List<Map<String, dynamic>> days) {
    final vf = context.vf;
    final shown = days.length > 7 ? days.sublist(days.length - 7) : days;
    num maxV = 0;
    for (final d in shown) {
      maxV = math.max(maxV, math.max(_n(d['checkIns']) ?? 0, _n(d['dispatches']) ?? 0));
    }
    const barArea = 96.0;
    double h(dynamic v) {
      final n = _n(v) ?? 0;
      if (maxV <= 0 || n <= 0) return 0;
      return math.max(3, barArea * n / maxV);
    }

    Widget bar(dynamic v, Color color) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_count(v), style: TextStyle(fontSize: 9.5, color: vf.textSecondary)),
            const SizedBox(height: 2),
            Container(
              width: 10,
              height: h(v),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
            ),
          ],
        );

    Widget legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(tr(context, label), style: TextStyle(fontSize: 11.5, color: vf.textSecondary)),
        ]);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(color: vf.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: vf.line)),
      child: Column(children: [
        SizedBox(
          // Room for the value and day labels, which grow with the phone's text size.
          height: barArea + 34 * (MediaQuery.textScalerOf(context).scale(10) / 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in shown)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [bar(d['checkIns'], vf.brass), const SizedBox(width: 3), bar(d['dispatches'], vf.success)],
                      ),
                      const SizedBox(height: 4),
                      Text(_shortDay(d['date']), style: TextStyle(fontSize: 10, color: vf.textSecondary), maxLines: 1),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 6, children: [legend(vf.brass, 'Check-ins'), legend(vf.success, 'Dispatches')]),
      ]),
    );
  }

  String _shortDay(dynamic v) {
    final d = v == null ? null : DateTime.tryParse(v.toString());
    return d == null ? _text(v) : DateFormat('d/M').format(d);
  }

  /// Compact horizontal bars (peak reports): label, bar scaled to the largest value, total.
  Widget _barList(List<_Bar> items) {
    final vf = context.vf;
    final maxV = items.fold<num>(0, (a, b) => math.max(a, b.value));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: vf.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: vf.line)),
      child: Column(
        children: [
          for (final b in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(b.label,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: b.highlight ? FontWeight.w800 : FontWeight.w600,
                            color: b.highlight ? vf.danger : vf.textPrimary)),
                  ),
                  if (b.highlight) ...[
                    Icon(Icons.local_fire_department_rounded, size: 15, color: vf.danger),
                    const SizedBox(width: 4),
                  ],
                  Text(_count(b.value), style: TextStyle(fontWeight: FontWeight.w800, color: b.highlight ? vf.danger : vf.textPrimary)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxV <= 0 ? 0 : (b.value / maxV).toDouble().clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: vf.line,
                    color: b.highlight ? vf.danger : vf.brass,
                  ),
                ),
                const SizedBox(height: 3),
                Text(b.detail, style: TextStyle(fontSize: 11, color: vf.textSecondary)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    final vf = context.vf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Icon(Icons.cloud_off_rounded, size: 40, color: vf.danger),
        const SizedBox(height: 10),
        Text(tr(context, 'Could not load the report'), style: TextStyle(fontWeight: FontWeight.w700, color: vf.textPrimary)),
        const SizedBox(height: 4),
        Text(tr(context, message), textAlign: TextAlign.center, style: TextStyle(color: vf.textSecondary)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr(context, 'Retry'))),
      ]),
    );
  }

  Widget _blockedState(PlanRequiredException e) {
    final vf = context.vf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Icon(Icons.star_rounded, size: 40, color: vf.brass),
        const SizedBox(height: 10),
        Text(tr(context, 'Part of Premium'), style: TextStyle(fontWeight: FontWeight.w700, color: vf.textPrimary)),
        const SizedBox(height: 4),
        Text(e.featureLabel, textAlign: TextAlign.center, style: TextStyle(color: vf.textSecondary)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => showPremiumSheet(context, featureKey: e.feature, featureLabel: e.featureLabel),
          child: Text(tr(context, 'See details')),
        ),
      ]),
    );
  }
}

class _Bar {
  final String label;
  final num value;
  final String detail;
  final bool highlight;
  const _Bar(this.label, this.value, this.detail, this.highlight);
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            ),
            Text(tr(context, label), style: TextStyle(fontSize: 11, color: color), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
