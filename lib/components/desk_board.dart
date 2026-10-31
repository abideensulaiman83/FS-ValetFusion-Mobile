// lib/components/desk_board.dart
//
// Live desk board for the lobby, key controllers, valet desk and company admins: every car a
// guest is waiting for, in three lanes - Requested, On the way, At lobby - each with the guest's
// running wait (since the request) coloured by the wait bands (green < 10 min, amber < 20, red
// after). Refreshes every 10 s and on pull-to-refresh; tapping a car opens the same dialog as
// scanning its ticket (dispatch / arrived / delivered, with their Undo links).
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/valet_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'pending_sync_banner.dart';

class DeskBoard extends StatefulWidget {
  /// Opens the ticket's next-step dialog (the desk's own lookup flow).
  final Future<void> Function(String ticketNo) onOpen;
  const DeskBoard({super.key, required this.onOpen});

  @override
  State<DeskBoard> createState() => _DeskBoardState();
}

class _BoardCar {
  final String ticketNo;
  final String? plateNo;
  final String? make;
  final String? color;
  final String status; // REQUESTED / ONTHEWAY / ARRIVED
  final DateTime? requestedAt;
  final DateTime? dispatchedAt;
  final DateTime? arrivedAt;
  final String? driver;
  final String? bay;

  _BoardCar.fromJson(Map<String, dynamic> v, String fallbackStatus)
      : ticketNo = v['ticketNo']?.toString() ?? '',
        plateNo = v['plateNo'] as String?,
        make = v['vehicleMake'] as String?,
        color = v['vehicleColor'] as String?,
        status = (v['status'] as String?) ?? fallbackStatus,
        requestedAt = _parse(v['requestedTime']),
        dispatchedAt = _parse(v['dispatchedTime']),
        arrivedAt = _parse(v['arrivedTime']),
        driver = v['vpaOut'] as String?,
        bay = v['bayNo'] as String?;

  static DateTime? _parse(Object? s) => s is String && s.isNotEmpty ? DateTime.tryParse(s) : null;
}

class _DeskBoardState extends State<DeskBoard> {
  final ValetService _service = ValetService();
  List<_BoardCar> _cars = const [];
  Duration _skew = Duration.zero; // server clock minus phone clock
  bool _loaded = false;
  String? _error;
  DateTime? _lastOk;
  Timer? _poll;
  Timer? _tick;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _cars.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final d = await _service.fetchDashboardDetails();
      final serverNow = d.timestamp == null ? null : DateTime.tryParse(d.timestamp!);
      final cars = [
        ...d.requestedVehicles.map((v) => _BoardCar.fromJson(v, 'REQUESTED')),
        ...d.onthewayVehicles.map((v) => _BoardCar.fromJson(v, 'ONTHEWAY')),
      ];
      if (!mounted) return;
      setState(() {
        _cars = cars;
        if (serverNow != null) _skew = serverNow.difference(DateTime.now());
        _loaded = true;
        _error = null;
        _lastOk = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _open(_BoardCar c) async {
    if (_opening || c.ticketNo.isEmpty) return;
    _opening = true;
    try {
      await widget.onOpen(c.ticketNo);
    } finally {
      _opening = false;
      _refresh();
    }
  }

  Duration _since(DateTime? t) {
    if (t == null) return Duration.zero;
    final d = DateTime.now().add(_skew).difference(t);
    return d.isNegative ? Duration.zero : d;
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    if (m >= 60) return '${d.inHours}h ${(m % 60).toString().padLeft(2, '0')}m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    List<_BoardCar> lane(bool Function(_BoardCar) test) =>
        _cars.where(test).toList()..sort((a, b) => _since(b.requestedAt).compareTo(_since(a.requestedAt)));
    final requested = lane((c) => c.status == 'REQUESTED');
    final onTheWay = lane((c) => c.status == 'ONTHEWAY');
    final atLobby = lane((c) => c.status == 'ARRIVED');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const PendingSyncBanner(),
          _statusLine(),
          const SizedBox(height: 12),
          if (!_loaded)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else ...[
            _lane(tr(context, 'Requested'), 'REQUESTED', requested, brightness, tr(context, 'No cars waiting for a driver')),
            const SizedBox(height: 16),
            _lane(tr(context, 'On the way'), 'ONTHEWAY', onTheWay, brightness, tr(context, 'No cars on the way')),
            const SizedBox(height: 16),
            _lane(tr(context, 'At lobby'), 'ARRIVED', atLobby, brightness, tr(context, 'No cars waiting at the lobby')),
          ],
        ],
      ),
    );
  }

  Widget _statusLine() {
    final stale = _error != null;
    final last = _lastOk;
    final ago = last == null ? null : DateTime.now().difference(last).inSeconds;
    final vf = context.vf;
    return Row(
      children: [
        Icon(stale ? Icons.cloud_off_outlined : Icons.sensors, size: 16, color: stale ? vf.warning : vf.success),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            stale
                ? (last == null
                    ? tr(context, 'Board unavailable - {error}', {'error': _error})
                    : tr(context, 'Not updating - last update {n}s ago', {'n': ago}))
                : tr(context, 'Live · updates every 10 s'),
            style: TextStyle(fontSize: 12, color: stale ? vf.warning : vf.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(tr(context, '{n} waiting', {'n': _cars.length}), style: AppTheme.mono(size: 12, color: vf.textSecondary)),
      ],
    );
  }

  Widget _lane(String title, String status, List<_BoardCar> cars, Brightness b, String empty) {
    final color = ticketStateColor(status, b);
    final vf = context.vf;
    return Container(
      decoration: BoxDecoration(
        color: vf.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vf.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${cars.length}', style: AppTheme.numeral(size: 22, color: color)),
              ],
            ),
          ),
          if (cars.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
              child: Text(empty, style: TextStyle(color: vf.textSecondary, fontSize: 13)),
            )
          else
            ...cars.map((c) => _row(c, b)),
        ],
      ),
    );
  }

  Widget _row(_BoardCar c, Brightness b) {
    final wait = _since(c.requestedAt);
    final band = waitBandColor(wait, b);
    final car = [c.color, c.make].where((s) => s != null && s.isNotEmpty).join(' ');
    final vf = context.vf;
    final String detail;
    switch (c.status) {
      case 'ONTHEWAY':
        detail = [
          if (c.driver != null && c.driver!.isNotEmpty) c.driver!,
          if (c.dispatchedAt != null) tr(context, 'out {time}', {'time': _fmt(_since(c.dispatchedAt))}),
        ].join(' · ');
        break;
      case 'ARRIVED':
        detail = c.arrivedAt != null ? tr(context, 'at lobby {time}', {'time': _fmt(_since(c.arrivedAt))}) : tr(context, 'at lobby');
        break;
      default:
        detail = c.bay != null && c.bay!.isNotEmpty ? tr(context, 'Bay {bay}', {'bay': c.bay}) : tr(context, 'awaiting a driver');
    }
    return InkWell(
      onTap: () => _open(c),
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: band, width: 4), top: BorderSide(color: vf.line)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.ticketNo, style: AppTheme.mono(size: 15, weight: FontWeight.w700, color: vf.textPrimary)),
                      const SizedBox(width: 8),
                      if (c.plateNo != null && c.plateNo!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.plateBg,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.lineStrong),
                          ),
                          child: Text(c.plateNo!, style: AppTheme.mono(size: 12, color: AppColors.plateFg)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [if (car.isNotEmpty) car, if (detail.isNotEmpty) detail].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: vf.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(c.requestedAt == null ? '-' : _fmt(wait), style: AppTheme.numeral(size: 26, color: band)),
                Text(tr(context, 'guest wait'), style: TextStyle(fontSize: 10.5, color: vf.textSecondary)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: vf.textSecondary),
          ],
        ),
      ),
    );
  }
}
