// lib/services/damage_service.dart
//
// Damage marks on the car diagram (plan D10), shared with the portal's damage tab:
//   POST /api/v1/vehicle-damages/save   {parkingVehicleId, damages:[{description, xPos, yPos}]}
//        (VehicleDamageBulkRequestDTO; Premium: DAMAGE_MARKING; 201 all saved, 207 partly)
//   GET  /api/v1/vehicle-damages/by-parking-vehicle/{id}
//        (VehicleDamageResponse {parkingVehicleId, damages:[{description, xpos, ypos, createdBy,
//        createdTime}]} - Lombok/Jackson writes the positions as "xpos"/"ypos")
// Positions are percentages (0-100) of the portal's 340 x 500 top-view diagram, front at the
// top, so a mark placed in the app lands on the same panel on the web and the other way round.
// The backend has no damage-type column, so the type leads the description: "Dent: Bonnet,
// small dent by the badge". Saving only adds marks; nothing is edited or removed server-side.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'authentication_service.dart';
import 'plan_service.dart' show apiErrorFrom;
import 'secure_store.dart';

enum DamageType { scratch, dent, crack, other }

extension DamageTypeLabel on DamageType {
  String get label => switch (this) {
        DamageType.scratch => 'Scratch',
        DamageType.dent => 'Dent',
        DamageType.crack => 'Crack',
        DamageType.other => 'Other',
      };
}

class DamageMark {
  final DamageType type;
  final String note;
  final double xPct; // 0-100 across the diagram, left to right
  final double yPct; // 0-100 down the diagram, front bumper at the top
  final String? createdBy;
  final DateTime? createdTime;
  final bool saved;

  const DamageMark({
    required this.type,
    required this.note,
    required this.xPct,
    required this.yPct,
    this.createdBy,
    this.createdTime,
    this.saved = false,
  });

  static final RegExp _typePrefix = RegExp(r'^\s*(scratch|dent|crack|other)\s*(?::\s*|$)', caseSensitive: false);

  /// Marks made on the web carry free text only - those read as "Other" with the whole text.
  factory DamageMark.fromJson(Map<String, dynamic> j) {
    final desc = (j['description'] as String?)?.trim() ?? '';
    final m = _typePrefix.firstMatch(desc);
    var type = DamageType.other;
    var note = desc;
    if (m != null) {
      type = DamageType.values.firstWhere((t) => t.label.toLowerCase() == m.group(1)!.toLowerCase());
      note = desc.substring(m.end).trim();
    }
    double pos(String a, String b) => ((j[a] ?? j[b] ?? 0) as num).toDouble().clamp(0, 100).toDouble();
    return DamageMark(
      type: type,
      note: note,
      xPct: pos('xpos', 'xPos'),
      yPct: pos('ypos', 'yPos'),
      createdBy: j['createdBy']?.toString(),
      createdTime: j['createdTime'] is String ? DateTime.tryParse(j['createdTime'] as String) : null,
      saved: true,
    );
  }

  String get description {
    final n = note.trim();
    final d = n.isEmpty ? type.label : '${type.label}: $n';
    return d.length > 255 ? d.substring(0, 255) : d;
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'xPos': double.parse(xPct.toStringAsFixed(2)),
        'yPos': double.parse(yPct.toStringAsFixed(2)),
      };

  DamageMark copyWith({DamageType? type, String? note}) =>
      DamageMark(type: type ?? this.type, note: note ?? this.note, xPct: xPct, yPct: yPct, createdBy: createdBy, createdTime: createdTime, saved: saved);
}

class DamageSaveResult {
  final int saved;
  final int failed;
  const DamageSaveResult(this.saved, this.failed);
}

class DamageService {
  static const String _base = '${AuthenticationService.apiBaseUrl}/v1/vehicle-damages';
  static const Duration _timeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final token = await SecureStore.token();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<DamageMark>> load(int parkingVehicleId) async {
    final r = await http.get(Uri.parse('$_base/by-parking-vehicle/$parkingVehicleId'), headers: await _headers()).timeout(_timeout);
    if (r.statusCode == 404) return const [];
    if (r.statusCode != 200) throw apiErrorFrom(r);
    final data = jsonDecode(r.body);
    final list = data is Map ? (data['damages'] as List? ?? const []) : (data is List ? data : const []);
    final marks = list.whereType<Map>().map((e) => DamageMark.fromJson(Map<String, dynamic>.from(e))).toList();
    marks.sort((a, b) => (a.createdTime ?? DateTime(0)).compareTo(b.createdTime ?? DateTime(0)));
    return marks;
  }

  /// Adds [marks] (1-50) to the car. Throws PlanRequiredException on a Free plan.
  Future<DamageSaveResult> save(int parkingVehicleId, List<DamageMark> marks) async {
    final r = await http
        .post(Uri.parse('$_base/save'),
            headers: await _headers(),
            body: jsonEncode({'parkingVehicleId': parkingVehicleId, 'damages': marks.map((m) => m.toJson()).toList()}))
        .timeout(_timeout);
    if (r.statusCode == 201 || r.statusCode == 200 || r.statusCode == 207) {
      try {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        return DamageSaveResult((d['successCount'] as num?)?.toInt() ?? marks.length, (d['failureCount'] as num?)?.toInt() ?? 0);
      } catch (_) {
        return DamageSaveResult(marks.length, 0);
      }
    }
    throw apiErrorFrom(r);
  }
}
