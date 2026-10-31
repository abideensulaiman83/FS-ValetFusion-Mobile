// lib/services/offline_queue.dart
//
// Drivers park cars in basements with no signal, and the desk loses Wi-Fi too. Every step that
// moves a car along - request, dispatch, arrived, handed over, parking slot, key holder - plus
// condition photos and "still on the way?" answers is queued on the phone when the network
// fails and sent, in order, as soon as it's back (connectivity change, every 30s, or "Send now").
// Each lifecycle step carries a client-made Idempotency-Key (plan E13): if the first try timed
// out after the server had already done it, the replay gets the original answer back instead of
// "already delivered". Only network failures are queued; an answer from the server ("slot just
// taken") is shown straight away as before. If a queued action is later rejected by the server,
// the user gets a notification to redo it - nothing is dropped silently.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'valet_service.dart';

bool isNetworkError(Object e) =>
    e is SocketException || e is TimeoutException || e is http.ClientException || e is HandshakeException;

class QueuedAction {
  final String id;
  // park_details | photo | eta_checkin | request | dispatch | arrive | deliver | key_holder
  final String type;
  final Map<String, dynamic> payload;
  final String label; // what the user sees, e.g. "Parking for ticket 90006"
  final String createdAt;

  QueuedAction({required this.id, required this.type, required this.payload, required this.label, required this.createdAt});

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'payload': payload, 'label': label, 'createdAt': createdAt};

  factory QueuedAction.fromJson(Map<String, dynamic> j) => QueuedAction(
        id: j['id'] as String,
        type: j['type'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        label: j['label'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
      );

  int? get parkingVehicleId => payload['parkingVehicleId'] as int?;
}

/// What happened to an action passed to [OfflineQueue.sendOrQueue].
class SendOutcome {
  final bool queued; // true: no signal, saved on the phone for later
  final String? message; // the server's message when it was sent now
  const SendOutcome._(this.queued, this.message);
}

class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const String _key = 'vf_offline_queue';
  final ValetService _service = ValetService();

  /// Pending actions, for the "waiting to sync" banner.
  final ValueNotifier<List<QueuedAction>> pending = ValueNotifier(const []);

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;

  Future<void> start() async {
    await _load();
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    flush();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      pending.value = (jsonDecode(raw) as List).map((e) => QueuedAction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      pending.value = const [];
    }
  }

  Future<void> _save(List<QueuedAction> items) async {
    pending.value = List.unmodifiable(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((a) => a.toJson()).toList()));
  }

  Future<void> _add(String type, Map<String, dynamic> payload, String label) async {
    await _load();
    final action = QueuedAction(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      payload: payload,
      label: label,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _save([...pending.value, action]);
  }

  /// Sends a lifecycle step now (with a fresh Idempotency-Key) or, with no signal, keeps it on
  /// the phone to send later with that same key. If earlier steps for the same car are still
  /// waiting, this one queues behind them so they reach the server in order. Server refusals
  /// ("slot just taken", wrong status) are rethrown for the screen to show.
  ///
  /// type: request | dispatch | arrive | deliver | park_details | key_holder.
  Future<SendOutcome> sendOrQueue({
    required String type,
    required Map<String, dynamic> payload,
    required String label,
  }) async {
    final p = {...payload, 'idempotencyKey': newIdempotencyKey()};
    final vehicleId = p['parkingVehicleId'];
    if (vehicleId != null && pending.value.any((a) => a.type != 'photo' && a.parkingVehicleId == vehicleId)) {
      await _add(type, p, label);
      flush();
      return const SendOutcome._(true, null);
    }
    try {
      final message = await _sendPayload(type, p);
      return SendOutcome._(false, message);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      await _add(type, p, label);
      return const SendOutcome._(true, null);
    }
  }

  // ── Enqueue helpers (called after a network failure) ─────────────────
  Future<void> queueParkDetails({
    required int parkingVehicleId,
    required String ticketNo,
    int? slotId,
    String? bayNo,
    String? keyHolderNo,
    String? idempotencyKey,
  }) =>
      _add('park_details', {
        'parkingVehicleId': parkingVehicleId,
        if (slotId != null) 'slotId': slotId,
        if (bayNo != null) 'bayNo': bayNo,
        if (keyHolderNo != null) 'keyHolderNo': keyHolderNo,
        'idempotencyKey': idempotencyKey ?? newIdempotencyKey(),
      }, 'Parking location for ticket $ticketNo');

  /// Copies the photo out of the picker's cache (the OS may clear it) before queueing.
  Future<void> queuePhoto({required int parkingVehicleId, required String filePath, required String angle}) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/pending_photos');
    await dir.create(recursive: true);
    final copy = await File(filePath).copy('${dir.path}/pv${parkingVehicleId}_${angle}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await _add('photo', {'parkingVehicleId': parkingVehicleId, 'filePath': copy.path, 'angle': angle},
        '${angle[0]}${angle.substring(1).toLowerCase()} photo');
  }

  Future<void> queueEtaCheckIn({required int parkingVehicleId, required int extendMinutes, required String ticketNo}) =>
      _add('eta_checkin', {'parkingVehicleId': parkingVehicleId, 'extendMinutes': extendMinutes},
          extendMinutes == 0 ? 'On-time update for ticket $ticketNo' : '+$extendMinutes min for ticket $ticketNo');

  /// Photos still waiting for [parkingVehicleId] (shown as "queued" in the photo card).
  List<QueuedAction> pendingPhotosFor(int parkingVehicleId) =>
      pending.value.where((a) => a.type == 'photo' && a.payload['parkingVehicleId'] == parkingVehicleId).toList();

  /// Lifecycle steps still waiting for [parkingVehicleId] (e.g. a handover sent without signal).
  List<QueuedAction> pendingFor(int parkingVehicleId) =>
      pending.value.where((a) => a.type != 'photo' && a.parkingVehicleId == parkingVehicleId).toList();

  // ── Sending ───────────────────────────────────────────────────────────
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _load();
      final queue = [...pending.value];
      while (queue.isNotEmpty) {
        final action = queue.first;
        try {
          await _send(action);
          queue.removeAt(0);
          _cleanupFile(action);
          await _save(queue);
        } catch (e) {
          if (isNetworkError(e)) break; // still offline - keep order, try again later
          // Server said no (e.g. slot taken meanwhile): drop it, but tell the user.
          queue.removeAt(0);
          _cleanupFile(action);
          await _save(queue);
          await NotificationService.instance.show(AppAlert(
            type: 'OFFLINE_REJECTED',
            title: 'Couldn\'t save: ${action.label}',
            body: '${e.toString().replaceAll('Exception: ', '')} - please redo it.',
          ));
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _send(QueuedAction a) async {
    if (a.type == 'photo') {
      final path = a.payload['filePath'] as String;
      if (!File(path).existsSync()) return; // file gone - nothing left to send
      await _service.uploadPhoto(a.payload['parkingVehicleId'] as int, path, a.payload['angle'] as String);
      return;
    }
    await _sendPayload(a.type, a.payload);
  }

  /// Returns the server's message where the endpoint has one.
  Future<String?> _sendPayload(String type, Map<String, dynamic> p) async {
    final id = p['parkingVehicleId'] as int;
    final key = p['idempotencyKey'] as String?;
    switch (type) {
      case 'park_details':
        return _service.recordParkDetails(
          parkingVehicleId: id,
          slotId: p['slotId'] as int?,
          bayNo: p['bayNo'] as String?,
          keyHolderNo: p['keyHolderNo'] as String?,
          idempotencyKey: key,
        );
      case 'eta_checkin':
        return _service.etaCheckIn(parkingVehicleId: id, extendMinutes: p['extendMinutes'] as int);
      case 'request':
        await _service.requestVehicle(
          parkingVehicleId: id,
          requestedRemarks: p['requestedRemarks'] as String? ?? 'Vehicle Requested',
          parkingCharge: (p['parkingCharge'] as num?)?.toDouble() ?? 0,
          shopId: p['shopId'] as int?,
          shopRemarks: p['shopRemarks'] as String?,
          paymentMethod: p['paymentMethod'] as String?,
          idempotencyKey: key,
        );
        return null;
      case 'dispatch':
        await _service.dispatchVehicle(
          parkingVehicleId: id,
          driverId: p['driverId'] as int?,
          vpaOut: p['vpaOut'] as String?,
          idempotencyKey: key,
        );
        return null;
      case 'arrive':
        await _service.arriveVehicle(id, idempotencyKey: key);
        return null;
      case 'deliver':
        await _service.deliverVehicle(id, idempotencyKey: key);
        return null;
      case 'key_holder':
        await _service.assignKeyHolder(
          parkingVehicleId: id,
          keyHolderNo: p['keyHolderNo'] as String,
          idempotencyKey: key,
        );
        return null;
    }
    return null;
  }

  void _cleanupFile(QueuedAction a) {
    if (a.type != 'photo') return;
    try {
      File(a.payload['filePath'] as String).deleteSync();
    } catch (_) {}
  }
}
