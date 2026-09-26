// lib/services/valet_service.dart
//
// Mirrors the web app's Valet Desk API surface (frontend/FS-ValetFusion/src/pages/DashboardPage.tsx)
// against the same backend contract (backend/evaletFusion .../ParkingVehicleController.java).
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication_service.dart';

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

  DriverOption({required this.id, required this.name, this.phone});

  factory DriverOption.fromJson(Map<String, dynamic> json) {
    return DriverOption(
      id: json['id'],
      name: (json['name'] as String?)?.trim().isEmpty ?? true ? 'Driver #${json['id']}' : json['name'],
      phone: json['phone'],
    );
  }
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

  DashboardDetails({
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

class TrackingCompany {
  final String code;
  final String name;
  TrackingCompany(this.code, this.name);
}

class ValetService {
  static const String apiBaseUrl = AuthenticationService.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 30);

  /// The signed-in user's company code, for the guest tracking link (/track/<CODE>/<TICKET>).
  Future<TrackingCompany> fetchTrackingCompany() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/master-locations/mine/tracking-code'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TrackingCompany(data['code'] as String, data['name'] as String? ?? '');
  }

  // companyCode: only needed when a CUSTOMER is looking up/acting on a ticket at a *different*
  // property than the one their account was created at (see CustomerHomePage's location picker).
  // The backend's JwtAuthenticationFilter re-points the tenant DB for this request when it sees
  // X-Company-Code on a CUSTOMER token - ignored (and ignored server-side) for every other role.
  Future<Map<String, String>> _headers({String? companyCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthenticationService.tokenKey);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (companyCode != null && companyCode.isNotEmpty) 'X-Company-Code': companyCode,
    };
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? data['error'] ?? 'Request failed (${response.statusCode})';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
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
    throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// Key Controller assigns/corrects the key holder (hook/board) number for an
  /// already-received vehicle - covers the in-person ticket+key handoff path.
  Future<void> assignKeyHolder({required int parkingVehicleId, required String keyHolderNo}) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/key-holder'),
          headers: headers,
          body: jsonEncode({'keyHolderNo': keyHolderNo}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
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
  }) async {
    final headers = await _headers();
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
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
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
    throw ValetApiException(_errorMessage(response));
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
  }) async {
    final headers = await _headers(companyCode: companyCode);
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
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// Mirrors VehicleDispatchDTO. Pass driverId (preferred, from fetchAvailableDrivers) or vpaOut
  /// free-text as a fallback - the server resolves driverId into vpaOut itself.
  Future<void> dispatchVehicle({required int parkingVehicleId, String? vpaOut, int? driverId}) async {
    final headers = await _headers();
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
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// Active DRIVER-role users the Key Controller can assign at dispatch time.
  Future<List<DriverOption>> fetchAvailableDrivers() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/available-drivers'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// Customer requests a wash for their parked (RECEIVED) car - independent of the pickup flow.
  Future<void> requestWash(int parkingVehicleId, {String? companyCode}) async {
    final headers = await _headers(companyCode: companyCode);
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/wash-request'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// Key Controller/Driver's "Wash Requests" list - pending/in-progress jobs.
  Future<List<TicketStatusResponse>> fetchWashRequests() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/wash-requests'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// Customer's "My Parking History".
  Future<List<CustomerHistoryEntry>> fetchMyHistory() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/my-history'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
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
      throw ValetApiException(_errorMessage(response));
    }
    return TicketStatusResponse.fromJson(jsonDecode(response.body));
  }

  /// Lobby acknowledges physical arrival (ONTHEWAY -> ARRIVED).
  Future<void> arriveVehicle(int parkingVehicleId) async {
    final headers = await _headers();
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/arrive'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
    }
  }

  /// ONTHEWAY or ARRIVED -> DELIVERED.
  Future<void> deliverVehicle(int parkingVehicleId) async {
    final headers = await _headers();
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/deliver'), headers: headers)
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ValetApiException(_errorMessage(response));
    }
  }

  Future<List<Shop>> fetchShops() async {
    final headers = await _headers();
    final response =
        await http.get(Uri.parse('$apiBaseUrl/v1/shops'), headers: headers).timeout(timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Shop.fromJson(e)).toList();
    }
    throw ValetApiException(_errorMessage(response));
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
    throw ValetApiException(_errorMessage(response));
  }

  Future<DashboardDetails> fetchDashboardDetails() async {
    final headers = await _headers();
    final response = await http
        .get(Uri.parse('$apiBaseUrl/v1/parking-vehicles/dashboard/details'), headers: headers)
        .timeout(timeout);

    if (response.statusCode == 200) {
      return DashboardDetails.fromJson(jsonDecode(response.body));
    }
    throw ValetApiException(_errorMessage(response));
  }
}
