// lib/pages/find_my_car_page.dart
//
// Driver's "Find my car": everything needed to walk straight to a parked car - slot (or bay),
// area, floor and building, the key hook, how long it has been parked, and the check-in photos so
// the car can be recognised across the car park. Opened from My Deliveries and from a ticket
// lookup on the driver desk.
import 'package:flutter/material.dart';
import '../components/condition_photos.dart';
import '../services/valet_service.dart';
import '../theme/app_theme.dart';

class FindMyCarPage extends StatefulWidget {
  final int parkingVehicleId;
  final String ticketNo;
  const FindMyCarPage({super.key, required this.parkingVehicleId, required this.ticketNo});

  static Future<void> open(BuildContext context, {required int parkingVehicleId, required String ticketNo}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FindMyCarPage(parkingVehicleId: parkingVehicleId, ticketNo: ticketNo),
      ));

  @override
  State<FindMyCarPage> createState() => _FindMyCarPageState();
}

class _FindMyCarPageState extends State<FindMyCarPage> {
  final ValetService _service = ValetService();
  VehicleWhere? _where;
  String? _error;
  bool _loading = true;

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
      final w = await _service.fetchWhere(widget.parkingVehicleId);
      if (mounted) setState(() => _where = w);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _parkedFor(String? iso) {
    final start = iso == null ? null : DateTime.tryParse(iso);
    if (start == null) return '-';
    final d = DateTime.now().difference(start);
    if (d.isNegative) return 'just now';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes} min';
  }

  static String _clock(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Find car · ${widget.ticketNo}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading && _where == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _where == null)
              Text(_error!, style: TextStyle(color: AppColors.danger))
            else if (_where != null) ...[
              _locationCard(_where!),
              const SizedBox(height: 12),
              _keyAndTimeRow(_where!),
              const SizedBox(height: 16),
              Text('Check-in photos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ConditionPhotosGrid(parkingVehicleId: widget.parkingVehicleId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationCard(VehicleWhere w) {
    final car = [w.vehicleColor, w.vehicleMake, w.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
    final spot = w.slotNumber ?? w.bayNo;
    final rows = <MapEntry<String, String>>[
      if (w.building != null && w.building!.isNotEmpty) MapEntry('Building', w.building!),
      if (w.floor != null && w.floor!.isNotEmpty) MapEntry('Floor', w.floor!),
      if (w.zone != null && w.zone!.isNotEmpty) MapEntry('Zone', w.zone!),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_filled, color: AppColors.liveOnDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(car.isEmpty ? 'Vehicle' : car,
                    style: const TextStyle(color: AppColors.inkText, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.plateBg, borderRadius: BorderRadius.circular(4)),
                child: Text(w.plateNo ?? '-', style: AppTheme.mono(size: 14, color: AppColors.plateFg)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(w.slotNumber != null ? 'SLOT' : 'BAY',
              style: const TextStyle(color: AppColors.inkTextSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          Text(spot == null || spot.isEmpty ? 'Not recorded' : spot,
              style: AppTheme.numeral(size: spot == null || spot.isEmpty ? 28 : 56, color: AppColors.brassOnDark)),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: rows
                  .map((r) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.key.toUpperCase(),
                              style: const TextStyle(color: AppColors.inkTextSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          Text(r.value, style: const TextStyle(color: AppColors.inkText, fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ))
                  .toList(),
            ),
          ],
          if (w.parkingLocation != null && w.parkingLocation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: AppColors.inkTextSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(w.parkingLocation!, style: const TextStyle(color: AppColors.inkTextBody, fontSize: 13))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _keyAndTimeRow(VehicleWhere w) {
    Widget tile(IconData icon, String label, String value, String? sub) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(value, style: AppTheme.numeral(size: 28, color: AppColors.textPrimary)),
                if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
    final key = w.keyHolderNo;
    return Row(
      children: [
        tile(Icons.vpn_key_outlined, 'Key hook', key == null || key.isEmpty ? '-' : key,
            key == null || key.isEmpty ? 'Not recorded' : null),
        const SizedBox(width: 10),
        tile(Icons.schedule, 'Parked for', _parkedFor(w.parkingInTime), 'since ${_clock(w.parkingInTime)}'),
      ],
    );
  }
}
