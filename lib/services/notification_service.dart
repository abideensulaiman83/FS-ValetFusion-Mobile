// lib/services/notification_service.dart
//
// Alerts that must reach the driver/customer even when the app is in the background or the phone
// is locked: the driver's "Still on the way?" reminder, a new delivery assignment, and the
// customer's "your car is on the way / has arrived / ETA changed" updates.
//
// Two delivery paths, so the feature works before Firebase is configured:
//   1. Local notifications (flutter_local_notifications) - fired by the app itself, e.g. the
//      DeliveryTracker's 5-minute check-in while the GPS foreground service keeps it running.
//   2. Firebase Cloud Messaging - the backend's PushNotificationService sends data-only, HIGH
//      priority messages (type, title, body, ticketNo, parkingVehicleId). Enabled only when
//      android/app/google-services.json is present; Firebase.initializeApp() fails otherwise and
//      we simply carry on without push.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication_service.dart';

/// One alert, from either path. [type] matches the backend's push types:
/// DELIVERY_ASSIGNED, ETA_CHECK_IN (driver); ON_THE_WAY, ETA_UPDATED, ARRIVED (customer).
class AppAlert {
  final String type;
  final String title;
  final String body;
  final int? parkingVehicleId;
  final String? ticketNo;
  final bool tapped; // true when the user opened the app from the notification

  AppAlert({
    required this.type,
    required this.title,
    required this.body,
    this.parkingVehicleId,
    this.ticketNo,
    this.tapped = false,
  });

  factory AppAlert.fromData(Map<String, dynamic> data, {bool tapped = false}) {
    return AppAlert(
      type: '${data['type'] ?? ''}',
      title: '${data['title'] ?? 'Valet Fusion'}',
      body: '${data['body'] ?? ''}',
      parkingVehicleId: int.tryParse('${data['parkingVehicleId'] ?? ''}'),
      ticketNo: data['ticketNo']?.toString(),
      tapped: tapped,
    );
  }

  Map<String, dynamic> toData() => {
        'type': type,
        'title': title,
        'body': body,
        if (parkingVehicleId != null) 'parkingVehicleId': '$parkingVehicleId',
        if (ticketNo != null) 'ticketNo': ticketNo,
      };

  /// Types that should wake the screen and pop over whatever is showing.
  bool get urgent => type == 'ETA_CHECK_IN' || type == 'DELIVERY_ASSIGNED' || type == 'ARRIVED';
}

const String _channelId = 'valet_alerts';
const String _channelName = 'Valet alerts';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

Future<void> _initLocal({DidReceiveNotificationResponseCallback? onTap}) async {
  await _local.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: onTap,
  );
  final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'Delivery assignments, "still on the way?" reminders and car status updates',
    importance: Importance.max,
  ));
}

Future<void> _showLocal(AppAlert alert) async {
  await _local.show(
    // One notification per car (a newer alert about the same car replaces the older one).
    id: alert.parkingVehicleId ?? alert.type.hashCode & 0x7fffffff,
    title: alert.title,
    body: alert.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.max,
        category: alert.urgent ? AndroidNotificationCategory.call : AndroidNotificationCategory.status,
        fullScreenIntent: alert.urgent,
        visibility: NotificationVisibility.public,
        ticker: alert.title,
        styleInformation: BigTextStyleInformation(alert.body),
      ),
    ),
    payload: jsonEncode(alert.toData()),
  );
}

// Runs in a separate isolate when a push arrives while the app is killed or in the background.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _initLocal();
    await _showLocal(AppAlert.fromData(message.data));
  } catch (e) {
    developer.log('Background push failed: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Set on MaterialApp so alerts can show dialogs without a BuildContext of their own.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final StreamController<AppAlert> _alerts = StreamController<AppAlert>.broadcast();

  /// Every alert that reaches the running app - pushes received in the foreground, and taps on
  /// notifications. DeliveryTracker listens for ETA_CHECK_IN / DELIVERY_ASSIGNED here.
  Stream<AppAlert> get alerts => _alerts.stream;

  bool _initialized = false;
  bool _pushEnabled = false;
  bool get pushEnabled => _pushEnabled;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _initLocal(onTap: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _alerts.add(AppAlert.fromData(jsonDecode(payload) as Map<String, dynamic>, tapped: true));
        } catch (_) {}
      });
      final launch = await _local.getNotificationAppLaunchDetails();
      final launchPayload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && launchPayload != null) {
        // Delay so listeners (set up by the first screen) are attached before we emit.
        Future.delayed(const Duration(seconds: 2), () {
          try {
            _alerts.add(AppAlert.fromData(jsonDecode(launchPayload) as Map<String, dynamic>, tapped: true));
          } catch (_) {}
        });
      }
    } catch (e) {
      developer.log('Local notifications unavailable: $e');
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message) {
        final alert = AppAlert.fromData(message.data);
        _alerts.add(alert);
        // Still show it in the shade - the driver may be looking at the map, not the app.
        _showLocal(alert);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _alerts.add(AppAlert.fromData(message.data, tapped: true));
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) => _sendToken(token));
      _pushEnabled = true;
    } catch (e) {
      // No google-services.json yet - push stays off, local reminders still work.
      developer.log('Firebase not configured, push disabled: $e');
    }
  }

  /// Ask for the Android 13+ notification permission (and full-screen intent on 14+).
  Future<void> requestPermissions() async {
    try {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  /// Show an alert from inside the app (e.g. the tracker's own 5-minute reminder).
  Future<void> show(AppAlert alert) async {
    try {
      await _showLocal(alert);
    } catch (e) {
      developer.log('Could not show notification: $e');
    }
  }

  Future<void> cancelFor(int parkingVehicleId) async {
    try {
      await _local.cancel(id: parkingVehicleId);
    } catch (_) {}
  }

  /// Called after login (and on app start when already logged in) so the backend can push to
  /// this phone. No-op until Firebase is configured.
  Future<void> registerDevice() async {
    if (!_pushEnabled) return;
    await requestPermissions();
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(token);
    } catch (e) {
      developer.log('FCM token registration failed: $e');
    }
  }

  /// Called on logout (while the auth token is still stored) so the next person to sign in on
  /// this phone doesn't receive the previous user's alerts.
  Future<void> unregisterDevice() async {
    if (!_pushEnabled) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _post('/devices/unregister', {'token': token});
    } catch (e) {
      developer.log('FCM token unregister failed: $e');
    }
  }

  Future<void> _sendToken(String token) async {
    try {
      await _post('/devices/register', {'token': token, 'platform': Platform.isIOS ? 'IOS' : 'ANDROID'});
    } catch (e) {
      developer.log('FCM token upload failed: $e');
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(AuthenticationService.tokenKey);
    if (jwt == null) return;
    await http
        .post(
          Uri.parse('${AuthenticationService.apiBaseUrl}$path'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $jwt'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
  }
}
