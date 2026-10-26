// lib/config/environment.dart
//
// Build-time environment for the app. Chosen with --dart-define=VF_ENV=production|staging (the
// Gradle/Xcode flavours pass it automatically); production when not given, so an ordinary
// `flutter build` still produces the production app. Every URL in the app comes from here so a
// staging build can never talk to the production server.
class Environment {
  Environment._();

  static const String name = String.fromEnvironment('VF_ENV', defaultValue: 'production');
  static const bool isStaging = name == 'staging';

  /// Origin of the portal + API for this environment (no trailing slash).
  static const String baseUrl = isStaging ? 'https://stvf.focalsoft.ae' : 'https://valetfusion.focalsoft.ae';
  static const String apiBaseUrl = '$baseUrl/api';

  /// Shown in the app bar / splash on non-production builds so nobody confuses the two apps.
  static const String label = isStaging ? 'STAGING' : '';
}
