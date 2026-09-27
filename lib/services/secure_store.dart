// lib/services/secure_store.dart
//
// Secrets - the session token and "Remember me" passwords - live in the platform keystore
// (Android Keystore-backed encryption / iOS Keychain), not in SharedPreferences, which is a plain
// XML file anyone with the device backup or root can read. Everything non-secret (user profile,
// roles, settings) stays in SharedPreferences.
//
// Values saved by older builds in SharedPreferences are moved here on first read, so an update
// keeps people signed in and keeps their saved logins.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'vf_token';

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
  static Future<String?> token() async {
    if (_tokenLoaded) return _token;
    _token = await _read(_tokenKey);
    _tokenLoaded = true;
    return _token;
  }

  static Future<void> setToken(String token) async {
    _token = token;
    _tokenLoaded = true;
    await _write(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    _token = null;
    _tokenLoaded = true;
    await _delete(_tokenKey);
  }

  // ── Other secrets (saved passwords) ────────────────────────────────────
  static Future<String?> read(String key) => _read(key);
  static Future<void> write(String key, String value) => _write(key, value);
  static Future<void> delete(String key) => _delete(key);
}
