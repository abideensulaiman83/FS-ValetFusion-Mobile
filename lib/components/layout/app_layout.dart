// lib/components/layout/app_layout.dart
//
// The signed-in shell for staff screens (plan §2.8 / C5): a flat app bar with the venue name and
// the notifications bell, the "Update available" banner when a newer build is out, and an ink
// drawer with the venue logo (or the ValetFusion mark), who is signed in, the company's plan
// (Free / Premium / Premium until ...), the menu for their role - Premium entries starred - and
// sign-out. Only routes that exist in main.dart are listed.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../confirm_dialog.dart';
import '../../l10n/app_strings.dart';
import '../notification_bell.dart';
import '../premium.dart';
import '../../services/app_update_service.dart';
import '../../services/authentication_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_theme.dart';

class AppLayout extends StatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const AppLayout({super.key, required this.child, this.title, this.actions});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _MenuEntry {
  final String title;
  final IconData icon;
  final String route;
  final String? premiumFeature; // starred; opens the Premium sheet when the plan lacks it
  const _MenuEntry(this.title, this.icon, this.route, {this.premiumFeature});
}

class _AppLayoutState extends State<AppLayout> {
  String currentLocation = '';
  String userName = '';
  List<String> roles = const [];
  String version = '';

  @override
  void initState() {
    super.initState();
    _load();
    PlanController.instance.load(); // no-op when loaded in the last few minutes
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(AuthenticationService.userKey);
    String v = '';
    try {
      final info = await PackageInfo.fromPlatform();
      v = 'v${info.version} (${info.buildNumber})';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      version = v;
      if (userStr != null) {
        final user = jsonDecode(userStr) as Map<String, dynamic>;
        roles = List<String>.from(user['roles'] ?? const []);
        currentLocation = (user['locationName'] ?? '') as String;
        final first = (user['firstName'] ?? '') as String, last = (user['lastName'] ?? '') as String;
        userName = [first, last].where((s) => s.isNotEmpty).join(' ');
        if (userName.isEmpty) userName = (user['username'] ?? 'User') as String;
      }
    });
  }

  String roleLabel(BuildContext context) {
    const names = {
      'SUPER_ADMIN': 'Super admin', 'LOCATION_ADMIN': 'Company admin', 'KEY_CONTROLLER': 'Location manager', 'LOBBY': 'Cashier',
      'VALET_STAFF': 'Valet desk', 'DRIVER': 'Valet', 'GATE_SCANNER': 'Gate scanner', 'SUPERVISOR': 'Supervisor',
      'OPERATIONS_HEAD': 'Division head', 'SECURITY': 'Security', 'REPORT_VIEWER': 'Reports', 'CUSTOMER': 'Guest',
    };
    final known = roles.where(names.containsKey).map((r) => tr(context, names[r]!)).toList();
    return known.isEmpty ? tr(context, 'Staff') : known.join(' · ');
  }

  bool has(String r) => roles.contains(r);

  List<_MenuEntry> get mainMenu {
    final items = <_MenuEntry>[];
    if (has('SUPER_ADMIN') || has('LOCATION_ADMIN')) items.add(const _MenuEntry('Admin home', Icons.space_dashboard_rounded, '/admin/home'));
    if (has('DRIVER') || has('GATE_SCANNER') || has('KEY_CONTROLLER') || has('LOBBY') || has('VALET_STAFF') || has('LOCATION_ADMIN') || has('SUPER_ADMIN')) {
      items.add(_MenuEntry(has('DRIVER') ? 'Driver desk' : 'Valet desk', Icons.directions_car_rounded, '/dashboard'));
    }
    if (has('SUPERVISOR')) {
      items.add(const _MenuEntry('My sites', Icons.fact_check_rounded, '/supervisor/home', premiumFeature: PremiumFeature.supervisors));
    }
    if (has('SECURITY')) items.add(const _MenuEntry('Parking setup', Icons.local_parking_rounded, '/security/parking'));
    if (has('DRIVER')) items.add(const _MenuEntry('My activity', Icons.bar_chart_rounded, '/driver/activity'));
    return items;
  }

  List<_MenuEntry> get managementMenu {
    final items = <_MenuEntry>[];
    if (has('SUPER_ADMIN') || has('LOCATION_ADMIN')) items.add(const _MenuEntry('Complaints', Icons.forum_rounded, '/master/complaints'));
    return items;
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr(context, 'Sign out?'),
      message: tr(context, "You'll need your password to sign in again."),
      confirmLabel: tr(context, 'Sign out'),
      destructive: true,
    );
    if (!confirmed) return;
    await AuthenticationService().logoutApi();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _logout();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title ?? 'ValetFusion'),
              if (currentLocation.isNotEmpty)
                Text(currentLocation, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          ),
          actions: [if (widget.actions != null) ...widget.actions!, const NotificationBell()],
        ),
        drawer: Drawer(
          backgroundColor: AppColors.inkPage,
          child: SafeArea(
            child: Column(
              children: [
                _DrawerHeader(userName: userName, roleLabel: roleLabel(context), location: currentLocation),
                const Divider(color: AppColors.inkLine),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ...mainMenu.map((m) => _item(m, currentRoute)),
                      if (managementMenu.isNotEmpty) ...[
                        _sectionLabel(tr(context, 'Management')),
                        ...managementMenu.map((m) => _item(m, currentRoute)),
                      ],
                      _sectionLabel(tr(context, 'Help')),
                      _item(const _MenuEntry('Privacy & policy', Icons.privacy_tip_outlined, '/privacy-policy'), currentRoute),
                    ],
                  ),
                ),
                const Divider(color: AppColors.inkLine),
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: AppColors.inkTextSecondary),
                  title: Text(tr(context, 'Language'), style: const TextStyle(color: AppColors.inkText, fontWeight: FontWeight.w600)),
                  trailing: const LanguageToggle(color: AppColors.brassOnDark),
                  onTap: () => LocaleController.set(isArabic(context) ? 'en' : 'ar'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.inkTextSecondary),
                  title: Text(tr(context, 'Sign out'), style: const TextStyle(color: AppColors.inkText, fontWeight: FontWeight.w600)),
                  onTap: _logout,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Text('ValetFusion $version', style: const TextStyle(color: AppColors.inkTextSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            const AppUpdateBanner(),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppColors.inkTextSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
      );

  Widget _item(_MenuEntry m, String? currentRoute) {
    final active = currentRoute == m.route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        selected: active,
        selectedTileColor: AppColors.inkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: active ? const BorderSide(color: AppColors.inkLine) : BorderSide.none,
        ),
        leading: Icon(m.icon, size: 20, color: active ? AppColors.brassOnDark : AppColors.inkTextSecondary),
        title: Row(children: [
          Flexible(
            child: Text(tr(context, m.title),
                style: TextStyle(color: active ? AppColors.inkText : AppColors.inkTextBody, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
          ),
          if (m.premiumFeature != null) ...[
            const SizedBox(width: 6),
            PremiumStar(featureKey: m.premiumFeature!, size: 14, onDark: true),
          ],
        ]),
        onTap: () {
          Navigator.pop(context);
          // The star is informational here: the supervisor's own screens are checked against the
          // operator group's plan on the server (SupervisorController), not this company's, so
          // the app does not block them - a PLAN_REQUIRED from the server still opens the sheet.
          if (!active) Navigator.pushNamed(context, m.route);
        },
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String userName;
  final String roleLabel;
  final String location;
  const _DrawerHeader({required this.userName, required this.roleLabel, required this.location});

  @override
  Widget build(BuildContext context) {
    final initials = userName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase()).take(2).join();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: BrandController.logoUrl,
            builder: (context, logo, _) => logo != null
                ? Container(
                    height: 40,
                    alignment: AlignmentDirectional.centerStart,
                    child: Image.network(logo, height: 40, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset('assets/icon/app_icon.png', width: 36, height: 36)),
                  )
                : Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/icon/app_icon.png', width: 34, height: 34)),
                    const SizedBox(width: 10),
                    const Text.rich(TextSpan(children: [
                      TextSpan(text: 'Valet', style: TextStyle(color: AppColors.inkText)),
                      TextSpan(text: 'Fusion', style: TextStyle(color: AppColors.brassOnDark)),
                    ]), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ]),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brassOnDark,
                child: Text(initials.isEmpty ? 'V' : initials, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.inkText, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.inkTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 15, color: AppColors.brassOnDark),
              const SizedBox(width: 6),
              Expanded(child: Text(location, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkTextBody, fontSize: 13))),
            ]),
          ],
          const _PlanLine(),
        ],
      ),
    );
  }
}

/// "Free plan" / "Premium" / "Premium until 14 Nov 2026" under the venue in the drawer header.
class _PlanLine extends StatelessWidget {
  const _PlanLine();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlanInfo?>(
      valueListenable: PlanController.instance.plan,
      builder: (context, plan, _) {
        if (plan == null) return const SizedBox.shrink();
        final premium = !plan.isFree || plan.trialActive;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: premium ? null : () => showPremiumSheet(context, featureLabel: tr(context, 'Premium features')),
            child: Row(children: [
              Icon(premium ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: AppColors.brassOnDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(planHeaderLabel(context, plan),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: premium ? AppColors.brassOnDark : AppColors.inkTextBody, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// [PlanInfo.headerLabel] in the app's language (the package's own name stays as it is).
String planHeaderLabel(BuildContext context, PlanInfo plan) {
  if (plan.trialActive && plan.trialEndsAt != null) {
    return tr(context, 'Premium until {date}', {'date': DateFormat('d MMM yyyy').format(plan.trialEndsAt!)});
  }
  switch (plan.tier) {
    case 'FREE':
      return tr(context, 'Free plan');
    case 'PREMIUM':
      return tr(context, 'Premium');
    default:
      return plan.planName.isEmpty ? tr(context, 'Customized') : plan.planName;
  }
}
