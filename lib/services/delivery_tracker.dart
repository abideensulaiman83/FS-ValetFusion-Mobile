// lib/services/delivery_tracker.dart
//
// App-level companion for a DRIVER with cars on the way to the guest. Lives outside any one
// screen so it keeps working when the driver switches tabs, locks the phone, or has Maps open:
//
//  * Polls /my-deliveries every 20s and publishes the list (MyDeliveriesSection renders it).
//  * While any delivery is ONTHEWAY, runs geolocator's position stream as an Android foreground
//    service ("Sharing your location...") and uploads the fix every ~15s, so the customer's live
//    map and GPS ETA keep moving in the background.
//  * Every 5 minutes (the server decides via checkInDue) asks "Still on the way?" - a dialog when
//    the app is open, a full-screen notification when it isn't - and sends the answer (+5/+10/
//    +15/+20 min, on time, or arrived) to /eta-checkin, which updates the customer's ETA.
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../components/eta_check_in_dialog.dart';
import 'notification_service.dart';
import 'valet_service.dart';

class DeliveryTracker with WidgetsBindingObserver {
  DeliveryTracker._();
  static final DeliveryTracker instance = DeliveryTracker._();

  static const Duration _pollEvery = Duration(seconds: 20);
  static const Duration _uploadEvery = Duration(seconds: 15);

  final ValetService _valetService = ValetService();

  final ValueNotifier<List<TicketStatusResponse>> deliveries = ValueNotifier(const []);
  final ValueNotifier<bool> loaded = ValueNotifier(false);

  bool _running = false;
  Timer? _pollTimer;
  Timer? _uploadTimer;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AppAlert>? _alertSub;
  Position? _lastFix;
  bool _uploading = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  // Check-in bookkeeping: which car's dialog is open, and when each was last answered (so a poll
  // that lands before the server has recorded the answer doesn't ask again).
  int? _promptingFor;
  final Map<int, DateTime> _answeredAt = {};
  final Set<int> _notifiedDue = {};

  bool get _inForeground => _lifecycle == AppLifecycleState.resumed;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _alertSub = NotificationService.instance.alerts.listen(_onAlert);
    NotificationService.instance.requestPermissions();
    refresh();
    _pollTimer = Timer.periodic(_pollEvery, (_) => refresh());
  }

  /// Logout: stop GPS, timers and listeners, and forget everything.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pollTimer = null;
    await _alertSub?.cancel();
    _alertSub = null;
    await _stopGps();
    _answeredAt.clear();
    _notifiedDue.clear();
    _promptingFor = null;
    deliveries.value = const [];
    loaded.value = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) refresh();
  }

  void _onAlert(AppAlert alert) {
    if (alert.type == 'ETA_CHECK_IN' || alert.type == 'DELIVERY_ASSIGNED') {
      if (alert.type == 'ETA_CHECK_IN' && alert.parkingVehicleId != null) {
        // A push (or tap on one) means the server wants an answer now.
        _answeredAt.remove(alert.parkingVehicleId);
      }
      refresh();
    }
  }

  Future<void> refresh() async {
    if (!_running) return;
    try {
      final list = await _valetService.fetchMyDeliveries();
      deliveries.value = list;
      loaded.value = true;
      await _syncGps(list);
      _checkIns(list);
    } catch (e) {
      // Keep showing the last list; the next poll will retry.
      developer.log('My deliveries refresh failed: $e');
      loaded.value = true;
    }
  }

  List<TicketStatusResponse> get _onTheWay =>
      deliveries.value.where((d) => d.status == 'ONTHEWAY' && d.parkingVehicleId != null).toList();

  // ---- GPS ----

  Future<void> _syncGps(List<TicketStatusResponse> list) async {
    final anyOnTheWay = list.any((d) => d.status == 'ONTHEWAY');
    if (anyOnTheWay && _positionSub == null) {
      await _startGps();
    } else if (!anyOnTheWay && _positionSub != null) {
      await _stopGps();
    }
  }

  Future<void> _startGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Delivering a car',
          notificationText: 'Sharing your location with the guest until you hand the car over.',
          notificationChannelName: 'Delivery location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
      _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) => _lastFix = position,
        onError: (e) => developer.log('Position stream error: $e'),
      );
      _uploadTimer = Timer.periodic(_uploadEvery, (_) => _upload());
      // First fix straight away so the customer's map doesn't wait 15s.
      Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
          .then((p) {
        _lastFix = p;
        _upload();
      }).catchError((_) {});
    } catch (e) {
      developer.log('Could not start delivery GPS: $e');
    }
  }

  Future<void> _stopGps() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _lastFix = null;
  }

  Future<void> _upload() async {
    final fix = _lastFix;
    if (fix == null || _uploading) return;
    _uploading = true;
    try {
      for (final d in _onTheWay) {
        await _valetService.updateDriverLocation(
          parkingVehicleId: d.parkingVehicleId!,
          lat: fix.latitude,
          lng: fix.longitude,
        );
      }
    } catch (e) {
      // One missed ping only means a slightly older fix on the guest's map.
      developer.log('Location upload failed: $e');
    } finally {
      _uploading = false;
    }
  }

  // ---- "Still on the way?" ----

  void _checkIns(List<TicketStatusResponse> list) {
    final due = list.where((d) {
      if (d.status != 'ONTHEWAY' || !d.checkInDue || d.parkingVehicleId == null) return false;
      final answered = _answeredAt[d.parkingVehicleId!];
      return answered == null || DateTime.now().difference(answered) > const Duration(minutes: 2);
    }).toList();

    // Forget notifications for cars that are no longer due.
    _notifiedDue.removeWhere((id) => !due.any((d) => d.parkingVehicleId == id));
    if (due.isEmpty) return;

    if (!_inForeground) {
      for (final d in due) {
        if (_notifiedDue.add(d.parkingVehicleId!)) {
          NotificationService.instance.show(AppAlert(
            type: 'ETA_CHECK_IN',
            title: 'Still on the way?',
            body: 'Ticket ${d.ticketNo} · ${d.plateNo ?? ''} - tap to confirm or add more time for the guest.',
            parkingVehicleId: d.parkingVehicleId,
            ticketNo: d.ticketNo,
          ));
        }
      }
      return;
    }
    if (_promptingFor == null) promptCheckIn(due.first);
  }

  /// Opens the check-in dialog for [d] (also used by the "Update ETA" button on the card).
  Future<void> promptCheckIn(TicketStatusResponse d) async {
    final context = NotificationService.navigatorKey.currentContext;
    final id = d.parkingVehicleId;
    if (context == null || id == null || _promptingFor != null) return;
    _promptingFor = id;
    try {
      final choice = await showEtaCheckInDialog(context, d);
      if (choice == null) return;
      _answeredAt[id] = DateTime.now();
      _notifiedDue.remove(id);
      NotificationService.instance.cancelFor(id);
      String message;
      if (choice.arrived) {
        await _valetService.arriveVehicle(id);
        message = 'Marked as arrived - the guest has been told.';
      } else {
        message = await _valetService.etaCheckIn(parkingVehicleId: id, extendMinutes: choice.extendMinutes);
      }
      _snack(message);
      await refresh();
    } catch (e) {
      _answeredAt.remove(id);
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      _promptingFor = null;
    }
  }

  void _snack(String message, {bool error = false}) {
    final context = NotificationService.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }
}
