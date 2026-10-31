// lib/services/valet_service.dart
//
// Mirrors the web app's Valet Desk API surface (frontend/FS-ValetFusion/src/pages/DashboardPage.tsx)
// against the same backend contract (backend/evaletFusion .../ParkingVehicleController.java).
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'authentication_service.dart';
import 'plan_service.dart' show apiErrorFrom;
import 'secure_store.dart';

final Random _keyRandom = Random.secure();

/// A random (v4) UUID, sent as the Idempotency-Key header on lifecycle calls (plan E13): when a
/// call times out after the server did the work, the offline queue replays it with the same key
/// and gets the original answer back instead of "already delivered".
String newIdempotencyKey() {
  final b = List<int>.generate(16, (_) => _keyRandom.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class Shop {
  final int id;
  final String shopName;

  Shop({required this.id, required this.shopName});

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(id: json['id'] ?? 0, shopName: json['shopName'] ?? '');
  }
}

class ServiceType {
  final int id;
  final String name;

  ServiceType({required this.id, required this.name});

  factory ServiceType.fromJson(Map<String, dynamic> json) {
    return ServiceType(id: json['id'] ?? 0, name: json['serviceName'] ?? json['name'] ?? '');
  }
}

// Mirrors TicketParkingStatusResponseDTO.java exactly.
class TicketStatusResponse {
  final String ticketNo;
  final bool ticketFree;
  final String? ticketStatus;
  final String message;
  final int? parkingVehicleId;
  final String? plateNo;
  final String? vehicleMake;
  final String? vehicleColor;
  final String? bayNo;
  final String? status; // RECEIVED / REQUESTED / ONTHEWAY / ARRIVED / DELIVERED
  final String? parkingInTime;
  final String? requestedTime;
  final String? shopValidateTime;
  final int? shopId;
  final String? shopName;
  final String? dispatchedTime;
  final String? arrivedTime;
  final String? deliveredTime;
  final double? parkingCharge;
  final double? originalParkingCharge;
  final String? vpaIn;
  final String? vpaOut;
  final String? receiveRemarks;
  final String? shopRemarks;
  final String? requestedRemarks;
  final String? keyHolderNo;
  final String? paymentMethod;
  final int? assignedDriverId;
  final double? driverLat;
  final double? driverLng;
  final String? driverLocationUpdatedAt;
  final double? etaDistanceMeters;
  final int? etaMinutes;
  final String? etaSource; // GPS (live fix) or SCHEDULE (dispatch estimate / driver's extension)
  final int? etaExtendedCount;
  final int? etaExtendedMinutes; // total minutes the driver added
  final int? etaExtendedAgoMinutes; // since the last extension
  final String? companyCode; // property code - opens the live-tracking stream
  final bool checkInDue; // driver app should ask "still on the way?"
  final int? driverLocationAgeSeconds; // computed server-side, so no phone/server clock skew
  final String? vehicleModel;
  final String? parkingLocation; // "Building · Floor · Area · Slot X" or "Bay X"
  final String? washStatus;
  final String? washRequestedAt;
  final String? washCompletedAt;
  final int? rating;
  final String? ratingComment;

  TicketStatusResponse({
    required this.ticketNo,
    required this.ticketFree,
    this.ticketStatus,
    required this.message,
    this.parkingVehicleId,
    this.plateNo,
    this.vehicleMake,
    this.vehicleColor,
    this.bayNo,
    this.status,
    this.parkingInTime,
    this.requestedTime,
    this.shopValidateTime,
    this.shopId,
    this.shopName,
    this.dispatchedTime,
    this.arrivedTime,
    this.deliveredTime,
    this.parkingCharge,
    this.originalParkingCharge,
    this.vpaIn,
    this.vpaOut,
    this.receiveRemarks,
    this.shopRemarks,
    this.requestedRemarks,
    this.keyHolderNo,
    this.paymentMethod,
    this.assignedDriverId,
    this.driverLat,
    this.driverLng,
    this.driverLocationUpdatedAt,
    this.etaDistanceMeters,
    this.etaMinutes,
    this.etaSource,
    this.etaExtendedCount,
    this.etaExtendedMinutes,
    this.etaExtendedAgoMinutes,
    this.companyCode,
    this.checkInDue = false,
    this.driverLocationAgeSeconds,
    this.vehicleModel,
    this.parkingLocation,
    this.washStatus,
    this.washRequestedAt,
    this.washCompletedAt,
    this.rating,
    this.ratingComment,
  });

  factory TicketStatusResponse.fromJson(Map<String, dynamic> json) {
    return TicketStatusResponse(
      ticketNo: json['ticketNo'] ?? '',
      ticketFree: json['ticketFree'] ?? false,
      ticketStatus: json['ticketStatus'],
      message: json['message'] ?? '',
      parkingVehicleId: json['parkingVehicleId'],
      plateNo: json['plateNo'],
      vehicleMake: json['vehicleMake'],
      vehicleColor: json['vehicleColor'],
      bayNo: json['bayNo'],
      status: json['status'],
      parkingInTime: json['parkingInTime'],
      requestedTime: json['requestedTime'],
      shopValidateTime: json['shopValidateTime'],
      shopId: json['shopId'],
      shopName: json['shopName'],
      dispatchedTime: json['dispatchedTime'],
      arrivedTime: json['arrivedTime'],
      deliveredTime: json['deliveredTime'],
      parkingCharge: (json['parkingCharge'] as num?)?.toDouble(),
      originalParkingCharge: (json['originalParkingCharge'] as num?)?.toDouble(),
      vpaIn: json['vpaIn'],
      vpaOut: json['vpaOut'],
      receiveRemarks: json['receiveRemarks'],
      shopRemarks: json['shopRemarks'],
      requestedRemarks: json['requestedRemarks'],
      keyHolderNo: json['keyHolderNo'],
      paymentMethod: json['paymentMethod'],
      assignedDriverId: json['assignedDriverId'],
      driverLat: (json['driverLat'] as num?)?.toDouble(),
      driverLng: (json['driverLng'] as num?)?.toDouble(),
      driverLocationUpdatedAt: json['driverLocationUpdatedAt'],
      etaDistanceMeters: (json['etaDistanceMeters'] as num?)?.toDouble(),
      etaMinutes: json['etaMinutes'],
      etaSource: json['etaSource'],
      etaExtendedCount: json['etaExtendedCount'],
      etaExtendedMinutes: (json['etaExtendedMinutes'] as num?)?.toInt(),
      etaExtendedAgoMinutes: (json['etaExtendedAgoMinutes'] as num?)?.toInt(),
      companyCode: json['companyCode'] as String?,
      checkInDue: json['checkInDue'] == true,
      driverLocationAgeSeconds: (json['driverLocationAgeSeconds'] as num?)?.toInt(),
      vehicleModel: json['vehicleModel'],
      parkingLocation: json['parkingLocation'],
      washStatus: json['washStatus'],
      washRequestedAt: json['washRequestedAt'],
      washCompletedAt: json['washCompletedAt'],
      rating: json['rating'],
      ratingComment: json['ratingComment'],
    );
  }
}

class CustomerHistoryEntry {
  final String ticketNo;
  final String? plateNo;
  final String? vehicleMake;
  final String? vehicleColor;
  final String? status;
  final String? parkingInTime;
  final String? deliveredTime;
  final int? rating;
  final double? parkingCharge;

  CustomerHistoryEntry({
    required this.ticketNo,
    this.plateNo,
    this.vehicleMake,
    this.vehicleColor,
    this.status,
    this.parkingInTime,
    this.deliveredTime,
    this.rating,
    this.parkingCharge,
  });

  factory CustomerHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CustomerHistoryEntry(
      ticketNo: json['ticketNo'] ?? '',
      plateNo: json['plateNo'],
      vehicleMake: json['vehicleMake'],
      vehicleColor: json['vehicleColor'],
      status: json['status'],
      parkingInTime: json['parkingInTime'],
      deliveredTime: json['deliveredTime'],
      rating: json['rating'],
      parkingCharge: (json['parkingCharge'] as num?)?.toDouble(),
    );
  }
}

class DriverRecentDelivery {
  final String ticketNo;
  final String? plateNo;
  final String? deliveredTime;
  final int? turnaroundMinutes;
  final int? rating;

  DriverRecentDelivery({
    required this.ticketNo,
    this.plateNo,
    this.deliveredTime,
    this.turnaroundMinutes,
    this.rating,
  });

  factory DriverRecentDelivery.fromJson(Map<String, dynamic> json) {
    return DriverRecentDelivery(
      ticketNo: json['ticketNo'] ?? '',
      plateNo: json['plateNo'],
      deliveredTime: json['deliveredTime'],
      turnaroundMinutes: json['turnaroundMinutes'],
      rating: json['rating'],
    );
  }
}

class DriverActivity {
  final int deliveredToday;
  final int deliveredTotal;
  final double? averageTurnaroundMinutes;
  final List<DriverRecentDelivery> recentDeliveries;

  DriverActivity({
    required this.deliveredToday,
    required this.deliveredTotal,
    this.averageTurnaroundMinutes,
    required this.recentDeliveries,
  });

  factory DriverActivity.fromJson(Map<String, dynamic> json) {
    return DriverActivity(
      deliveredToday: json['deliveredToday'] ?? 0,
      deliveredTotal: json['deliveredTotal'] ?? 0,
      averageTurnaroundMinutes: (json['averageTurnaroundMinutes'] as num?)?.toDouble(),
      recentDeliveries: ((json['recentDeliveries'] as List?) ?? [])
          .map((e) => DriverRecentDelivery.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DriverOption {
  final int id;
  final String name;
  final String? phone;
  // Server orders drivers best-first and flags the top one (fewest cars in hand, longest idle).
  final int activeDeliveries;
  final bool suggested;
  // ON_DUTY / BREAK / OFF from the driver's shift buttons; null if they've never used shifts.
  // The server already sorts on-duty drivers first.
  final String? shiftState;

  DriverOption({required this.id, required this.name, this.phone, this.activeDeliveries = 0, this.suggested = false, this.shiftState});

  factory DriverOption.fromJson(Map<String, dynamic> json) {
    return DriverOption(
      id: json['id'],
      name: (json['name'] as String?)?.trim().isEmpty ?? true ? 'Driver #${json['id']}' : json['name'],
      phone: json['phone'],
      activeDeliveries: (json['activeDeliveries'] as num?)?.toInt() ?? 0,
      suggested: json['suggested'] == true,
      shiftState: json['shiftState'] as String?,
    );
  }

  bool get onBreak => shiftState == 'BREAK';
  bool get offDuty => shiftState == 'OFF';

  String get loadLabel {
    final load = activeDeliveries == 0 ? 'free' : '$activeDeliveries in hand';
    if (onBreak) return 'On break · $load';
    if (offDuty) return 'Off duty';
    return suggested ? 'Suggested · $load' : load;
  }
}

/// GET/POST /v1/driver-shift/me - the driver's availability and this shift's numbers.
class DriverShift {
  final String state; // ON_DUTY / BREAK / OFF
  final String? since;
  final String? shiftStart;
  final String? shiftEnd;
  final int shiftMinutes;
  final int breakMinutes;
  final int receivedThisShift;
  final int deliveredThisShift;
  final int inHand;
  final String? message;

  DriverShift({
    required this.state,
    this.since,
    this.shiftStart,
    this.shiftEnd,
    this.shiftMinutes = 0,
    this.breakMinutes = 0,
    this.receivedThisShift = 0,
    this.deliveredThisShift = 0,
    this.inHand = 0,
    this.message,
  });

  factory DriverShift.fromJson(Map<String, dynamic> json) => DriverShift(
        state: json['state'] as String? ?? 'OFF',
        since: json['since'] as String?,
        shiftStart: json['shiftStart'] as String?,
        shiftEnd: json['shiftEnd'] as String?,
        shiftMinutes: (json['shiftMinutes'] as num?)?.toInt() ?? 0,
        breakMinutes: (json['breakMinutes'] as num?)?.toInt() ?? 0,
        receivedThisShift: (json['receivedThisShift'] as num?)?.toInt() ?? 0,
        deliveredThisShift: (json['deliveredThisShift'] as num?)?.toInt() ?? 0,
        inHand: (json['inHand'] as num?)?.toInt() ?? 0,
        message: json['message'] as String?,
      );

  bool get onDuty => state == 'ON_DUTY';
  bool get onBreak => state == 'BREAK';
  bool get off => state == 'OFF';
}

/// GET /v1/parking-vehicles/{id}/where - the driver's "Find my car" card.
class VehicleWhere {
  final int id;
  final String ticketNo;
  final String? plateNo;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? status;
  final String? building;
  final String? floor;
  final String? zone;
  final String? slotNumber;
  final String? bayNo;
  final String? parkingLocation;
  final String? keyHolderNo;
  final String? parkingInTime;

  VehicleWhere({
    required this.id,
    required this.ticketNo,
    this.plateNo,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.status,
    this.building,
    this.floor,
    this.zone,
    this.slotNumber,
    this.bayNo,
    this.parkingLocation,
    this.keyHolderNo,
    this.parkingInTime,
  });

  factory VehicleWhere.fromJson(Map<String, dynamic> json) => VehicleWhere(
        id: (json['id'] as num).toInt(),
        ticketNo: json['ticketNo'] as String? ?? '',
        plateNo: json['plateNo'] as String?,
        vehicleMake: json['vehicleMake'] as String?,
        vehicleModel: json['vehicleModel'] as String?,
        vehicleColor: json['vehicleColor'] as String?,
        status: json['status'] as String?,
        building: json['building'] as String?,
        floor: json['floor'] as String?,
        zone: json['zone'] as String?,
        slotNumber: json['slotNumber'] as String?,
        bayNo: json['bayNo'] as String?,
        parkingLocation: json['parkingLocation'] as String?,
        keyHolderNo: json['keyHolderNo'] as String?,
        parkingInTime: json['parkingInTime'] as String?,
      );
}

class DashboardDetails {
  final List<Map<String, dynamic>> requestedVehicles;
  final List<Map<String, dynamic>> onthewayVehicles;
  final int receivedCount;
  final int deliveredCount;
  final int currentInventory;
  final int complimentaryCount;
  final int paidCount;
  final int ticketsTotal;
  final int ticketsUsed;
  final int ticketsRemaining;
  final String? timestamp; // server clock at response time - lets wait timers ignore phone clock skew

  DashboardDetails({
    this.timestamp,
    required this.requestedVehicles,
    required this.onthewayVehicles,
    required this.receivedCount,
    required this.deliveredCount,
    required this.currentInventory,
    required this.complimentaryCount,
    required this.paidCount,
    required this.ticketsTotal,
    required this.ticketsUsed,
    required this.ticketsRemaining,
  });

  factory DashboardDetails.fromJson(Map<String, dynamic> json) {
    return DashboardDetails(
      requestedVehicles: List<Map<String, dynamic>>.from(json['requestedVehicles'] ?? []),
      onthewayVehicles: List<Map<String, dynamic>>.from(json['onthewayVehicles'] ?? []),
      receivedCount: json['receivedCount'] ?? 0,
      deliveredCount: json['deliveredCount'] ?? 0,
      currentInventory: json['currentInventory'] ?? 0,
      complimentaryCount: json['complimentaryCount'] ?? 0,
      paidCount: json['paidCount'] ?? 0,
      ticketsTotal: json['ticketsTotal'] ?? 0,
      ticketsUsed: json['ticketsUsed'] ?? 0,
      ticketsRemaining: json['ticketsRemaining'] ?? 0,
      timestamp: json['timestamp'] as String?,
    );
  }
}

class AvailableSlot {
  final int slotId;
  final String slotNumber;
  final String? areaName;
  final String? floorName;
  final String? buildingName;
  final String label;

  AvailableSlot({
    required this.slotId,
    required this.slotNumber,
    this.areaName,
    this.floorName,
    this.buildingName,
    required this.label,
  });

  factory AvailableSlot.fromJson(Map<String, dynamic> json) {
    return AvailableSlot(
      slotId: (json['slotId'] as num).toInt(),
      slotNumber: json['slotNumber'] ?? '',
      areaName: json['areaName'],
      floorName: json['floorName'],
      buildingName: json['buildingName'],
      label: json['label'] ?? 'Slot ${json['slotNumber']}',
    );
  }

  /// "Building · Floor · Area" - shown under the big slot number.
  String get where => [buildingName, floorName, areaName].where((s) => s != null && s.isNotEmpty).join(' · ');
}

class ValetApiException implements Exception {
  final String message;
  ValetApiException(this.message);
  @override
  String toString() => message;
}

class VehiclePhotoInfo {
  final int id;
  final String angle; // FRONT / BACK / LEFT / RIGHT / OTHER
  final String takenAt;
  final String url; // relative to apiBaseUrl
  VehiclePhotoInfo({required this.id, required this.angle, required this.takenAt, required this.url});

  factory VehiclePhotoInfo.fromJson(Map<String, dynamic> json) => VehiclePhotoInfo(
        id: (json['id'] as num).toInt(),
        angle: json['angle'] as String? ?? 'OTHER',
        takenAt: json['takenAt'] as String? ?? '',
        url: json['url'] as String,
      );
}

class TrackingCompany {
  final String code;
  final String name;
  TrackingCompany(this.code, this.name);
}

class ValetService {
  static const String apiBaseUrl = AuthenticationService.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 30);

  /// The signed-in user's company code, for the guest tracking link (`/track/CODE/TICKET`).
  Future<TrackingCompany> fetchTrackingCompany() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/master-locations/mine/tracking-code'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TrackingCompany(data['code'] as String, data['name'] as String? ?? '');
  }

  // companyCode: only needed when a CUSTOMER is looking up/acting on a ticket at a *different*
  // property than the one their account was created at (see CustomerHomePage's location picker).
  // The backend's JwtAuthenticationFilter re-points the tenant DB for this request when it sees
  // X-Company-Code on a CUSTOMER token - ignored (and ignored server-side) for every other role.
  Future<Map<String, String>> _headers({String? companyCode, String? idempotencyKey}) async {
    final token = await SecureStore.token();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (companyCode != null && companyCode.isNotEmpty) 'X-Company-Code': companyCode,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
    };
  }

  /// Where a car is parked, its key hook and since when ("Find my car").
  Future<VehicleWhere> fetchWhere(int parkingVehicleId) async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/where'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) throw ValetApiException(_errorMessage(response));
    return VehicleWhere.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Driver shift (Start shift / Break / End shift) ──
  Future<DriverShift> fetchMyShift() async {
    final headers = await _headers();
    final response =
        await http.get(Uri.parse('$apiBaseUrl/v1/driver-shift/me'), headers: headers).timeout(timeout);
    if (response.statusCode != 200) throw ValetApiException(_errorMessage(response));
    return DriverShift.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// state: 'ON_DUTY' (start shift / back from break), 'BREAK' or 'OFF' (end shift).
  Future<DriverShift> updateMyShift(String state) async {
    final headers = await _headers();
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/driver-shift/me'), headers: headers, body: jsonEncode({'state': state}))
        .timeout(timeout);
    if (response.statusCode != 200) throw ValetApiException(_errorMessage(response));
    return DriverShift.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Condition photos (taken at check-in, looked at again at handover) ──
  Future<List<VehiclePhotoInfo>> fetchPhotos(int parkingVehicleId) async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/photos'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) throw apiErrorFrom(response);
    return (jsonDecode(response.body) as List).map((e) => VehiclePhotoInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VehiclePhotoInfo> uploadPhoto(int parkingVehicleId, String filePath, String angle) async {
    final token = await SecureStore.token();
    final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/photos'))
      ..fields['angle'] = angle
      ..files.add(await http.MultipartFile.fromPath('file', filePath, contentType: MediaType('image', 'jpeg')));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) throw apiErrorFrom(response);
    return VehiclePhotoInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Image bytes for a photo (the endpoint needs the auth header, so no plain Image.network).
  Future<List<int>> fetchPhotoBytes(String url) async {
    final token = await SecureStore.token();
    final response = await http.get(Uri.parse('$apiBaseUrl$url'), headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    }).timeout(timeout);
    if (response.statusCode != 200) throw ValetApiException('Photo unavailable');
    return response.bodyBytes;
  }

  Future<TicketStatusResponse> checkTicketStatus(String ticketNo, {String? companyCode}) async {
    final headers = await _headers(companyCode: companyCode);
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/ticket-status'),
          headers: headers,
          body: jsonEncode({'ticketNo': ticketNo}),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return TicketStatusResponse.fromJson(jsonDecode(response.body));
    }
    throw apiErrorFrom(response);
  }

  /// Receive a new vehicle (RECEIVED). Mirrors ParkingVehicleRequestDTO.
  Future<void> receiveVehicle({
    required String ticketNo,
    String? vpaIn,
    String? plateNo,
    String? bayNo,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    int? serviceType,
    String? requestedRemarks,
    String? keyHolderNo,
  }) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/receive'),
          headers: headers,
          body: jsonEncode({
            'ticketNo': ticketNo,
            if (vpaIn != null) 'vpaIn': vpaIn,
            'plateNo': plateNo ?? '',
            if (bayNo != null) 'bayNo': bayNo,
            if (vehicleMake != null) 'vehicleMake': vehicleMake,
            if (vehicleModel != null) 'vehicleModel': vehicleModel,
            if (vehicleColor != null) 'vehicleColor': vehicleColor,
            if (serviceType != null) 'serviceType': serviceType,
            if (requestedRemarks != null) 'requestedRemarks': requestedRemarks,
            if (keyHolderNo != null) 'keyHolderNo': keyHolderNo,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw apiErrorFrom(response);
    }
  }

  /// Key Controller assigns/corrects the key holder (hook/board) number for an
  /// already-received vehicle - covers the in-person ticket+key handoff path.
  Future<void> assignKeyHolder({required int parkingVehicleId, required String keyHolderNo, String? idempotencyKey}) async {
    final headers = await _headers(idempotencyKey: idempotencyKey);
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/key-holder'),
          headers: headers,
          body: jsonEncode({'keyHolderNo': keyHolderNo}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Driver / Key Controller records where the vehicle was actually parked. Mirrors
  /// ParkDetailsRequestDTO: pass slotId when the property has a parking layout (the server claims
  /// the slot atomically, so two drivers can't take the same one), or a free-text bayNo otherwise.
  /// Returns the server's message, e.g. "Parked at Tower A · B1 · Zone 1 · Slot 12".
  Future<String> recordParkDetails({
    required int parkingVehicleId,
    int? slotId,
    String? bayNo,
    String? keyHolderNo,
    String? idempotencyKey,
  }) async {
    final headers = await _headers(idempotencyKey: idempotencyKey);
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/park-details'),
          headers: headers,
          body: jsonEncode({
            if (slotId != null) 'slotId': slotId,
            if (bayNo != null && bayNo.isNotEmpty) 'bayNo': bayNo,
            if (keyHolderNo != null && keyHolderNo.isNotEmpty) 'keyHolderNo': keyHolderNo,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    return _messageOr(response, 'Parked');
  }

  String _messageOr(http.Response response, String fallback) {
    try {
      return (jsonDecode(response.body)['message'] as String?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Free valet slots, nearest first (building -> floor -> area -> slot order, as set up in
  /// Parking Management). Empty when the property hasn't configured a layout.
  Future<List<AvailableSlot>> fetchAvailableSlots({int limit = 50}) async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-layout/available-slots?limit=$limit'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => AvailableSlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Driver answers "Still on the way?" - extendMinutes 0 means "on time", 5..60 pushes the
  /// customer's ETA back by that much.
  Future<String> etaCheckIn({required int parkingVehicleId, required int extendMinutes}) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/eta-checkin'),
          headers: headers,
          body: jsonEncode({'extendMinutes': extendMinutes}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    return _messageOr(response, 'Updated');
  }

  /// Mirrors ShopChargePreviewRequestDTO / ShopChargePreviewResponseDTO.
  Future<double> previewShopCharge({required int parkingVehicleId, required int shopId}) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/shop-charges-preview'),
          headers: headers,
          body: jsonEncode({'shopId': shopId}),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['calculatedCharge'] as num?)?.toDouble() ?? 0.0;
    }
    throw apiErrorFrom(response);
  }

  /// Mirrors VehicleRequestDTO.
  Future<void> requestVehicle({
    required int parkingVehicleId,
    required String requestedRemarks,
    required double parkingCharge,
    int? shopId,
    String? shopRemarks,
    String? paymentMethod, // 'CASH' or 'CARD' - set when the customer app requests a payable pickup
    String? companyCode,
    String? idempotencyKey,
  }) async {
    final headers = await _headers(companyCode: companyCode, idempotencyKey: idempotencyKey);
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/request'),
          headers: headers,
          body: jsonEncode({
            'requestedRemarks': requestedRemarks,
            'parkingCharge': parkingCharge,
            if (shopId != null) 'shopId': shopId,
            if (shopRemarks != null) 'shopRemarks': shopRemarks,
            if (paymentMethod != null) 'paymentMethod': paymentMethod,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Mirrors VehicleDispatchDTO. Pass driverId (preferred, from fetchAvailableDrivers) or vpaOut
  /// free-text as a fallback - the server resolves driverId into vpaOut itself.
  Future<void> dispatchVehicle({required int parkingVehicleId, String? vpaOut, int? driverId, String? idempotencyKey}) async {
    final headers = await _headers(idempotencyKey: idempotencyKey);
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/dispatch'),
          headers: headers,
          body: jsonEncode({
            if (vpaOut != null) 'vpaOut': vpaOut,
            if (driverId != null) 'driverId': driverId,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Active DRIVER-role users the Key Controller can assign at dispatch time.
  Future<List<DriverOption>> fetchAvailableDrivers() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/available-drivers'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => DriverOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Driver's "My Deliveries" - vehicles a Key Controller assigned to them, still ONTHEWAY/ARRIVED.
  Future<List<TicketStatusResponse>> fetchMyDeliveries() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/my-deliveries'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => _fromDeliveryJson(e as Map<String, dynamic>)).toList();
  }

  // /my-deliveries returns ParkingVehicleResponseDTO shape, which differs slightly from
  // TicketStatusResponse (ticket-status's DTO) - map the fields both share into the same model
  // so the Driver UI can reuse one type for "assigned to me" and "looked up by ticket number".
  TicketStatusResponse _fromDeliveryJson(Map<String, dynamic> json) {
    return TicketStatusResponse(
      ticketNo: json['ticketNo'] ?? '',
      ticketFree: false,
      message: json['message'] ?? '',
      parkingVehicleId: json['id'],
      plateNo: json['plateNo'],
      vehicleMake: json['vehicleMake'],
      vehicleColor: json['vehicleColor'],
      bayNo: json['bayNo'],
      status: json['status'],
      keyHolderNo: json['keyHolderNo'],
      paymentMethod: json['paymentMethod'],
      assignedDriverId: json['assignedDriverId'],
      driverLat: (json['driverLat'] as num?)?.toDouble(),
      driverLng: (json['driverLng'] as num?)?.toDouble(),
      etaDistanceMeters: (json['etaDistanceMeters'] as num?)?.toDouble(),
      etaMinutes: json['etaMinutes'],
      etaSource: json['etaSource'],
      etaExtendedCount: json['etaExtendedCount'],
      etaExtendedMinutes: (json['etaExtendedMinutes'] as num?)?.toInt(),
      etaExtendedAgoMinutes: (json['etaExtendedAgoMinutes'] as num?)?.toInt(),
      companyCode: json['companyCode'] as String?,
      checkInDue: json['checkInDue'] == true,
      driverLocationAgeSeconds: (json['driverLocationAgeSeconds'] as num?)?.toInt(),
      vehicleModel: json['vehicleModel'],
      parkingLocation: json['parkingLocation'],
      washStatus: json['washStatus'],
      parkingInTime: json['parkingInTime'],
    );
  }

  /// Parking Occupancy view - every vehicle currently in the given status (e.g. RECEIVED = parked).
  Future<List<TicketStatusResponse>> fetchByStatus(String status) async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/status/$status'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => _fromDeliveryJson(e as Map<String, dynamic>)).toList();
  }

  /// Driver's app calls this every ~15s while a delivery is ONTHEWAY, so Customer/Lobby can see
  /// live movement and a rough ETA.
  Future<void> updateDriverLocation({required int parkingVehicleId, required double lat, required double lng}) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/location'),
          headers: headers,
          body: jsonEncode({'lat': lat, 'lng': lng}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Customer requests a wash for their parked (RECEIVED) car - independent of the pickup flow.
  Future<void> requestWash(int parkingVehicleId, {String? companyCode}) async {
    final headers = await _headers(companyCode: companyCode);
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/wash-request'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Key Controller/Driver's "Wash Requests" list - pending/in-progress jobs.
  Future<List<TicketStatusResponse>> fetchWashRequests() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/wash-requests'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => _fromDeliveryJson(e as Map<String, dynamic>)).toList();
  }

  /// status: 'IN_PROGRESS' or 'DONE'.
  Future<void> updateWashStatus({required int parkingVehicleId, required String status}) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/wash-status?status=$status'),
          headers: headers,
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Customer rates their experience right after DELIVERED.
  Future<void> submitRating({required int parkingVehicleId, required int rating, String? comment, String? companyCode}) async {
    final headers = await _headers(companyCode: companyCode);
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/rating'),
          headers: headers,
          body: jsonEncode({'rating': rating, if (comment != null && comment.isNotEmpty) 'comment': comment}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Customer's "My Parking History".
  Future<List<CustomerHistoryEntry>> fetchMyHistory() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/my-history'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => CustomerHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Driver's "My Activity" report.
  Future<DriverActivity> fetchMyActivity() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/my-activity'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    return DriverActivity.fromJson(jsonDecode(response.body));
  }

  /// The Customer's own linked ticket, if any - lets the home screen show status without asking
  /// for the ticket number every time.
  Future<TicketStatusResponse?> fetchMyActiveTicket() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/my-active-ticket'), headers: headers)
        .timeout(timeout);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    return TicketStatusResponse.fromJson(jsonDecode(response.body));
  }

  /// Lobby acknowledges physical arrival (ONTHEWAY -> ARRIVED).
  Future<void> arriveVehicle(int parkingVehicleId, {String? idempotencyKey}) async {
    final headers = await _headers(idempotencyKey: idempotencyKey);
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/arrive'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// ONTHEWAY or ARRIVED -> DELIVERED.
  Future<void> deliverVehicle(int parkingVehicleId, {String? idempotencyKey}) async {
    final headers = await _headers(idempotencyKey: idempotencyKey);
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/deliver'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
  }

  /// Desk mistake recovery: moves the ticket one step back (Requested -> Parked, On the way ->
  /// Requested, At lobby -> On the way, Delivered -> At lobby). Returns the server's message.
  Future<String> undoLastStep(int parkingVehicleId, String reason) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/undo'),
          headers: headers,
          body: jsonEncode({'reason': reason}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw apiErrorFrom(response);
    }
    final body = jsonDecode(response.body);
    return (body is Map && body['message'] is String) ? body['message'] as String : 'Step undone';
  }

  Future<List<Shop>> fetchShops() async {
    final headers = await _headers();
    final response =
        await http.get(Uri.parse('$apiBaseUrl/v1/shops'), headers: headers).timeout(timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Shop.fromJson(e)).toList();
    }
    throw apiErrorFrom(response);
  }

  Future<List<ServiceType>> fetchServiceTypes() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/service-type/getServiceTypes'), headers: headers)
        .timeout(timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => ServiceType.fromJson(e)).toList();
    }
    throw apiErrorFrom(response);
  }

  Future<DashboardDetails> fetchDashboardDetails() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/dashboard/details'), headers: headers)
        .timeout(timeout);

    if (response.statusCode == 200) {
      return DashboardDetails.fromJson(jsonDecode(response.body));
    }
    throw apiErrorFrom(response);
  }
}
