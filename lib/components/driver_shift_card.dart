// lib/components/driver_shift_card.dart
//
// Top of the driver home: Start shift / Break / End shift as big thumb-sized buttons. The state
// is kept on the server (/v1/driver-shift/me), so the desk's dispatch picker lists on-duty
// drivers first and marks who is on a break or off duty. Ending the shift shows a summary -
// cars received and handed over this shift, counted from the cars themselves.
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/valet_service.dart';
import '../theme/app_theme.dart';
import 'confirm_dialog.dart';

class DriverShiftCard extends StatefulWidget {
  const DriverShiftCard({super.key});

  @override
  State<DriverShiftCard> createState() => _DriverShiftCardState();
}

class _DriverShiftCardState extends State<DriverShiftCard> {
  final ValetService _service = ValetService();
  DriverShift? _shift;
  bool _busy = false;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps the counts and the "on duty for" time current while the screen is open.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _service.fetchMyShift();
      if (mounted) {
        setState(() {
          _shift = s;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && _shift == null) setState(() => _failed = true);
    }
  }

  Future<void> _set(String state) async {
    if (state == 'OFF') {
      final inHand = _shift?.inHand ?? 0;
      final ok = await showConfirmDialog(
        context,
        title: 'End your shift?',
        message: inHand > 0
            ? 'You still have $inHand car${inHand == 1 ? '' : 's'} on the way or at the lobby. '
                'The desk will see you as off duty.'
            : 'The desk will see you as off duty and stop suggesting you for pickups.',
        confirmLabel: 'End shift',
        destructive: true,
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      final s = await _service.updateMyShift(state);
      if (!mounted) return;
      setState(() => _shift = s);
      if (state == 'OFF' && s.shiftStart != null) {
        await _showSummary(s);
      } else if (s.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.message!), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _duration(int minutes) => minutes >= 60 ? '${minutes ~/ 60}h ${minutes % 60}m' : '${minutes}m';

  static String _clock(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showSummary(DriverShift s) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.flag_circle_rounded, color: AppColors.success, size: 40),
          title: const Text('Shift ended'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_clock(s.shiftStart)} - ${_clock(s.shiftEnd)} · ${_duration(s.shiftMinutes)}'
                  '${s.breakMinutes > 0 ? ' (breaks ${_duration(s.breakMinutes)})' : ''}'),
              const SizedBox(height: 16),
              _SummaryRow(received: s.receivedThisShift, delivered: s.deliveredThisShift),
            ],
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = _shift;
    if (s == null) {
      if (!_failed) return const SizedBox.shrink();
      // Shift endpoint unreachable (offline / older server) - offer a retry, never block the work.
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Shift status unavailable - retry'),
        ),
      );
    }
    final Color stateColor = s.onDuty ? AppColors.success : (s.onBreak ? AppColors.warning : AppColors.textSecondary);
    final String stateText = s.onDuty ? 'On duty' : (s.onBreak ? 'On break' : 'Off duty');
    final since = _clock(s.since);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.off ? AppColors.line : stateColor.withValues(alpha: 0.5), width: s.off ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(stateText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: stateColor)),
              if (!s.off && since.isNotEmpty)
                Text('  since $since', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              if (!s.off) Text(_duration(s.shiftMinutes), style: AppTheme.numeral(size: 20, color: AppColors.textPrimary)),
            ],
          ),
          if (!s.off) ...[
            const SizedBox(height: 12),
            _SummaryRow(received: s.receivedThisShift, delivered: s.deliveredThisShift, inHand: s.inHand),
          ] else if (s.shiftEnd != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last shift ${_clock(s.shiftStart)} - ${_clock(s.shiftEnd)}: '
              '${s.receivedThisShift} received · ${s.deliveredThisShift} handed over',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          if (s.off)
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _set('ON_DUTY'),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text('Start shift', style: TextStyle(fontSize: 17)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: s.onBreak
                        ? ElevatedButton.icon(
                            onPressed: _busy ? null : () => _set('ON_DUTY'),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Back on duty'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          )
                        : OutlinedButton.icon(
                            onPressed: _busy ? null : () => _set('BREAK'),
                            icon: const Icon(Icons.free_breakfast_outlined),
                            label: const Text('Break'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning, width: 1.4),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _set('OFF'),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('End shift'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger, width: 1.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int received;
  final int delivered;
  final int? inHand;
  const _SummaryRow({required this.received, required this.delivered, this.inHand});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text('$value', style: AppTheme.numeral(size: 30, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Row(
      children: [
        stat('Received', received, AppColors.live),
        stat('Handed over', delivered, AppColors.success),
        if (inHand != null) stat('In hand', inHand!, AppColors.warning),
      ],
    );
  }
}
