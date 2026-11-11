// lib/services/shop_service.dart
//
// The outlet (SHOP_VALIDATOR) login's own calls, mirroring the web ShopValidatePage
// (frontend/FS-ValetFusion/src/pages/ShopValidatePage.tsx): its shop and what it may do
// (GET /v1/shops/mine), validating a ticket and requesting the car. The ticket itself is read with
// ValetService.checkTicketStatus - for a shop login ticket-status adds shopCharge, shopValidated,
// validatedShopName and applicableCharge.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'authentication_service.dart';
import 'plan_service.dart' show PlanRequiredException, apiErrorFrom;
import 'secure_store.dart';
import 'valet_service.dart' show ValetApiException;

/// Mirrors MyShopDTO. A missing (null) flag counts as on - older shops and older servers.
class MyShop {
  final int? id;
  final String name;
  final bool canValidate;
  final bool canRequest;
  final bool web; // "Web Access" in the Edit Shop dialog
  final bool mobile; // "Mobile Access": off = this app shows the switched-off message only

  const MyShop({
    required this.id,
    required this.name,
    this.canValidate = true,
    this.canRequest = true,
    this.web = true,
    this.mobile = true,
  });

  /// May call for any parked car but never validates; the guest pays at the valet desk.
  bool get requestOnly => canRequest && !canValidate;

  factory MyShop.fromJson(Map<String, dynamic> json) => MyShop(
        id: (json['id'] as num?)?.toInt(),
        name: (json['shopName'] as String?) ?? '',
        canValidate: json['canValidate'] != false,
        canRequest: json['canRequest'] != false,
        web: json['web'] != false,
        mobile: json['mobile'] != false,
      );
}

/// A refused shop call: the HTTP status (403 capability off, 409 conflict, 400 bad state) and the
/// server's message when it sent one.
class ShopApiException extends ValetApiException {
  final int statusCode;
  final bool hasServerMessage;
  ShopApiException(super.message, {required this.statusCode, required this.hasServerMessage});
}

/// The message to show for a failed shop call (English - screens pass it through tr()). The
/// server's own message wins; [conflict] is used for a 409 without one, [fallback] otherwise.
String shopErrorMessage(Object e, {required String fallback, String? conflict}) {
  if (e is ShopApiException) {
    if (e.hasServerMessage) return e.message;
    return e.statusCode == 409 && conflict != null ? conflict : fallback;
  }
  if (e is ValetApiException) return e.message;
  if (e is TimeoutException) return 'The server took too long to respond. Try again.';
  if (e is SocketException || e is http.ClientException || e is HandshakeException) {
    return 'No connection. Check the network and try again.';
  }
  return fallback;
}

/// "12.50", or "-" when unknown - as the web page shows prices.
String shopMoney(double? n) => n == null ? '-' : n.toStringAsFixed(2);

/// A charge of 0 to the cent (the web compares toFixed(2) with 0); unknown is not 0.
bool isZeroCharge(double? c) => c != null && c.abs() < 0.005;

class ShopService {
  static const String apiBaseUrl = AuthenticationService.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final token = await SecureStore.token();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // PLAN_REQUIRED still opens the Premium sheet (apiErrorFrom); anything else keeps its status.
  Exception _error(http.Response response) {
    final e = apiErrorFrom(response);
    if (e is PlanRequiredException) return e;
    bool fromServer = false;
    try {
      final data = jsonDecode(response.body);
      final m = data is Map ? data['message'] : null;
      fromServer = m is String && m.isNotEmpty;
    } catch (_) {}
    return ShopApiException(e.message, statusCode: response.statusCode, hasServerMessage: fromServer);
  }

  /// The signed-in outlet login's own shop and what it may do.
  Future<MyShop> fetchMine() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/v1/shops/mine'), headers: await _headers()).timeout(timeout);
    if (response.statusCode != 200) throw _error(response);
    return MyShop.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Validates the ticket for this login's own outlet (ShopValidationRequestDTO).
  Future<void> validate(int parkingVehicleId, {required String shopRemarks}) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/shop-validate'),
          headers: await _headers(),
          body: jsonEncode({'shopRemarks': shopRemarks}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) throw _error(response);
  }

  /// Requests the car (VehicleRequestDTO) - the server prices it and checks the outlet may.
  Future<void> requestCar(
    int parkingVehicleId, {
    int? shopId,
    String? paymentMethod,
    double? parkingCharge,
    String? requestedRemarks,
    String? shopRemarks,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/parking-vehicles/$parkingVehicleId/request'),
          headers: await _headers(),
          body: jsonEncode({
            'shopId': ?shopId,
            'paymentMethod': ?paymentMethod,
            'parkingCharge': ?parkingCharge,
            'requestedRemarks': ?requestedRemarks,
            'shopRemarks': ?shopRemarks,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) throw _error(response);
  }
}
