// lib/components/live_tracking_card.dart
//
// The customer's "your car is on the way" card. Live: the driver's position is pushed to the app
// the moment their phone reports it (LiveTrackStream, Server-Sent Events) and the car glides to
// each new point along the route drawn so far. The ETA is always shown: from the driver's GPS
// when a recent fix exists (straight-line estimate, see EtaUtil.java), otherwise from the dispatch
// schedule plus any time the driver added. A position that stops updating is kept on the map as
// "last known" with its age. Free OpenStreetMap tiles via flutter_map - no API key needed.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../services/live_track_stream.dart';
import '../services/valet_service.dart';
import '../l10n/app_strings.dart';

class LiveTrackingCard extends StatefulWidget {
  final TicketStatusResponse data;
  // Called when the server pushes a status/ETA change, so the parent refetches the full status.
  final VoidCallback? onRefresh;

  const LiveTrackingCard({super.key, required this.data, this.onRefresh});

  @override
  State<LiveTrackingCard> createState() => _LiveTrackingCardState();
}

class _LiveTrackingCardState extends State<LiveTrackingCard> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // A position older than this is shown as "last known" (grey car, low-signal note) rather than
  // hidden - underground car parks drop GPS, and a last-seen pin reassures more than nothing.
  static const int _liveMaxAgeSeconds = 120;
  // Past this, "underground car park" stops being a believable reason - point the guest to the desk.
  static const int _overdueAgeSeconds = 30 * 60;

  LiveTrackStream? _stream;
  StreamSubscription<LiveEvent>? _sub;
  bool _connected = false;
  final List<ll.LatLng> _trail = [];
  ll.LatLng? _livePoint; // latest pushed fix
  DateTime? _livePointAt;
  DateTime _dataAt = DateTime.now(); // when widget.data (and its server-computed age) arrived
  Timer? _tick;

  // Glide between fixes.
  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  ll.LatLng? _from;
  ll.LatLng? _to;

  TicketStatusResponse get data => widget.data;

  @override
  void initState() {
    super.initState();
    _glide.addListener(() => setState(() {}));
    _startStream();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant LiveTrackingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _dataAt = DateTime.now();
    if (oldWidget.data.ticketNo != data.ticketNo || oldWidget.data.companyCode != data.companyCode) {
      _stopStream();
      _trail.clear();
      _livePoint = null;
      _startStream();
    }
    // A polled position newer than the last pushed one (e.g. stream not connected).
    final lat = data.driverLat, lng = data.driverLng;
    if (lat != null && lng != null && (_livePoint == null || (data.driverLocationAgeSeconds ?? 999) == 0)) {
      _moveTo(ll.LatLng(lat, lng));
    }
  }

  void _startStream() {
    final code = data.companyCode;
    if (code == null || code.isEmpty) return;
    final stream = _stream = LiveTrackStream(code, data.ticketNo);
    _sub = stream.events.listen((e) {
      if (!mounted) return;
      switch (e.name) {
        case 'ready':
          setState(() => _connected = true);
          break;
        case 'position':
          final p = ll.LatLng((e.data['lat'] as num).toDouble(), (e.data['lng'] as num).toDouble());
          _livePointAt = DateTime.now();
          _trail.add(p);
          if (_trail.length > 300) _trail.removeAt(0);
          _moveTo(p);
          break;
        case 'status':
        case 'eta':
          widget.onRefresh?.call();
          break;
      }
    });
    stream.start();
    stream.trail().then((points) {
      if (!mounted || points.isEmpty) return;
      setState(() {
        _trail
          ..clear()
          ..addAll(points.map((p) => ll.LatLng(p[0], p[1])));
      });
    });
  }

  void _stopStream() {
    _sub?.cancel();
    _stream?.close();
    _stream = null;
    _connected = false;
  }

  void _moveTo(ll.LatLng target) {
    final current = _shownPoint();
    _livePoint = target;
    if (current == null || const ll.Distance().as(ll.LengthUnit.Meter, current, target) > 2000) {
      _from = target;
      _to = target;
      _glide.value = 1;
    } else {
      _from = current;
      _to = target;
      _glide.forward(from: 0);
    }
    if (_mapReady) {
      final bounds = _mapController.camera.visibleBounds;
      if (!bounds.contains(target)) _mapController.move(target, _mapController.camera.zoom);
    }
  }

  ll.LatLng? _shownPoint() {
    if (_from != null && _to != null) {
      final t = Curves.easeInOut.transform(_glide.value);
      return ll.LatLng(
        _from!.latitude + (_to!.latitude - _from!.latitude) * t,
        _from!.longitude + (_to!.longitude - _from!.longitude) * t,
      );
    }
    final lat = data.driverLat, lng = data.driverLng;
    return lat != null && lng != null ? ll.LatLng(lat, lng) : null;
  }

  // Age of the shown position right now (server age at the last refresh, or since the last push).
  int? _ageNow() {
    final pushed = _livePointAt;
    if (pushed != null && pushed.isAfter(_dataAt.subtract(const Duration(seconds: 1)))) {
      return DateTime.now().difference(pushed).inSeconds;
    }
    final server = data.driverLocationAgeSeconds;
    return server == null ? null : server + DateTime.now().difference(_dataAt).inSeconds;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stopStream();
    _glide.dispose();
    super.dispose();
  }

  String _freshnessLabel(int? age) {
    if (age == null) return '';
    if (age < 60) return tr(context, 'Updated {n}s ago', {'n': age});
    final minutes = (age / 60).floor();
    if (minutes < 60) return tr(context, 'Updated {n} min ago', {'n': minutes});
    return tr(context, 'Updated {h} h {m} min ago', {'h': minutes ~/ 60, 'm': minutes % 60});
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
    final point = _shownPoint();
    final hasPosition = point != null;
    final age = _ageNow();
    final isLive = hasPosition && (age == null || age <= _liveMaxAgeSeconds);
    if (!hasPosition) _mapReady = false; // the map (and its controller binding) is being dropped
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
          if (hasPosition)
            SizedBox(
              height: 220,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                  onMapReady: () => _mapReady = true,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.focalsoft.fsvalet.fs_valetfusion',
                  ),
                  if (_trail.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: List.of(_trail), strokeWidth: 4, color: Colors.indigo.withValues(alpha: 0.55)),
                    ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
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
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          if (hasPosition)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: isLive ? Colors.green.shade600 : Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Text(tr(context, isLive ? 'Live location' : 'Last known position'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (isLive && _connected) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text(tr(context, 'LIVE'),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green.shade700, letterSpacing: 0.6)),
                    ),
                  ],
                  const Spacer(),
                  Text(_freshnessLabel(age),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          if (hasPosition && !isLive)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                (age ?? 0) > _overdueAgeSeconds
                    ? tr(context, "This is taking longer than usual. If you're already at the lobby, please ask the valet desk for an update.")
                    : tr(context, 'Your driver may be in an underground car park or a low-signal area. The position updates as soon as their phone reconnects - your car is on its way.'),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
