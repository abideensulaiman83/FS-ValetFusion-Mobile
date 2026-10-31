// lib/services/plan_service.dart
//
// The company's plan (GET /api/v1/plan - PlanController / PlanDTO on the backend): Free, Premium
// or Customized, which Premium features are on, and the trial clock. Loaded once after login (and
// on a restored session), refreshed when the app comes back to the front and whenever a call is
// refused with PLAN_REQUIRED. Screens read PlanController.instance.plan to put a star on Premium
// entry points and to decide whether tapping one opens the feature or the "Part of Premium" sheet.
// The server is the real gate: an unknown plan (offline, not loaded yet) never locks anything.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'authentication_service.dart';
import 'secure_store.dart';
import 'valet_service.dart' show ValetApiException;

/// Premium feature keys, as in PlanFeature.java.
class PremiumFeature {
  PremiumFeature._();
  static const String damageMarking = 'DAMAGE_MARKING';
  static const String supervisors = 'SUPERVISORS';
  static const String advancedReports = 'ADVANCED_REPORTS';
  static const String operatorGroups = 'OPERATOR_GROUPS';
  static const String branding = 'BRANDING';

  /// Fallback labels for when the plan has not been loaded.
  static String label(String key) => const {
        damageMarking: 'Damage marking & condition photos',
        supervisors: 'Supervisors with GPS check-in',
        advancedReports: 'Advanced reports',
        operatorGroups: 'Operator groups & Operations Overview',
        branding: 'Venue branding',
      }[key] ??
      'This feature';
}

class PlanFeatureInfo {
  final String key;
  final String label;
  final String? description;
  final bool enabled;
  final String? source; // PLAN, TRIAL, OVERRIDE, SUPER_ADMIN; null when locked

  const PlanFeatureInfo({required this.key, required this.label, this.description, required this.enabled, this.source});

  factory PlanFeatureInfo.fromJson(Map<String, dynamic> j) => PlanFeatureInfo(
        key: (j['key'] as String?) ?? '',
        label: (j['label'] as String?) ?? (j['key'] as String? ?? ''),
        description: j['description'] as String?,
        enabled: j['enabled'] == true,
        source: j['source'] as String?,
      );
}

class PlanInfo {
  final String tier; // FREE, PREMIUM, CUSTOMIZED
  final String planName;
  final String? companyName;
  final bool trialActive;
  final DateTime? trialEndsAt;
  final bool canUpgrade;
  final bool canStartTrial;
  final bool companyAdmin;
  final bool superAdmin;
  final List<PlanFeatureInfo> features;

  const PlanInfo({
    required this.tier,
    required this.planName,
    this.companyName,
    this.trialActive = false,
    this.trialEndsAt,
    this.canUpgrade = false,
    this.canStartTrial = false,
    this.companyAdmin = false,
    this.superAdmin = false,
    this.features = const [],
  });

  factory PlanInfo.fromJson(Map<String, dynamic> j) => PlanInfo(
        tier: (j['tier'] as String?) ?? 'FREE',
        planName: (j['planName'] as String?) ?? 'Free',
        companyName: j['companyName'] as String?,
        trialActive: j['trialActive'] == true,
        trialEndsAt: j['trialEndsAt'] is String ? DateTime.tryParse(j['trialEndsAt'] as String) : null,
        canUpgrade: j['canUpgrade'] == true,
        canStartTrial: j['canStartTrial'] == true,
        companyAdmin: j['companyAdmin'] == true,
        superAdmin: j['superAdmin'] == true,
        features: ((j['features'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => PlanFeatureInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  bool get isFree => tier == 'FREE';

  PlanFeatureInfo? feature(String key) {
    for (final f in features) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// Unknown features count as enabled - the server decides.
  bool has(String key) => superAdmin || (feature(key)?.enabled ?? true);

  /// "Free plan", "Premium", "Premium until 14 Nov 2026" (trial), or the package's own name.
  String get headerLabel {
    if (trialActive && trialEndsAt != null) {
      return 'Premium until ${DateFormat('d MMM yyyy').format(trialEndsAt!)}';
    }
    switch (tier) {
      case 'FREE':
        return 'Free plan';
      case 'PREMIUM':
        return 'Premium';
      default:
        return planName.isEmpty ? 'Customized' : planName;
    }
  }
}

/// HTTP 402 {code: PLAN_REQUIRED, feature, featureLabel, plan, message} from any endpoint.
class PlanRequiredException extends ValetApiException {
  final String? feature;
  final String featureLabel;
  PlanRequiredException(super.message, {this.feature, required this.featureLabel});
}

/// Turns a failed response into the exception the screens catch. PLAN_REQUIRED becomes a
/// [PlanRequiredException] and is reported to [PlanController], which shows the Premium sheet
/// once, wherever the call came from.
ValetApiException apiErrorFrom(http.Response response) {
  Map<String, dynamic>? data;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) data = decoded;
  } catch (_) {}
  if (response.statusCode == 402 && (data == null || data['code'] == null || data['code'] == 'PLAN_REQUIRED')) {
    final feature = data?['feature'] as String?;
    final label = (data?['featureLabel'] as String?) ?? (feature != null ? PremiumFeature.label(feature) : 'This feature');
    final e = PlanRequiredException('$label is part of Premium - ask your company admin.', feature: feature, featureLabel: label);
    PlanController.instance.reportBlocked(e);
    return e;
  }
  final message = data == null ? null : (data['message'] ?? data['error']);
  return ValetApiException(message is String && message.isNotEmpty ? message : 'Request failed (${response.statusCode})');
}

class PlanService {
  Future<PlanInfo> fetch() async {
    final token = await SecureStore.token();
    final response = await http.get(Uri.parse('${AuthenticationService.apiBaseUrl}/v1/plan'), headers: {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw apiErrorFrom(response);
    return PlanInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

/// The signed-in company's plan, cached for the session.
class PlanController {
  PlanController._();
  static final PlanController instance = PlanController._();

  final ValueNotifier<PlanInfo?> plan = ValueNotifier<PlanInfo?>(null);
  final PlanService _service = PlanService();
  Future<void>? _loading;
  DateTime? _loadedAt;

  /// Set by the app shell (main.dart): shows the "Part of Premium" sheet.
  static void Function(PlanRequiredException e)? onBlocked;

  /// Loads the plan; with [force] false a plan fetched in the last 5 minutes is kept.
  Future<void> load({bool force = false}) {
    if (!force && plan.value != null && _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    return _loading ??= _doLoad().whenComplete(() => _loading = null);
  }

  Future<void> _doLoad() async {
    try {
      plan.value = await _service.fetch();
      _loadedAt = DateTime.now();
    } catch (_) {
      // Offline or not signed in - keep what we had; nothing is locked on an unknown plan.
    }
  }

  void clear() {
    plan.value = null;
    _loadedAt = null;
  }

  bool has(String featureKey) => plan.value?.has(featureKey) ?? true;

  String labelFor(String featureKey) => plan.value?.feature(featureKey)?.label ?? PremiumFeature.label(featureKey);

  DateTime? _lastBlocked;

  void reportBlocked(PlanRequiredException e) {
    // The feature may just have been switched off (trial over) - refresh the badges.
    load(force: true);
    final now = DateTime.now();
    if (_lastBlocked != null && now.difference(_lastBlocked!) < const Duration(seconds: 2)) return;
    _lastBlocked = now;
    onBlocked?.call(e);
  }
}
