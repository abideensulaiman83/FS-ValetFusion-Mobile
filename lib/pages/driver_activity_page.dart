// lib/pages/driver_activity_page.dart
//
// Driver's own "My Activity" report - today's delivery count, lifetime count, average
// dispatch-to-delivered turnaround, and recent deliveries with the guest's rating where given.
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../services/valet_service.dart';
import '../theme/app_theme.dart';

class DriverActivityPage extends StatefulWidget {
  const DriverActivityPage({super.key});

  @override
  State<DriverActivityPage> createState() => _DriverActivityPageState();
}

class _DriverActivityPageState extends State<DriverActivityPage> {
  final _valetService = ValetService();
  DriverActivity? _activity;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await _valetService.fetchMyActivity();
      if (mounted) setState(() => _activity = activity);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'My Activity'))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statCard(tr(context, 'Today'), '${_activity?.deliveredToday ?? 0}', Icons.today, Theme.of(context).colorScheme.primary)),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(tr(context, 'All Time'), '${_activity?.deliveredTotal ?? 0}', Icons.emoji_events_outlined, context.vf.success)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _statCard(
                            tr(context, 'Avg. Turnaround'),
                            _activity?.averageTurnaroundMinutes != null
                                ? tr(context, '{n} min', {'n': _activity!.averageTurnaroundMinutes!.round()})
                                : '-',
                            Icons.timer_outlined,
                            context.vf.warning,
                          ),
                          const SizedBox(height: 20),
                          Text(tr(context, 'Recent Deliveries'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.vf.textPrimary)),
                          const SizedBox(height: 10),
                          if ((_activity?.recentDeliveries ?? []).isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(tr(context, 'No deliveries yet'), style: TextStyle(color: context.vf.textSecondary)),
                            )
                          else
                            for (final d in _activity!.recentDeliveries) _deliveryRow(d),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _deliveryRow(DriverRecentDelivery d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: context.vf.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.vf.line)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, 'Ticket {no}', {'no': d.ticketNo}), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.vf.textPrimary)),
                if (d.plateNo != null) Text(d.plateNo!, style: TextStyle(fontSize: 12, color: context.vf.textSecondary)),
              ],
            ),
          ),
          if (d.turnaroundMinutes != null)
            Text(tr(context, '{n} min', {'n': d.turnaroundMinutes}), style: TextStyle(fontSize: 12, color: context.vf.textSecondary)),
          if (d.rating != null) ...[
            const SizedBox(width: 10),
            Row(
              children: List.generate(5, (i) => Icon(
                    i < d.rating! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: context.vf.warning,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}
