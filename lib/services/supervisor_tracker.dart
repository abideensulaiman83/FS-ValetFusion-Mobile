// lib/services/supervisor_tracker.dart
//
// Keeps a SUPERVISOR's position flowing to head office from check-in to check-out, like
// DeliveryTracker does for drivers: geolocator's position stream as an Android foreground service
// ("On duty at <site>" notification) or iPhone background location, uploading the latest fix every
// pingIntervalSec (company setting). If the app is closed or the phone loses data the reports stop
// and the server shows "No signal" - reopening the app picks the open visit up and resumes.
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'supervisor_service.dart';

class SupervisorTracker with WidgetsBindingObserver {
  SupervisorTracker._();
  static final SupervisorTracker instance = SupervisorTracker._();

  final SupervisorService _api = SupervisorService();

  /// Latest status from the server (null until loaded).
  final ValueNotifier<SupervisorMe?> me = ValueNotifier(null);
  /// The open visit as last reported back by a position upload (on site / distance).
  final ValueNotifier<SupervisorVisit?> visit = ValueNotifier(null);

  bool _running = false;
  StreamSubscription<Position>? _positionSub;
  Timer? _uploadTimer;
  Position? _lastFix;
  bool _uploading = false;
  String? _trackingSite;

  Future<void> start() async {
    if (!_running) {
      _running = true;
      WidgetsBinding.instance.addObserver(this);
    }
    await refresh();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    await _stopGps();
    me.value = null;
    visit.value = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final status = await _api.me();
    me.value = status;
    visit.value = status.openVisit;
    if (status.openVisit != null) {
      await _startGps(status.openVisit!.locationName, status.pingIntervalSec);
    } else {
      await _stopGps();
    }
  }

  /// One-off fix for check-in / check-out. Null when location is off or denied.
  static Future<Position?> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
    } catch (e) {
      developer.log('Supervisor fix failed: $e');
      return null;
    }
  }

  Future<void> _startGps(String siteName, int intervalSec) async {
    if (_positionSub != null && _trackingSite == siteName) return;
    await _stopGps();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final LocationSettings settings = Platform.isIOS
          ? AppleSettings(
              accuracy: LocationAccuracy.high,
              activityType: ActivityType.other,
              distanceFilter: 10,
              pauseLocationUpdatesAutomatically: false,
              allowBackgroundLocationUpdates: true,
              showBackgroundLocationIndicator: true,
            )
          : AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 10),
              foregroundNotificationConfig: ForegroundNotificationConfig(
                notificationTitle: 'On duty at $siteName',
                notificationText: 'Sharing your location with head office until you check out.',
                notificationChannelName: 'Supervisor duty',
                enableWakeLock: true,
                setOngoing: true,
              ),
            );
      _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) => _lastFix = p,
        onError: (e) => developer.log('Supervisor position stream error: $e'),
      );
      _trackingSite = siteName;
      _uploadTimer = Timer.periodic(Duration(seconds: intervalSec.clamp(15, 900)), (_) => _upload());
    } catch (e) {
      developer.log('Could not start supervisor GPS: $e');
    }
  }

  Future<void> _stopGps() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _lastFix = null;
    _trackingSite = null;
  }

  Future<void> _upload() async {
    final fix = _lastFix;
    if (fix == null || _uploading) return;
    _uploading = true;
    try {
      visit.value = await _api.ping(fix.latitude, fix.longitude, fix.accuracy);
    } catch (e) {
      // A missed report only shows as a short gap; if we are no longer checked in, stop.
      developer.log('Supervisor report failed: $e');
      if (e.toString().contains('Not checked in')) await refresh();
    } finally {
      _uploading = false;
    }
  }
}
