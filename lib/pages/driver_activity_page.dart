// lib/pages/driver_activity_page.dart
//
// Driver's own "My Activity" report - today's delivery count, lifetime count, average
// dispatch-to-delivered turnaround, and recent deliveries with the guest's rating where given.
import 'package:flutter/material.dart';
import '../services/valet_service.dart';

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
      appBar: AppBar(title: const Text('My Activity')),
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
                              Expanded(child: _statCard('Today', '${_activity?.deliveredToday ?? 0}', Icons.today, Colors.blue)),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard('All Time', '${_activity?.deliveredTotal ?? 0}', Icons.emoji_events_outlined, Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _statCard(
                            'Avg. Turnaround',
                            _activity?.averageTurnaroundMinutes != null
                                ? '${_activity!.averageTurnaroundMinutes!.round()} min'
                                : '-',
                            Icons.timer_outlined,
                            Colors.orange,
                          ),
                          const SizedBox(height: 20),
                          Text('Recent Deliveries', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                          const SizedBox(height: 10),
                          if ((_activity?.recentDeliveries ?? []).isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text('No deliveries yet', style: TextStyle(color: Colors.grey.shade500)),
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

  Widget _statCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade600),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color.shade800)),
          Text(label, style: TextStyle(fontSize: 12, color: color.shade700)),
        ],
      ),
    );
  }

  Widget _deliveryRow(DriverRecentDelivery d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ticket ${d.ticketNo}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (d.plateNo != null) Text(d.plateNo!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (d.turnaroundMinutes != null)
            Text('${d.turnaroundMinutes} min', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (d.rating != null) ...[
            const SizedBox(width: 10),
            Row(
              children: List.generate(5, (i) => Icon(
                    i < d.rating! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber.shade600,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}
