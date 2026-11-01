// lib/services/live_alerts.dart
//
// Live alerts: the bell's notifications arrive the moment the backend creates them, instead of
// on the 60-second poll. Our own login stays the identity provider - after sign-in the app swaps
// its session for a Firebase custom token (POST /api/v1/firebase/token, uid "vf-<userId>") and
// listens to Firestore users/<uid>/alerts, which the backend mirrors from every notification.
// Clients only read there (see backend/firebase/firestore.rules); marking read still goes through
// InboxService, and the backend updates the Firestore copy.
//
// Off (silently) when Firebase isn't configured on the phone or the server answers
// {"enabled": false}; the bell's polling keeps working either way.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'authentication_service.dart';
import 'inbox_service.dart';
import 'notification_service.dart';
import 'secure_store.dart';

class LiveAlerts {
  LiveAlerts._();
  static final LiveAlerts instance = LiveAlerts._();

  // Also sent as an FCM push by the backend - showing it again here would double the alert.
  static const Set<String> _pushedTypes = {'DISPATCH_OVERDUE'};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Future<void>? _starting;

  bool get running => _sub != null;

  /// Called after login and on app start when already signed in. Safe to call repeatedly.
  Future<void> start() => _starting ??= _start().whenComplete(() => _starting = null);

  Future<void> _start() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final jwt = await SecureStore.token();
      if (jwt == null) return;
      final r = await http
          .post(Uri.parse('${AuthenticationService.apiBaseUrl}/v1/firebase/token'),
              headers: {'Accept': 'application/json', 'Authorization': 'Bearer $jwt'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (data['enabled'] != true || data['token'] is! String) return;

      final auth = FirebaseAuth.instance;
      final uid = data['uid'] as String;
      // Another user signed in on this phone before - never keep listening as them.
      if (auth.currentUser != null && auth.currentUser!.uid != uid) await auth.signOut();
      await auth.signInWithCustomToken(data['token'] as String);

      await _sub?.cancel();
      var first = true;
      _sub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots()
          .listen((snap) {
        InboxController.instance.refresh();
        // The first snapshot is the backlog - the bell's badge covers it; only new ones pop up.
        if (first) {
          first = false;
          return;
        }
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final a = change.doc.data();
          if (a == null || a['read'] == true) continue;
          final type = '${a['type'] ?? ''}';
          if (_pushedTypes.contains(type) && NotificationService.instance.pushEnabled) continue;
          NotificationService.instance.show(AppAlert(
            type: type,
            title: '${a['title'] ?? 'ValetFusion'}',
            body: '${a['body'] ?? ''}',
            ticketNo: InboxItem(id: 0, severity: 'INFO', title: '', body: a['body'] as String?,
                    link: a['link'] as String?, read: false)
                .ticketNo,
          ));
        }
      }, onError: (Object e) => developer.log('Live alerts listener stopped: $e'));
    } catch (e) {
      developer.log('Live alerts unavailable: $e');
    }
  }

  /// Called on logout so the next person on this phone never sees the previous user's alerts.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
