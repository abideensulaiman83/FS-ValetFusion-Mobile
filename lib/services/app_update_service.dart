// lib/services/app_update_service.dart
//
// Start-up version check against /api/public/app-config. Below the server's minimum version the
// app is blocked with "Update required" (after a breaking API change old builds would just fail);
// below the latest it offers the update once per version (dialog at start-up) and keeps a soft
// "Update available" banner on the staff screens (AppUpdateBanner) until dismissed. The check runs
// again when the app comes back to the front (at most every 30 min), so a long-running session is
// also blocked once the minimum is raised. Without a store link, Android falls back to the
// APK download (/downloads/ValetFusion-latest.apk). Any failure - offline, server down, slow
// network - lets the app carry on: a version check must never lock people out.
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/environment.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'authentication_service.dart';
import 'notification_service.dart';

enum UpdateStatus { upToDate, optional, required }

class UpdateInfo {
  final UpdateStatus status;
  final String latestVersionName;
  final int latestVersionCode;
  final String storeUrl;
  const UpdateInfo(this.status, this.latestVersionName, this.latestVersionCode, this.storeUrl);
}

class AppUpdateService {
  static const String _dismissedKey = 'vf_update_dismissed_code';

  /// Android builds are also handed out as an APK until the store listing is live.
  static const String apkDownloadUrl = '${Environment.baseUrl}/downloads/ValetFusion-latest.apk';

  /// Result of the last successful check - drives the "Update available" banner.
  static final ValueNotifier<UpdateInfo?> latest = ValueNotifier<UpdateInfo?>(null);

  /// The banner was closed for this run of the app.
  static final ValueNotifier<bool> bannerDismissed = ValueNotifier<bool>(false);

  static DateTime? _lastCheck;
  static bool _blocking = false;

  static Future<UpdateInfo> check() async {
    final info = await _check();
    // A failed check reads as "up to date" - never let it hide an update already found (the
    // installed build cannot change while the app runs).
    if (info.status != UpdateStatus.upToDate || latest.value == null) latest.value = info;
    _lastCheck = DateTime.now();
    return info;
  }

  /// On resume: re-check (throttled) and block the app if this build has fallen below the minimum.
  static Future<void> recheck() async {
    if (_blocking) return;
    if (_lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 30)) return;
    final info = await check();
    if (info.status != UpdateStatus.required) return;
    final nav = NotificationService.navigatorKey.currentState;
    if (nav == null) return;
    _blocking = true;
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => UpdateRequiredPage(update: info)), (_) => false);
  }

  static Future<UpdateInfo> _check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber) ?? 0;
      final res = await http
          .get(Uri.parse('${AuthenticationService.apiBaseUrl}/public/app-config'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return const UpdateInfo(UpdateStatus.upToDate, '', 0, '');
      final cfg = jsonDecode(res.body) as Map<String, dynamic>;
      final min = (cfg['minVersionCode'] as num?)?.toInt() ?? 0;
      final latest = (cfg['latestVersionCode'] as num?)?.toInt() ?? 0;
      var url = (Platform.isIOS ? cfg['iosStoreUrl'] : cfg['androidStoreUrl']) as String? ?? '';
      if (url.trim().isEmpty && Platform.isAndroid) url = apkDownloadUrl;
      final name = cfg['latestVersionName'] as String? ?? '';
      if (installed < min) return UpdateInfo(UpdateStatus.required, name, latest, url);
      if (installed < latest) return UpdateInfo(UpdateStatus.optional, name, latest, url);
    } catch (_) {}
    return const UpdateInfo(UpdateStatus.upToDate, '', 0, '');
  }

  static Future<void> openStore(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Offers an optional update once per version; returns when the user has chosen.
  static Future<void> maybeOfferOptional(BuildContext context, UpdateInfo update) async {
    if (update.status != UpdateStatus.optional || update.storeUrl.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_dismissedKey) == update.latestVersionCode) return;
    if (!context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, 'Update available')),
        content: Text(tr(dialogContext, 'Valet Fusion {version} is available, with fixes and improvements.',
            {'version': update.latestVersionName})),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(dialogContext, 'Later'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(dialogContext, 'Update'))),
        ],
      ),
    );
    await prefs.setInt(_dismissedKey, update.latestVersionCode);
    if (go == true) await openStore(update.storeUrl);
  }
}

/// Full-screen block for builds older than the server's minimum. No way past it except updating.
/// Deliberately dark (ink) in both themes, so it keeps the fixed ink colours.
class UpdateRequiredPage extends StatelessWidget {
  final UpdateInfo update;
  const UpdateRequiredPage({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.system_update, color: AppColors.brassOnDark, size: 64),
                const SizedBox(height: 20),
                Text(tr(context, 'Update required'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkText, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  update.latestVersionName.isEmpty
                      ? tr(context, 'This version of Valet Fusion is no longer supported. Please install the latest version to continue.')
                      : tr(context,
                          'This version of Valet Fusion is no longer supported. Please install the latest version ({version}) to continue.',
                          {'version': update.latestVersionName}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkTextSecondary, fontSize: 14.5, height: 1.4),
                ),
                const SizedBox(height: 28),
                if (update.storeUrl.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => AppUpdateService.openStore(update.storeUrl),
                    icon: const Icon(Icons.download),
                    label: Text(tr(context, update.storeUrl.endsWith('.apk') ? 'Download update' : 'Update now')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brassOnDark,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                else
                  Text(tr(context, 'Ask your manager for the latest ValetFusion app.'),
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkTextSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft "Update available" strip for the staff screens (AppLayout): shown while a newer build
/// than this one is published, until closed for this run of the app.
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppUpdateService.bannerDismissed,
      builder: (context, dismissed, _) => ValueListenableBuilder<UpdateInfo?>(
        valueListenable: AppUpdateService.latest,
        builder: (context, update, _) {
          if (dismissed || update == null || update.status != UpdateStatus.optional || update.storeUrl.isEmpty) {
            return const SizedBox.shrink();
          }
          final theme = Theme.of(context);
          final vf = context.vf;
          return Material(
            color: vf.infoSoft,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
              child: Row(children: [
                Icon(Icons.system_update_rounded, size: 20, color: vf.live),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    update.latestVersionName.isEmpty
                        ? tr(context, 'Update available')
                        : tr(context, 'Update available - {version}', {'version': update.latestVersionName}),
                    style: theme.textTheme.bodyMedium?.copyWith(color: vf.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => AppUpdateService.openStore(update.storeUrl),
                  style: TextButton.styleFrom(foregroundColor: vf.live),
                  child: Text(tr(context, update.storeUrl.endsWith('.apk') ? 'Download' : 'Update')),
                ),
                IconButton(
                  tooltip: tr(context, 'Later'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => AppUpdateService.bannerDismissed.value = true,
                  icon: Icon(Icons.close_rounded, size: 18, color: vf.textSecondary),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
