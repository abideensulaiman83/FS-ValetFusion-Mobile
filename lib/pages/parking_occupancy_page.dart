// lib/pages/parking_occupancy_page.dart
//
// A genuine parking-management view, not just the valet pickup flow - every currently parked
// vehicle (status RECEIVED), which bay it's in, and how long it's been parked. This is the kind
// of "which bays are occupied" visibility a property manager actually needs day to day, distinct
// from the ticket-by-ticket valet desk.
import 'package:flutter/material.dart';
import '../services/valet_service.dart';

class ParkingOccupancyPage extends StatefulWidget {
  const ParkingOccupancyPage({super.key});

  @override
  State<ParkingOccupancyPage> createState() => _ParkingOccupancyPageState();
}

class _ParkingOccupancyPageState extends State<ParkingOccupancyPage> {
  final _valetService = ValetService();
  List<TicketStatusResponse> _parked = [];
  bool _loading = true;
  String? _error;
  String _search = '';

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
      final parked = await _valetService.fetchByStatus('RECEIVED');
      if (mounted) setState(() => _parked = parked);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _durationSince(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final start = DateTime.parse(isoTime);
      final diff = DateTime.now().difference(start);
      if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      return '${diff.inMinutes}m';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _parked
        : _parked.where((p) =>
            (p.ticketNo.toLowerCase().contains(_search.toLowerCase())) ||
            (p.plateNo?.toLowerCase().contains(_search.toLowerCase()) ?? false) ||
            (p.bayNo?.toLowerCase().contains(_search.toLowerCase()) ?? false)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Parking Occupancy')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    Icon(Icons.local_parking, color: Colors.indigo.shade600),
                                    const SizedBox(width: 10),
                                    Text('${_parked.length} vehicles currently parked',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo.shade800)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Search ticket, plate or bay',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(child: Text('No parked vehicles found', style: TextStyle(color: Colors.grey.shade500)))
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) => _buildRow(filtered[i]),
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildRow(TicketStatusResponse p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text(p.bayNo ?? '-', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.indigo.shade700, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ticket ${p.ticketNo}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text('${p.vehicleColor ?? ''} ${p.vehicleMake ?? ''} · ${p.plateNo ?? '-'}'.trim(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_durationSince(p.parkingInTime), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              Text('parked', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}
