// lib/components/live_tracking_card.dart
//
// The customer's "your car is on the way" card. The ETA is always shown: from the driver's live
// GPS when a recent fix exists (straight-line estimate, see EtaUtil.java), otherwise from the
// dispatch schedule (the property's typical delivery time, plus any extra minutes the driver
// added when asked "still on the way?"). The map appears once the driver's phone has sent a
// position, on free OpenStreetMap tiles via flutter_map - no API key needed.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../services/valet_service.dart';
import '../l10n/app_strings.dart';

class LiveTrackingCard extends StatefulWidget {
  final TicketStatusResponse data;

  const LiveTrackingCard({super.key, required this.data});

  @override
  State<LiveTrackingCard> createState() => _LiveTrackingCardState();
}

class _LiveTrackingCardState extends State<LiveTrackingCard> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  TicketStatusResponse get data => widget.data;

  @override
  void didUpdateWidget(covariant LiveTrackingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lat = data.driverLat, lng = data.driverLng;
    if (_mapReady && lat != null && lng != null &&
        (lat != oldWidget.data.driverLat || lng != oldWidget.data.driverLng)) {
      // Follow the car as new fixes arrive.
      _mapController.move(ll.LatLng(lat, lng), _mapController.camera.zoom);
    }
  }

  // A position older than this is shown as "last known" (grey car, low-signal note) rather than
  // hidden - underground car parks drop GPS, and a last-seen pin reassures more than nothing.
  static const int _liveMaxAgeSeconds = 120;

  // Age is computed by the server, so a phone clock that's off doesn't skew it.
  String _freshnessLabel() {
    final age = data.driverLocationAgeSeconds;
    if (age == null) return '';
    if (age < 60) return tr(context, 'Updated {n}s ago', {'n': age});
    return tr(context, 'Updated {n} min ago', {'n': (age / 60).floor()});
  }

  String _etaHeadline() {
    final eta = data.etaMinutes;
    if (eta == null) return tr(context, 'On the way');
    if (eta <= 1) return tr(context, 'Arriving now');
    return tr(context, '{n} min', {'n': eta});
  }

  String _etaSubline() {
    final eta = data.etaMinutes;
    if (eta == null) return tr(context, 'Your driver is bringing the car to you.');
    final source = data.etaSource == 'GPS' ? tr(context, 'Based on your driver\'s live location') : tr(context, 'Estimated arrival time');
    final extended = (data.etaExtendedCount ?? 0) > 0 ? tr(context, ' · updated by your driver') : '';
    return '$source$extended';
  }

  @override
  Widget build(BuildContext context) {
    final hasPosition = data.driverLat != null && data.driverLng != null;
    final isLive = hasPosition && (data.driverLocationAgeSeconds == null || data.driverLocationAgeSeconds! <= _liveMaxAgeSeconds);
    final positionFresh = hasPosition; // shown however old - labelled live / last known below
    if (!positionFresh) _mapReady = false; // the map (and its controller binding) is being dropped
    final extendedMin = data.etaExtendedMinutes ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (extendedMin > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                tr(context, 'Your driver added {n} min to the arrival time', {'n': extendedMin}) +
                    (data.etaExtendedAgoMinutes == null
                        ? ''
                        : ' · ${data.etaExtendedAgoMinutes! < 1 ? tr(context, 'just now') : tr(context, '{n} min ago', {'n': data.etaExtendedAgoMinutes})}'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.timer_outlined, color: Colors.indigo.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, 'Estimated arrival'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(
                        _etaHeadline(),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.indigo.shade800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(_etaSubline(), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (positionFresh)
            SizedBox(
              height: 200,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: ll.LatLng(data.driverLat!, data.driverLng!),
                  initialZoom: 16,
                  onMapReady: () => _mapReady = true,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.focalsoft.fsvalet.fs_valetfusion',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: ll.LatLng(data.driverLat!, data.driverLng!),
                      width: 44,
                      height: 44,
                      child: Icon(Icons.directions_car, color: isLive ? Colors.indigo : Colors.blueGrey, size: 34),
                    ),
                  ]),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.location_searching, size: 18, color: Colors.blue.shade400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr(context, 'The live map appears as soon as your driver\'s location comes through.'),
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          if (positionFresh)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: isLive ? Colors.green.shade600 : Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(tr(context, isLive ? 'Live location' : 'Last known position'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Text(_freshnessLabel(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          if (positionFresh && !isLive)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                tr(context, 'Your driver may be in an underground car park or a low-signal area. The position updates as soon as their phone reconnects - your car is on its way.'),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
