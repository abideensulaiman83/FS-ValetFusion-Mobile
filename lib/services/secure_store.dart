// lib/services/secure_store.dart
//
// Secrets - the session token and "Remember me" passwords - live in the platform keystore
// (Android Keystore-backed encryption / iOS Keychain), not in SharedPreferences, which is a plain
// XML file anyone with the device backup or root can read. Everything non-secret (user profile,
// roles, settings) stays in SharedPreferences.
//
// Values saved by older builds in SharedPreferences are moved here on first read, so an update
// keeps people signed in and keeps their saved logins.
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';

class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'vf_token';
  static const String _refreshKey = 'vf_refresh_token';

  // The token is read on every API call - keep it in memory after the first keystore read.
  static String? _token;
  static bool _tokenLoaded = false;

  static Future<String?> _read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) return value;
    } catch (_) {
      // Keystore unavailable or entry unreadable (e.g. restored from another device) - fall
      // through to the legacy copy, if any.
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null) {
      try {
        await _storage.write(key: key, value: legacy);
        await prefs.remove(key);
      } catch (_) {}
    }
    return legacy;
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Last resort so login still works on a device with a broken keystore.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key); // never leave a plain copy behind
  }

  static Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // ── Session token ──────────────────────────────────────────────────────
  // Access tokens last 30 minutes (plan B5). Every caller goes through token(), so renewing
  // here keeps the whole app - including background GPS - signed in without each service
  // knowing about refresh tokens.
  static Future<String?>? _renewing;

  static Future<String?> token() async {
    if (!_tokenLoaded) {
      _token = await _read(_tokenKey);
      _tokenLoaded = true;
    }
    final t = _token;
    if (t != null && _expiresWithin(t, const Duration(minutes: 2))) {
      final renewed = await _renew();
      if (renewed != null) return renewed;
    }
    return t;
  }

  static Future<void> setToken(String token, {String? refreshToken}) async {
    _token = token;
    _tokenLoaded = true;
    await _write(_tokenKey, token);
    if (refreshToken != null && refreshToken.isNotEmpty) await _write(_refreshKey, refreshToken);
  }

  static Future<String?> refreshToken() => _read(_refreshKey);

  static Future<void> clearToken() async {
    _token = null;
    _tokenLoaded = true;
    await _delete(_tokenKey);
    await _delete(_refreshKey);
  }

  /// Seconds-until-expiry from the JWT's exp claim; true when missing or unreadable so a
  /// renewal is at least attempted.
  static bool _expiresWithin(String jwt, Duration window) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false;
      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return expiry.difference(DateTime.now().toUtc()) < window;
    } catch (_) {
      return false;
    }
  }

  /// One renewal at a time; concurrent callers share it. Returns the new access token or null.
  static Future<String?> _renew() {
    final inFlight = _renewing;
    if (inFlight != null) return inFlight;
    final f = _doRenew().whenComplete(() => _renewing = null);
    _renewing = f;
    return f;
  }

  static Future<String?> _doRenew() async {
    final refresh = await _read(_refreshKey);
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final res = await http
          .post(Uri.parse('${Environment.apiBaseUrl}/auth/refresh'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'refreshToken': refresh}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        if (res.statusCode == 401) await _delete(_refreshKey); // revoked or expired: sign-in needed
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final access = data['accessToken'] as String?;
      if (access == null) return null;
      await setToken(access, refreshToken: data['refreshToken'] as String?);
      return access;
    } catch (_) {
      return null; // offline: keep using the current token until it really expires
    }
  }

  // ── Other secrets (saved passwords) ────────────────────────────────────
  static Future<String?> read(String key) => _read(key);
  static Future<void> write(String key, String value) => _write(key, value);
  static Future<void> delete(String key) => _delete(key);
}
