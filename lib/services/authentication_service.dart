import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PublicCompanyOption {
  final String code;
  final String name;
  final double? pickupLat;
  final double? pickupLng;

  PublicCompanyOption({required this.code, required this.name, this.pickupLat, this.pickupLng});

  factory PublicCompanyOption.fromJson(Map<String, dynamic> json) {
    return PublicCompanyOption(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      pickupLat: (json['pickupLat'] as num?)?.toDouble(),
      pickupLng: (json['pickupLng'] as num?)?.toDouble(),
    );
  }
}

class UserDto {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;
  final int locationId;
  final String locationCode;
  final String locationName;
  final int tenantId;
  final String tenantCode;

  UserDto({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.tenantId,
    required this.tenantCode,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      locationId: json['locationId'] ?? 0,
      locationCode: json['locationCode'] ?? '',
      locationName: json['locationName'] ?? '',
      tenantId: json['tenantId'] ?? 0,
      tenantCode: json['tenantCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'roles': roles,
      'locationId': locationId,
      'locationCode': locationCode,
      'locationName': locationName,
      'tenantId': tenantId,
      'tenantCode': tenantCode,
    };
  }
}

class LocationDto {
  final int id;
  final String code;
  final String name;
  final String tenantCode;
  final bool defaultForUser;

  LocationDto({
    required this.id,
    required this.code,
    required this.name,
    required this.tenantCode,
    required this.defaultForUser,
  });

  factory LocationDto.fromJson(Map<String, dynamic> json) {
    return LocationDto(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      tenantCode: json['tenantCode'] ?? '',
      defaultForUser: json['defaultForUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'tenantCode': tenantCode,
      'defaultForUser': defaultForUser,
    };
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserDto user;
  final List<LocationDto>? locations;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    this.locations,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      expiresIn: json['expiresIn'] ?? 0,
      user: UserDto.fromJson(json['user'] ?? {}),
      locations: json['locations'] != null
          ? (json['locations'] as List)
          .map((loc) => LocationDto.fromJson(loc))
          .toList()
          : null,
    );
  }
}

class AuthenticationService {
  static const String apiBaseUrl = 'https://valetfusion.focalsoft.ae/api';

  static const Duration timeout = Duration(seconds: 30);

  // Storage keys
  static const String tokenKey = 'vf_token';
  static const String userKey = 'vf_user';
  static const String locationKey = 'vf_location';
  static const String pendingUserKey = 'vf_pending_user';
  static const String pendingLocationsKey = 'vf_pending_locations';
  static const String rememberedUsernameKey = 'vf_remembered_username';
  static const String rememberedPasswordKey = 'vf_remembered_password';

  // "Remember me" on the login form itself - separate from staying logged in across app
  // restarts (see SplashPage, which checks the saved token/session). This just pre-fills the
  // username/password fields next time, for after an explicit logout. Kept in SharedPreferences
  // like the rest of this app's local storage (the session token included) rather than a secure
  // keystore, to match the existing security posture without adding a new native dependency.
  Future<void> saveRememberedCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(rememberedUsernameKey, username);
    await prefs.setString(rememberedPasswordKey, password);
  }

  Future<Map<String, String>?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(rememberedUsernameKey);
    final password = prefs.getString(rememberedPasswordKey);
    if (username == null || password == null) return null;
    return {'username': username, 'password': password};
  }

  Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(rememberedUsernameKey);
    await prefs.remove(rememberedPasswordKey);
  }

  // Biometric sign-in: an opt-in shortcut over "Remember me" above, not a separate credential
  // store - Face ID/fingerprint just unlocks the same remembered username/password and submits
  // them, the same as if the user had typed them in. So this only ever makes sense (and only
  // ever gets offered) once remembered credentials already exist.
  static const String biometricEnabledKey = 'vf_biometric_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(biometricEnabledKey, enabled);
  }

  /// Whether this device can actually prompt for Face ID/fingerprint right now - has the
  /// hardware, and the user has actually enrolled a face/fingerprint with the OS. Checked fresh
  /// each time rather than cached, since enrollment can change (e.g. fingerprints cleared) after
  /// the app was first opened.
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns true only on a genuine successful Face ID/fingerprint match - false for a user
  /// cancel, a lockout, or any plugin error, so callers can treat "not authenticated" uniformly
  /// without needing to inspect the failure reason.
  Future<bool> authenticateWithBiometrics({String reason = 'Sign in to Valet Fusion'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Login API - Authenticates user and returns token + user info
  Future<LoginResponse> loginApi({
    required String username,
    required String password,
    String? locationCode,
  }) async {
    developer.log('api call start');
    developer.log(' HTTP request to: $apiBaseUrl/auth/login');

    // Log request details
    developer.log(' Request Headers:');
    developer.log(' Content-Type: application/json');
    developer.log(' Accept: application/json');

    developer.log('Request Body (payload):');
    developer.log('{');
    developer.log('"username": "$username",');
    developer.log('"password": "******** (${password.length} characters)",');
    if (locationCode != null) {
      developer.log('"locationCode": "$locationCode",');
    }
    developer.log('}');
    developer.log(' Request Timestamp: ${DateTime.now().toIso8601String()}');
    developer.log('Timeout: $timeout');

    try {
      final url = Uri.parse('$apiBaseUrl/auth/login');

      final payload = {
        'username': username,
        'password': password,
        if (locationCode != null) 'locationCode': locationCode,
      };

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      )
          .timeout(timeout);

      // Log response details
      developer.log(' RESPONSE');
      developer.log('Status Code: ${response.statusCode}');
      developer.log('Headers:');
      response.headers.forEach((key, value) {
        developer.log('   $key: $value');
      });

      developer.log(' Body (raw):');
      developer.log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['accessToken'] == null) {
          developer.log(' ERROR: Invalid response format - missing accessToken');
          throw Exception('Invalid response format from server');
        }

        // Parse the response
        final loginResponse = LoginResponse.fromJson(data);

        // Log successful response details
        

        if (loginResponse.locations != null && loginResponse.locations!.isNotEmpty) {
          developer.log(' Available Locations (${loginResponse.locations!.length}):');
          for (var loc in loginResponse.locations!) {
            developer.log('   - ${loc.name} (ID: ${loc.id}, Code: ${loc.code})');
          }
        } else {
          developer.log(' No additional locations available');
        }

        developer.log(' ========== API CALL END ==========');
        return loginResponse;
      } else {
        // Log error response
        developer.log(' ========== API ERROR ==========');
        developer.log(' HTTP Error ${response.statusCode}');

        // Invalid credentials come back as 400/401 with a JSON {"message": "..."} body - that
        // message ("Invalid username or password") is what should reach the user, not a generic
        // "status 400" popup. Parsing is separated from the throw below so a *parse* failure
        // (e.g. an HTML error page instead of JSON) doesn't also swallow a *successfully parsed*
        // server message - a bug that was previously catching its own deliberate throw.
        String errorMessage = 'Login failed with status ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          developer.log(' Error Body: ${jsonEncode(errorData)}');
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (_) {
          developer.log(' Raw Error Response: ${response.body}');
        }
        developer.log(' Error Message: $errorMessage');
        developer.log(' ========== ERROR END ==========');
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      developer.log(' ========== NETWORK ERROR ==========');
      developer.log(' Network/Connection Error: $e');
      developer.log(' Please check your internet connection');
      developer.log(' ========== ERROR END ==========');
      throw Exception('Network error: Please check your internet connection');
    } on FormatException catch (e) {
      developer.log(' ========== JSON PARSE ERROR ==========');
      developer.log(' JSON Parse Error: $e');
      developer.log(' Invalid JSON response from server');
      developer.log(' ========== ERROR END ==========');
      throw Exception('Server response format error');
    } on Exception catch (e) {
      developer.log(' ========== UNEXPECTED ERROR ==========');
      developer.log(' Exception: $e');
      developer.log(' ========== ERROR END ==========');
      rethrow;
    }
  }

  /// Active companies for the sign-up screen's "Select your property" dropdown - no auth needed.
  Future<List<PublicCompanyOption>> fetchPublicCompanies() async {
    final url = Uri.parse('$apiBaseUrl/public/companies');
    final response = await http.get(url).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Could not load the property list - please try again.');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((e) => PublicCompanyOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Requests a password reset code by email - same for every role (Driver, Customer, staff, all
  /// share the same CentralUser/email login). Backend responds identically whether or not the
  /// email is registered, so there's nothing to distinguish here either.
  Future<void> requestPasswordReset(String email) async {
    final url = Uri.parse('$apiBaseUrl/auth/forgot-password');
    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email}))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }
  }

  /// Completes the reset with the emailed code + a new password.
  Future<void> resetPassword({required String code, required String newPassword}) async {
    final url = Uri.parse('$apiBaseUrl/auth/reset-password');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': code, 'newPassword': newPassword}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Request failed (${response.statusCode})';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }

  /// Guest self-registration - creates a CUSTOMER-role account scoped to one property (found by
  /// its company code) and logs them straight in. Mirrors /auth/login's response shape exactly,
  /// since the backend just calls the same authenticate() internally after creating the account.
  Future<LoginResponse> registerCustomer({
    required String companyCode,
    required String mobile,
    required String password,
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      final url = Uri.parse('$apiBaseUrl/auth/customer/register');
      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'companyCode': companyCode,
          'mobile': mobile,
          'password': password,
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
          if (email != null) 'email': email,
        }),
      )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['accessToken'] == null) {
          throw Exception('Invalid response format from server');
        }
        return LoginResponse.fromJson(data);
      } else {
        // Same fix as loginApi: extract the message without the parse attempt's own catch
        // swallowing a successfully-parsed one.
        String errorMessage = 'Registration failed with status ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {
          // Body wasn't valid JSON - keep the generic status-based message.
        }
        throw Exception(errorMessage);
      }
    } on http.ClientException {
      throw Exception('Network error: Please check your internet connection');
    }
  }

  Future<List<LocationDto>> fetchActiveLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);

      final url = Uri.parse('$apiBaseUrl/master-locations/status/ACTIVE');

      developer.log(' Fetching active locations from: ${url.path}');

      final response = await http
          .get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      )
          .timeout(timeout);

      developer.log(' Locations API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final locations = data.map((loc) => LocationDto.fromJson(loc)).toList();
        developer.log(' Found ${locations.length} active locations');
        return locations;
      } else {
        throw Exception('Failed to fetch locations: ${response.statusCode}');
      }
    } catch (e) {
      developer.log(' Fetch Locations Error: $e');
      throw Exception(e.toString());
    }
  }

  Future<LoginResponse> selectLocationApi({
    required int locationId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);

      final url = Uri.parse('$apiBaseUrl/auth/select-location');

      final payload = {'locationId': locationId};

      developer.log(' Selecting location ID: $locationId');

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      )
          .timeout(timeout);

      developer.log(' Location select response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['accessToken'] == null) {
          throw Exception('Invalid response format from server');
        }

        return LoginResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Location selection failed');
      }
    } catch (e) {
      developer.log(' Select Location Error: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> logoutApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);

      if (token != null) {
        final url = Uri.parse('$apiBaseUrl/auth/logout');

        developer.log(' Logging out user...');

        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(timeout);

        developer.log(' Logout API call successful');
      } else {
        developer.log(' No token found, skipping logout API call');
      }
    } catch (e) {
      developer.log(' Logout API error (continuing with local cleanup): $e');
    } finally {
      await clearStorage();
      developer.log(' Storage cleared successfully');
    }
  }

  Future<void> clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
    await prefs.remove(locationKey);
    await prefs.remove(pendingUserKey);
    await prefs.remove(pendingLocationsKey);
    developer.log(' All storage keys cleared');
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    final user = prefs.getString(userKey);

    final isAuth = token != null && user != null;
    developer.log(' Authentication check: $isAuth');
    return isAuth;
  }

  /// Get current user
  Future<UserDto?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(userKey);

    if (userStr == null) {
      developer.log(' No user found in storage');
      return null;
    }

    try {
      final userJson = jsonDecode(userStr);
      final user = UserDto.fromJson(userJson);
      developer.log(' Retrieved user from storage: ${user.username}');
      return user;
    } catch (e) {
      developer.log(' Error parsing user from storage: $e');
      return null;
    }
  }

  Future<LocationDto?> getCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationStr = prefs.getString(locationKey);

    if (locationStr == null) {
      developer.log(' No location found in storage');
      return null;
    }

    try {
      final locationJson = jsonDecode(locationStr);
      final location = LocationDto.fromJson(locationJson);
      developer.log(' Retrieved location from storage: ${location.name}');
      return location;
    } catch (e) {
      developer.log(' Error parsing location from storage: $e');
      return null;
    }
  }

  /// Get auth token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    developer.log(' Token retrieved: ${token != null ? "Yes (${token.substring(0, 10)}...)" : "No"}');
    return token;
  }

  /// Save login data to storage
  Future<void> saveLoginData({
    required String token,
    required UserDto user,
    LocationDto? location,
  }) async {
    developer.log(' Saving login data to storage...');

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(tokenKey, token);
    developer.log('    Token saved');

    await prefs.setString(userKey, jsonEncode(user.toJson()));
    developer.log('    User saved: ${user.username}');

    if (location != null) {
      await prefs.setString(locationKey, jsonEncode(location.toJson()));
      developer.log('    Location saved: ${location.name}');
    } else {
      developer.log('    No location to save');
    }

    developer.log(' Storage save complete!');
  }
}