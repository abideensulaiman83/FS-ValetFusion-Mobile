// lib/services/ocr_service.dart
//
// Talks to the FocalOCR ANPR server (see C:\Projects\FocalOCR\API.md) to read a vehicle's plate,
// color, and make/model/year from a single photo. This is a separate, unrelated backend from
// ValetFusion's own API - it has its own base URL and its own X-API-Key auth.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OcrPlate {
  final String? raw;
  final String? display;
  final String? emirate;
  final String? emirateCode;
  final String? category;
  final String? number;
  final double confidence;
  final String? source; // "cloud" or "local"
  final bool? verified;

  OcrPlate({
    this.raw,
    this.display,
    this.emirate,
    this.emirateCode,
    this.category,
    this.number,
    required this.confidence,
    this.source,
    this.verified,
  });

  factory OcrPlate.fromJson(Map<String, dynamic> json) {
    return OcrPlate(
      raw: json['raw'],
      display: json['display'],
      emirate: json['emirate'],
      emirateCode: json['emirate_code'],
      category: json['category'],
      number: json['number'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      source: json['source'],
      verified: json['verified'],
    );
  }
}

class OcrColor {
  final String? name;
  final double confidence;
  final String? source; // "kmeans" or "google_vision"

  OcrColor({this.name, required this.confidence, this.source});

  factory OcrColor.fromJson(Map<String, dynamic> json) {
    return OcrColor(
      name: json['name'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      source: json['source'],
    );
  }
}

class OcrVehicle {
  final String? brand;
  final double? brandConfidence;
  final String? brandSource;
  final String? model;
  final int? year;
  final double? modelConfidence;

  OcrVehicle({
    this.brand,
    this.brandConfidence,
    this.brandSource,
    this.model,
    this.year,
    this.modelConfidence,
  });

  factory OcrVehicle.fromJson(Map<String, dynamic> json) {
    return OcrVehicle(
      brand: json['brand'],
      brandConfidence: (json['brand_confidence'] as num?)?.toDouble(),
      brandSource: json['brand_source'],
      model: json['model'],
      year: json['year'],
      modelConfidence: (json['model_confidence'] as num?)?.toDouble(),
    );
  }
}

class OcrRecognitionResult {
  final OcrPlate? plate;
  final OcrColor? color;
  final OcrVehicle? vehicle;
  final bool needsReview;
  final String? reason; // set on total failure, e.g. "no_vehicle_detected"
  final double? latencySeconds;

  OcrRecognitionResult({
    this.plate,
    this.color,
    this.vehicle,
    required this.needsReview,
    this.reason,
    this.latencySeconds,
  });

  factory OcrRecognitionResult.fromJson(Map<String, dynamic> json) {
    return OcrRecognitionResult(
      plate: json['plate'] != null ? OcrPlate.fromJson(json['plate']) : null,
      color: json['color'] != null ? OcrColor.fromJson(json['color']) : null,
      vehicle: json['vehicle'] != null ? OcrVehicle.fromJson(json['vehicle']) : null,
      needsReview: json['needs_review'] ?? true,
      reason: json['reason'],
      latencySeconds: (json['latency_s'] as num?)?.toDouble(),
    );
  }
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);
  @override
  String toString() => message;
}

class OcrService {
  static const String baseUrl = 'https://vision.focalsoft.ae';
  // Server-side X-API-Key for the FocalOCR /recognize endpoint - not a ValetFusion credential.
  // Treat like a password (per FocalOCR/API.md): don't expose it outside this app's binary.
  static const String apiKey = 'DMmFJEEDDUcLiLwj3siKLZf93O3ODb5O';
  static const Duration timeout = Duration(seconds: 30);

  Future<OcrRecognitionResult> recognize(File imageFile) async {
    final uri = Uri.parse('$baseUrl/recognize');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-API-Key'] = apiKey
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return OcrRecognitionResult.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 401) {
      throw OcrException('OCR server rejected the request (invalid API key).');
    }
    throw OcrException('OCR recognition failed (${response.statusCode}).');
  }
}
