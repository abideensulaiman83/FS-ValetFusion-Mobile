// lib/components/live_tracking_card.dart
//
// Shows the assigned driver's live position (pushed by the Driver app while ONTHEWAY) on a free
// OpenStreetMap tile layer via flutter_map - no API key needed, unlike Google Maps. Distance/ETA
// is a straight-line estimate from the backend (see EtaUtil.java), not turn-by-turn routing: a
// valet's drive from a bay back to the lobby is a short trip inside one property where an
// external routing API's road-network directions don't really apply anyway.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../services/valet_service.dart';

class LiveTrackingCard extends StatelessWidget {
  final TicketStatusResponse data;

  const LiveTrackingCard({super.key, required this.data});

  String _freshnessLabel() {
    final updatedAt = data.driverLocationUpdatedAt;
    if (updatedAt == null) return '';
    try {
      final dt = DateTime.parse(updatedAt);
      final ageSeconds = DateTime.now().difference(dt).inSeconds;
      if (ageSeconds < 60) return 'Updated ${ageSeconds}s ago';
      return 'Updated ${(ageSeconds / 60).floor()}m ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPosition = data.driverLat != null && data.driverLng != null;
    if (!hasPosition) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_car_filled, color: Colors.blue.shade400),
            const SizedBox(width: 10),
            const Expanded(child: Text('Your driver is on the way - live location will appear here shortly.')),
          ],
        ),
      );
    }

    final point = ll.LatLng(data.driverLat!, data.driverLng!);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.focalsoft.fsvalet.fs_valetfusion',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.directions_car, color: Colors.indigo, size: 34),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Colors.indigo.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.etaMinutes != null
                        ? 'Approx. ${data.etaMinutes} min away'
                        : 'Vehicle location live',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Text(_freshnessLabel(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
