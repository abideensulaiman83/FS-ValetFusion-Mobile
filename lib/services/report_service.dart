// lib/services/report_service.dart
//
// Company reports for the Admin Console (the "Media One" style daily reports the web console
// shows): the ops reports under /v1/reports/ops/{name}, plus /v1/reports/validations and
// /v1/reports/staff. Each report is a JSON GET and has /export/pdf and /export/excel siblings that
// return the file. A Premium refusal (402 PLAN_REQUIRED) goes through apiErrorFrom, which shows
// the Premium sheet once and throws a PlanRequiredException for the screen.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'authentication_service.dart';
import 'plan_service.dart';
import 'secure_store.dart';
import 'valet_service.dart' show ValetApiException;

enum ReportFileFormat { pdf, excel }

extension ReportFileFormatX on ReportFileFormat {
  /// The path segment after /export/.
  String get segment => this == ReportFileFormat.pdf ? 'pdf' : 'excel';
  String get extension => this == ReportFileFormat.pdf ? 'pdf' : 'xlsx';
  String get mimeType =>
      this == ReportFileFormat.pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}

class ReportService {
  static const Duration _timeout = Duration(seconds: 30);
  // Exports are built on the server - give a long period / big PDF time to come back.
  static const Duration _exportTimeout = Duration(seconds: 90);

  Uri _uri(String path, Map<String, String> params) {
    final base = Uri.parse('${AuthenticationService.apiBaseUrl}$path');
    return params.isEmpty ? base : base.replace(queryParameters: params);
  }

  Future<Map<String, String>> _headers(String accept) async {
    final token = await SecureStore.token();
    return {'Accept': accept, if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// GET [path] (relative to the API base, e.g. /v1/reports/ops/overview) as a JSON object.
  Future<Map<String, dynamic>> fetch(String path, Map<String, String> params) async {
    final response = await http.get(_uri(path, params), headers: await _headers('application/json')).timeout(_timeout);
    if (response.statusCode != 200) throw apiErrorFrom(response);
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ValetApiException('Unexpected response from the server');
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw ValetApiException('Unexpected response from the server');
  }

  /// Downloads [path]/export/{pdf|excel} into the app's temp folder and returns the file.
  Future<File> download(String path, Map<String, String> params, ReportFileFormat format, String baseName) async {
    final response = await http
        .get(_uri('$path/export/${format.segment}', params), headers: await _headers('*/*'))
        .timeout(_exportTimeout);
    if (response.statusCode != 200) throw apiErrorFrom(response);
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (response.bodyBytes.isEmpty) throw ValetApiException('The server returned an empty file');
    if (contentType.contains('json') || contentType.contains('text/html')) {
      throw ValetApiException('The server did not return a file');
    }
    final dir = Directory('${(await getTemporaryDirectory()).path}/reports');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeName = baseName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final file = File('${dir.path}/$safeName.${format.extension}');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}

/// A short English message for a failed report call (screens pass it through tr()).
String reportErrorMessage(Object e) {
  if (e is ValetApiException) return e.message;
  if (e is TimeoutException) return 'The server took too long to respond. Try again.';
  if (e is SocketException || e is http.ClientException) return 'No connection. Check the network and try again.';
  if (e is FileSystemException) return 'Could not save the file on this phone.';
  return 'Something went wrong. Try again.';
}
