// lib/services/complaint_service.dart
//
// Public (guest) complaint submission, guarded by a math captcha, plus the authenticated
// admin-side list/acknowledge/close actions. Mirrors the backend's PublicComplaintController
// and ComplaintController.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication_service.dart';

class CaptchaChallenge {
  final String token;
  final String question;

  CaptchaChallenge({required this.token, required this.question});

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return CaptchaChallenge(token: json['token'] ?? '', question: json['question'] ?? '');
  }
}

class Complaint {
  final int id;
  final String customerName;
  final String mobile;
  final String? place;
  final String message;
  final String status; // OPEN / ACKNOWLEDGED / CLOSED
  final String? createdAt;
  final String? acknowledgedAt;
  final String? closedAt;
  final String? resolutionNotes;

  Complaint({
    required this.id,
    required this.customerName,
    required this.mobile,
    this.place,
    required this.message,
    required this.status,
    this.createdAt,
    this.acknowledgedAt,
    this.closedAt,
    this.resolutionNotes,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'],
      customerName: json['customerName'] ?? '',
      mobile: json['mobile'] ?? '',
      place: json['place'],
      message: json['message'] ?? '',
      status: json['status'] ?? 'OPEN',
      createdAt: json['createdAt'],
      acknowledgedAt: json['acknowledgedAt'],
      closedAt: json['closedAt'],
      resolutionNotes: json['resolutionNotes'],
    );
  }
}

class ComplaintApiException implements Exception {
  final String message;
  ComplaintApiException(this.message);
  @override
  String toString() => message;
}

class ComplaintService {
  static const String apiBaseUrl = AuthenticationService.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 30);

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Request failed (${response.statusCode})';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }

  Future<CaptchaChallenge> getCaptcha() async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/public/complaints/captcha'))
        .timeout(timeout);
    if (response.statusCode == 200) {
      return CaptchaChallenge.fromJson(jsonDecode(response.body));
    }
    throw ComplaintApiException(_errorMessage(response));
  }

  Future<Complaint> submit({
    required String companyCode,
    required String customerName,
    required String mobile,
    String? place,
    required String message,
    required String captchaToken,
    required int captchaAnswer,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/public/complaints/$companyCode'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'customerName': customerName,
            'mobile': mobile,
            if (place != null && place.isNotEmpty) 'place': place,
            'message': message,
            'captchaToken': captchaToken,
            'captchaAnswer': captchaAnswer,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ComplaintApiException(_errorMessage(response));
    }
    return Complaint.fromJson(jsonDecode(response.body));
  }

  /// Public status check by reference number (the complaint id) + the mobile number it was
  /// submitted with - no account needed, matching how the complaint itself was filed.
  Future<Complaint> checkStatus({
    required String companyCode,
    required int reference,
    required String mobile,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/public/complaints/$companyCode/$reference')
        .replace(queryParameters: {'mobile': mobile});
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode == 200) {
      return Complaint.fromJson(jsonDecode(response.body));
    }
    throw ComplaintApiException(_errorMessage(response));
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthenticationService.tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Complaint>> listComplaints({String? status}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$apiBaseUrl/v1/complaints').replace(
      queryParameters: status != null ? {'status': status} : null,
    );
    final response = await http.get(uri, headers: headers).timeout(timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Complaint.fromJson(e)).toList();
    }
    throw ComplaintApiException(_errorMessage(response));
  }

  Future<void> acknowledge(int id) async {
    final headers = await _authHeaders();
    final response = await http
        .post(Uri.parse('$apiBaseUrl/v1/complaints/$id/acknowledge'), headers: headers)
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ComplaintApiException(_errorMessage(response));
    }
  }

  Future<void> close(int id, {String? resolutionNotes}) async {
    final headers = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/complaints/$id/close'),
          headers: headers,
          body: jsonEncode({if (resolutionNotes != null) 'resolutionNotes': resolutionNotes}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ComplaintApiException(_errorMessage(response));
    }
  }
}
