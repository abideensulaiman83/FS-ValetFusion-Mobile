// lib/components/premium.dart
//
// Premium awareness in the app: the star on Premium entry points, the "Part of Premium" sheet
// (shown when a locked entry point is tapped, and for any call refused with PLAN_REQUIRED), and
// guardPremium() for entry points. Company admins are sent to the web console to upgrade; staff
// are told to ask their company admin. The app never sells the upgrade itself.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/environment.dart';
import '../services/authentication_service.dart';
import '../services/notification_service.dart';
import '../services/plan_service.dart';
import '../theme/app_theme.dart';

/// Where company admins manage the plan.
const String kWebConsoleUrl = '${Environment.baseUrl}/home';

/// The small star next to a Premium feature's name. Filled when the feature is locked for this
/// company, outlined when the plan includes it.
class PremiumStar extends StatelessWidget {
  final String featureKey;
  final double size;
  final bool onDark;
  const PremiumStar({super.key, required this.featureKey, this.size = 16, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlanInfo?>(
      valueListenable: PlanController.instance.plan,
      builder: (context, plan, _) {
        final locked = !(plan?.has(featureKey) ?? true);
        final color = onDark || Theme.of(context).brightness == Brightness.dark ? AppColors.brassOnDark : AppColors.brass;
        return Tooltip(
          message: locked ? 'Premium - not on your plan' : 'Premium feature',
          child: Icon(locked ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: color),
        );
      },
    );
  }
}

/// Runs [action] when the company's plan includes [featureKey]; otherwise shows the Premium sheet.
void guardPremium(BuildContext context, String featureKey, VoidCallback action) {
  if (PlanController.instance.has(featureKey)) {
    action();
  } else {
    showPremiumSheet(context, featureKey: featureKey);
  }
}

Future<bool> _isCompanyAdmin() async {
  final plan = PlanController.instance.plan.value;
  if (plan != null && (plan.companyAdmin || plan.canUpgrade)) return true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(AuthenticationService.userKey);
    if (userStr == null) return false;
    final roles = List<String>.from((jsonDecode(userStr) as Map<String, dynamic>)['roles'] ?? const []);
    return roles.contains('LOCATION_ADMIN');
  } catch (_) {
    return false;
  }
}

bool _sheetOpen = false;

/// "Part of Premium - ask your company admin" (staff) or "Upgrade from the web console" (company
/// admins, with a button that opens the portal).
Future<void> showPremiumSheet(BuildContext context, {String? featureKey, String? featureLabel}) async {
  if (_sheetOpen) return;
  final admin = await _isCompanyAdmin();
  if (!context.mounted) return;
  final plan = PlanController.instance.plan.value;
  final label = featureLabel ?? (featureKey != null ? PlanController.instance.labelFor(featureKey) : 'This feature');
  final description = featureKey != null ? plan?.feature(featureKey)?.description : null;
  _sheetOpen = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final dark = theme.brightness == Brightness.dark;
        final accent = dark ? AppColors.brassOnDark : AppColors.brass;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: dark ? AppColors.inkCard2 : AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.star_rounded, color: accent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Part of Premium', style: theme.textTheme.titleLarge),
                      Text(label, style: theme.textTheme.bodyMedium),
                    ]),
                  ),
                ]),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(description, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 14),
                Text(
                  admin
                      ? 'Upgrade from the web console${plan?.canStartTrial == true ? ' - or start the free 14-day trial there' : ''}.'
                      : 'Ask your company admin - they can upgrade from the web console.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (plan != null) ...[
                  const SizedBox(height: 6),
                  Text('Your plan: ${plan.headerLabel}', style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 20),
                if (admin)
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await launchUrl(Uri.parse(kWebConsoleUrl), mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open web console'),
                  ),
                if (admin) const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(admin ? 'Not now' : 'OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    _sheetOpen = false;
  }
}

/// Wired to PlanController.onBlocked in main.dart: any API call answered with PLAN_REQUIRED shows
/// the sheet over whatever screen made it, replacing the raw error snackbar that screen showed.
void presentPlanRequired(PlanRequiredException e) {
  // Let the calling screen finish its catch block (which usually shows a snackbar) first.
  Future.delayed(const Duration(milliseconds: 120), () {
    final context = NotificationService.navigatorKey.currentState?.overlay?.context;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    showPremiumSheet(context, featureKey: e.feature, featureLabel: e.featureLabel);
  });
}
