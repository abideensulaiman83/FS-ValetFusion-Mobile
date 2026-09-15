// lib/components/wash_requests_section.dart
//
// Key Controller and Driver both see this - a customer's "Request a Wash" tap shows up here
// (polled every 20s, since there's no push-notification infra wired up yet) so it can be picked
// up and marked done. Shared between both roles' screens rather than duplicated.
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/valet_service.dart';

class WashRequestsSection extends StatefulWidget {
  const WashRequestsSection({super.key});

  @override
  State<WashRequestsSection> createState() => _WashRequestsSectionState();
}

class _WashRequestsSectionState extends State<WashRequestsSection> {
  final ValetService _valetService = ValetService();
  List<TicketStatusResponse> _requests = [];
  bool _loading = true;
  Timer? _timer;
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final requests = await _valetService.fetchWashRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (_) {
      // Non-fatal on background refresh.
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(TicketStatusResponse r, String status) async {
    if (r.parkingVehicleId == null) return;
    setState(() => _acting.add(r.parkingVehicleId!));
    try {
      await _valetService.updateWashStatus(parkingVehicleId: r.parkingVehicleId!, status: status);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _acting.remove(r.parkingVehicleId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CircularProgressIndicator()));
    }
    if (_requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.local_car_wash, color: Colors.teal.shade600, size: 18),
            const SizedBox(width: 6),
            Text('Wash Requests (${_requests.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          ],
        ),
        const SizedBox(height: 10),
        for (final r in _requests) ...[
          _buildCard(r),
          const SizedBox(height: 10),
        ],
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildCard(TicketStatusResponse r) {
    final isActing = r.parkingVehicleId != null && _acting.contains(r.parkingVehicleId);
    final inProgress = r.washStatus == 'IN_PROGRESS';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ticket ${r.ticketNo} · Bay ${r.bayNo ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${r.vehicleColor ?? ''} ${r.vehicleMake ?? ''} · ${r.plateNo ?? ''}'.trim(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (isActing)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (!inProgress)
            OutlinedButton(
              onPressed: () => _updateStatus(r, 'IN_PROGRESS'),
              child: const Text('Start'),
            )
          else
            ElevatedButton(
              onPressed: () => _updateStatus(r, 'DONE'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}
