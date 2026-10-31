// lib/services/supervisor_service.dart
//
// Site supervisor API (backend SupervisorController /api/v1/supervisor/me/**): assigned sites,
// GPS check-in, position reports while checked in, check-out with checklist + notes, history.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'authentication_service.dart';
import 'secure_store.dart';
import 'plan_service.dart' show apiErrorFrom;

class SupervisorSite {
  final int id;
  final String name;
  final String? code;
  final double? lat;
  final double? lng;
  SupervisorSite({required this.id, required this.name, this.code, this.lat, this.lng});

  factory SupervisorSite.fromJson(Map<String, dynamic> j) => SupervisorSite(
        id: (j['id'] as num).toInt(),
        name: j['name'] ?? '',
        code: j['code'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

class SupervisorVisit {
  final int id;
  final int locationId;
  final String locationName;
  final String status; // OPEN / CLOSED
  final String liveState; // ON_SITE / OFF_SITE / NO_SIGNAL / CHECKED_OUT
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int durationMinutes;
  final bool? checkInOnSite;
  final int? checkInDistanceM;
  final int? lastDistanceM;
  final bool? lastOnSite;
  final int offSiteMinutes;

  SupervisorVisit({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.status,
    required this.liveState,
    required this.checkInAt,
    this.checkOutAt,
    required this.durationMinutes,
    this.checkInOnSite,
    this.checkInDistanceM,
    this.lastDistanceM,
    this.lastOnSite,
    required this.offSiteMinutes,
  });

  // Backend times are UTC without a zone suffix.
  static DateTime? _utc(dynamic s) {
    if (s == null) return null;
    final str = s.toString();
    return DateTime.tryParse(RegExp(r'([zZ]|[+-]\d\d:?\d\d)$').hasMatch(str) ? str : '${str}Z')?.toLocal();
  }

  factory SupervisorVisit.fromJson(Map<String, dynamic> j) => SupervisorVisit(
        id: (j['id'] as num).toInt(),
        locationId: (j['locationId'] as num).toInt(),
        locationName: j['locationName'] ?? '',
        status: j['status'] ?? 'OPEN',
        liveState: j['liveState'] ?? 'ON_SITE',
        checkInAt: _utc(j['checkInAt']) ?? DateTime.now(),
        checkOutAt: _utc(j['checkOutAt']),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 0,
        checkInOnSite: j['checkInOnSite'],
        checkInDistanceM: (j['checkInDistanceM'] as num?)?.toInt(),
        lastDistanceM: (j['lastDistanceM'] as num?)?.toInt(),
        lastOnSite: j['lastOnSite'],
        offSiteMinutes: (j['offSiteMinutes'] as num?)?.toInt() ?? 0,
      );
}

class SupervisorMe {
  final String name;
  final List<SupervisorSite> sites;
  final SupervisorVisit? openVisit;
  final int geofenceRadiusM;
  final int pingIntervalSec;
  final bool requireGps;

  SupervisorMe({
    required this.name,
    required this.sites,
    this.openVisit,
    required this.geofenceRadiusM,
    required this.pingIntervalSec,
    required this.requireGps,
  });

  factory SupervisorMe.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map<String, dynamic>?) ?? const {};
    return SupervisorMe(
      name: j['name'] ?? '',
      sites: ((j['sites'] as List?) ?? const []).map((e) => SupervisorSite.fromJson(e)).toList(),
      openVisit: j['openVisit'] == null ? null : SupervisorVisit.fromJson(j['openVisit']),
      geofenceRadiusM: (s['geofenceRadiusM'] as num?)?.toInt() ?? 200,
      pingIntervalSec: (s['pingIntervalSec'] as num?)?.toInt() ?? 60,
      requireGps: s['requireGps'] ?? true,
    );
  }
}

class SupervisorService {
  static const String _base = '${AuthenticationService.apiBaseUrl}/v1/supervisor/me';
  static const Duration _timeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final token = await SecureStore.token();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _get(String path) async {
    final r = await http.get(Uri.parse('$_base$path'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 200) throw apiErrorFrom(r);
    return jsonDecode(r.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$_base$path'), headers: await _headers(), body: jsonEncode(body)).timeout(_timeout);
    if (r.statusCode != 200) throw apiErrorFrom(r);
    return jsonDecode(r.body);
  }

  Future<SupervisorMe> me() async => SupervisorMe.fromJson(await _get(''));

  Future<SupervisorVisit> checkIn(int locationId, {double? lat, double? lng, double? accuracyM}) async =>
      SupervisorVisit.fromJson(await _post('/check-in', {
        'locationId': locationId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (accuracyM != null) 'accuracyM': accuracyM,
      }));

  Future<SupervisorVisit> ping(double lat, double lng, double? accuracyM) async =>
      SupervisorVisit.fromJson(await _post('/ping', {'lat': lat, 'lng': lng, if (accuracyM != null) 'accuracyM': accuracyM}));

  Future<SupervisorVisit> checkOut({double? lat, double? lng, required Map<String, bool> checklist, String? notes}) async =>
      SupervisorVisit.fromJson(await _post('/check-out', {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'checklistJson': jsonEncode(checklist),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }));

  Future<List<SupervisorVisit>> myVisits() async =>
      ((await _get('/visits')) as List).map((e) => SupervisorVisit.fromJson(e)).toList();
}
