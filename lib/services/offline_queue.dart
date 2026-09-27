// lib/services/offline_queue.dart
//
// Drivers park cars in basements with no signal. The actions they take down there - saving the
// slot/key holder, condition photos, answering "still on the way?" - are queued on the phone when
// the network fails and sent, in order, as soon as it's back (connectivity change, every 30s, or
// "Send now"). Only network failures are queued; an answer from the server ("slot just taken") is
// shown straight away as before. If a queued action is later rejected by the server, the driver
// gets a notification to redo it - nothing is dropped silently.
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
  final String type; // park_details | photo | eta_checkin
  final Map<String, dynamic> payload;
  final String label; // what the driver sees, e.g. "Parking for ticket 90006"
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

  // ── Enqueue helpers (called after a network failure) ─────────────────
  Future<void> queueParkDetails({required int parkingVehicleId, required String ticketNo, int? slotId, String? bayNo, String? keyHolderNo}) =>
      _add('park_details', {
        'parkingVehicleId': parkingVehicleId,
        if (slotId != null) 'slotId': slotId,
        if (bayNo != null) 'bayNo': bayNo,
        if (keyHolderNo != null) 'keyHolderNo': keyHolderNo,
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
          // Server said no (e.g. slot taken meanwhile): drop it, but tell the driver.
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
    final p = a.payload;
    switch (a.type) {
      case 'park_details':
        await _service.recordParkDetails(
          parkingVehicleId: p['parkingVehicleId'] as int,
          slotId: p['slotId'] as int?,
          bayNo: p['bayNo'] as String?,
          keyHolderNo: p['keyHolderNo'] as String?,
        );
        break;
      case 'photo':
        final path = p['filePath'] as String;
        if (!File(path).existsSync()) return; // file gone - nothing left to send
        await _service.uploadPhoto(p['parkingVehicleId'] as int, path, p['angle'] as String);
        break;
      case 'eta_checkin':
        await _service.etaCheckIn(parkingVehicleId: p['parkingVehicleId'] as int, extendMinutes: p['extendMinutes'] as int);
        break;
    }
  }

  void _cleanupFile(QueuedAction a) {
    if (a.type != 'photo') return;
    try {
      File(a.payload['filePath'] as String).deleteSync();
    } catch (_) {}
  }
}
