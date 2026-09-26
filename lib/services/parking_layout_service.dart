// lib/services/parking_layout_service.dart
//
// Building -> Floor -> Area -> Slot layout the client gives the valet company
// (backend ParkingLayoutController, /api/v1/parking-layout). Buildings and floors are set up by
// the admin on the web portal; the client's SECURITY user then adds the valet areas and numbered
// slots on each floor from the phone, and switches slots off/on as the site changes.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication_service.dart';
import 'valet_service.dart' show ValetApiException;

class LayoutSlot {
  final int id;
  final String slotNumber;
  final String status; // FREE / OCCUPIED / RESERVED / OUT_OF_SERVICE
  final String? occupantPlateNo;

  LayoutSlot({required this.id, required this.slotNumber, required this.status, this.occupantPlateNo});

  factory LayoutSlot.fromJson(Map<String, dynamic> j) => LayoutSlot(
        id: (j['id'] as num).toInt(),
        slotNumber: j['slotNumber'] ?? '',
        status: j['status'] ?? 'FREE',
        occupantPlateNo: j['occupantPlateNo'],
      );
}

class LayoutArea {
  final int id;
  final int? floorId;
  final String name;
  final String purpose; // VALET / SELF_PARK
  final String status;
  final List<LayoutSlot> slots;
  final int totalSlots;
  final int freeSlots;
  final int occupiedSlots;

  LayoutArea({
    required this.id,
    this.floorId,
    required this.name,
    required this.purpose,
    required this.status,
    required this.slots,
    required this.totalSlots,
    required this.freeSlots,
    required this.occupiedSlots,
  });

  factory LayoutArea.fromJson(Map<String, dynamic> j) => LayoutArea(
        id: (j['id'] as num).toInt(),
        floorId: (j['floorId'] as num?)?.toInt(),
        name: j['name'] ?? '',
        purpose: j['purpose'] ?? 'VALET',
        status: j['status'] ?? 'ACTIVE',
        slots: ((j['slots'] as List?) ?? []).map((e) => LayoutSlot.fromJson(e as Map<String, dynamic>)).toList(),
        totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
        freeSlots: (j['freeSlots'] as num?)?.toInt() ?? 0,
        occupiedSlots: (j['occupiedSlots'] as num?)?.toInt() ?? 0,
      );
}

class LayoutFloor {
  final int id;
  final String name;
  final String? buildingName;
  final List<LayoutArea> areas;
  final int totalSlots;
  final int freeSlots;

  LayoutFloor({
    required this.id,
    required this.name,
    this.buildingName,
    required this.areas,
    required this.totalSlots,
    required this.freeSlots,
  });

  factory LayoutFloor.fromJson(Map<String, dynamic> j, {String? buildingName}) => LayoutFloor(
        id: (j['id'] as num).toInt(),
        name: j['name'] ?? '',
        buildingName: buildingName,
        areas: ((j['zones'] as List?) ?? []).map((e) => LayoutArea.fromJson(e as Map<String, dynamic>)).toList(),
        totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
        freeSlots: (j['freeSlots'] as num?)?.toInt() ?? 0,
      );

  String get title => buildingName == null ? name : '$buildingName · $name';
}

class ParkingLayout {
  /// Every floor, in the site's order (building by building, then floors with no building).
  final List<LayoutFloor> floors;
  final List<LayoutArea> areasWithoutFloor;
  final int totalSlots;
  final int freeSlots;
  final int occupiedSlots;
  final int outOfServiceSlots;

  ParkingLayout({
    required this.floors,
    required this.areasWithoutFloor,
    required this.totalSlots,
    required this.freeSlots,
    required this.occupiedSlots,
    required this.outOfServiceSlots,
  });

  factory ParkingLayout.fromJson(Map<String, dynamic> j) {
    final floors = <LayoutFloor>[];
    for (final b in (j['buildings'] as List?) ?? []) {
      final building = b as Map<String, dynamic>;
      for (final f in (building['floors'] as List?) ?? []) {
        floors.add(LayoutFloor.fromJson(f as Map<String, dynamic>, buildingName: building['name']));
      }
    }
    for (final f in (j['floorsWithoutBuilding'] as List?) ?? []) {
      floors.add(LayoutFloor.fromJson(f as Map<String, dynamic>));
    }
    return ParkingLayout(
      floors: floors,
      areasWithoutFloor:
          ((j['zonesWithoutFloor'] as List?) ?? []).map((e) => LayoutArea.fromJson(e as Map<String, dynamic>)).toList(),
      totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
      freeSlots: (j['freeSlots'] as num?)?.toInt() ?? 0,
      occupiedSlots: (j['occupiedSlots'] as num?)?.toInt() ?? 0,
      outOfServiceSlots: (j['outOfServiceSlots'] as num?)?.toInt() ?? 0,
    );
  }
}

class ParkingLayoutService {
  static const String _base = '${AuthenticationService.apiBaseUrl}/v1/parking-layout';
  static const Duration _timeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthenticationService.tokenKey);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Never _fail(http.Response r) {
    String message = 'Request failed (${r.statusCode})';
    try {
      final data = jsonDecode(r.body);
      message = data['message'] ?? data['error'] ?? message;
    } catch (_) {}
    if (r.statusCode == 403) message = 'Your account is not allowed to change the parking layout.';
    throw ValetApiException(message);
  }

  Future<ParkingLayout> fetchLayout() async {
    final r = await http.get(Uri.parse(_base), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 200) _fail(r);
    return ParkingLayout.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> addArea({required int floorId, required String name}) async {
    final r = await http
        .post(Uri.parse('$_base/areas'),
            headers: await _headers(), body: jsonEncode({'floorId': floorId, 'name': name, 'purpose': 'VALET'}))
        .timeout(_timeout);
    if (r.statusCode != 200 && r.statusCode != 201) _fail(r);
  }

  /// Either a range (prefix + start + count, e.g. "B1-" 1..20) or an explicit list of numbers.
  Future<void> addSlots({
    required int areaId,
    String? prefix,
    int? startNumber,
    int? count,
    List<String>? slotNumbers,
  }) async {
    final body = slotNumbers != null && slotNumbers.isNotEmpty
        ? {'slotNumbers': slotNumbers}
        : {'prefix': prefix ?? '', 'startNumber': startNumber ?? 1, 'count': count ?? 1};
    final r = await http
        .post(Uri.parse('$_base/areas/$areaId/slots'), headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    if (r.statusCode != 200 && r.statusCode != 201) _fail(r);
  }

  /// FREE, RESERVED or OUT_OF_SERVICE (OCCUPIED is only ever set by parking a car).
  Future<void> setSlotStatus({required int slotId, required String status}) async {
    final r = await http
        .put(Uri.parse('$_base/slots/$slotId/status'), headers: await _headers(), body: jsonEncode({'status': status}))
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r);
  }

  Future<void> deleteSlot(int slotId) async {
    final r = await http.delete(Uri.parse('$_base/slots/$slotId'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode != 200 && r.statusCode != 204) _fail(r);
  }
}
