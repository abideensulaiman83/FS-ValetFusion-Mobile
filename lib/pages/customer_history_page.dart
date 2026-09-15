// lib/pages/customer_history_page.dart
//
// Customer's own "My Parking History" - a small dashboard (visit count, avg rating, total spent)
// over the same list of every visit ever linked to their account, computed client-side from the
// list already fetched (no separate stats endpoint needed).
import 'package:flutter/material.dart';
import '../services/valet_service.dart';

class CustomerHistoryPage extends StatefulWidget {
  const CustomerHistoryPage({super.key});

  @override
  State<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  final _valetService = ValetService();
  List<CustomerHistoryEntry> _history = [];
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
      final history = await _valetService.fetchMyHistory();
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalVisits => _history.length;

  double? get _averageRating {
    final rated = _history.where((h) => h.rating != null).toList();
    if (rated.isEmpty) return null;
    return rated.map((h) => h.rating!).reduce((a, b) => a + b) / rated.length;
  }

  double get _totalSpent =>
      _history.where((h) => h.status == 'DELIVERED').fold(0.0, (sum, h) => sum + (h.parkingCharge ?? 0));

  int get _visitsThisMonth {
    final now = DateTime.now();
    return _history.where((h) {
      final raw = h.deliveredTime ?? h.parkingInTime;
      if (raw == null) return false;
      final d = DateTime.tryParse(raw);
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(title: const Text('My Parking History')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _history.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 400,
                                child: Center(
                                  child: Text('No parking history yet', style: TextStyle(color: Colors.grey.shade500)),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildStatsGrid(),
                              const SizedBox(height: 20),
                              const Text('All Visits', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              ..._history.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildRow(e),
                                  )),
                            ],
                          ),
                  ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final rating = _averageRating;
    final stats = <_StatTile>[
      _StatTile(label: 'Total Visits', value: '$_totalVisits', icon: Icons.directions_car_filled, color: Colors.blue),
      _StatTile(label: 'This Month', value: '$_visitsThisMonth', icon: Icons.calendar_month, color: Colors.indigo),
      _StatTile(
        label: 'Avg Rating',
        value: rating != null ? rating.toStringAsFixed(1) : '-',
        icon: Icons.star_rounded,
        color: Colors.amber,
      ),
      _StatTile(label: 'Total Spent', value: 'AED ${_totalSpent.toStringAsFixed(0)}', icon: Icons.payments_outlined, color: Colors.green),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(_StatTile stat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: stat.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(stat.icon, color: stat.color.shade700, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(stat.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                Text(stat.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(CustomerHistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.directions_car, color: Colors.blue.shade400, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ticket ${entry.ticketNo}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '${entry.vehicleColor ?? ''} ${entry.vehicleMake ?? ''} · ${entry.plateNo ?? '-'}'.trim(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (entry.deliveredTime != null)
                  Text(entry.deliveredTime!.split('T').first, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (entry.rating != null)
            Row(
              children: List.generate(5, (i) => Icon(
                    i < entry.rating! ? Icons.star : Icons.star_border,
                    size: 13,
                    color: Colors.amber.shade600,
                  )),
            )
          else
            Chip(
              label: Text(entry.status ?? '-', style: const TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _StatTile {
  final String label;
  final String value;
  final IconData icon;
  final MaterialColor color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});
}
