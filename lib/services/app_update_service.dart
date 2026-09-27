// lib/services/app_update_service.dart
//
// Start-up version check against /api/public/app-config. Below the server's minimum version the
// app is blocked with "Update required" (after a breaking API change old builds would just fail);
// below the latest it offers the update once per version. Any failure - offline, server down,
// slow network - lets the app carry on: a version check must never lock people out.
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'authentication_service.dart';

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

  static Future<UpdateInfo> check() async {
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
      final url = (Platform.isIOS ? cfg['iosStoreUrl'] : cfg['androidStoreUrl']) as String? ?? '';
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
        title: const Text('Update available'),
        content: Text('Valet Fusion ${update.latestVersionName} is available, with fixes and improvements.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Update')),
        ],
      ),
    );
    await prefs.setInt(_dismissedKey, update.latestVersionCode);
    if (go == true) await openStore(update.storeUrl);
  }
}

/// Full-screen block for builds older than the server's minimum. No way past it except updating.
class UpdateRequiredPage extends StatelessWidget {
  final UpdateInfo update;
  const UpdateRequiredPage({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 64),
                const SizedBox(height: 20),
                const Text('Update required',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  'This version of Valet Fusion is no longer supported. Please install the latest version'
                  '${update.latestVersionName.isEmpty ? '' : ' (${update.latestVersionName})'} to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.4),
                ),
                const SizedBox(height: 28),
                if (update.storeUrl.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => AppUpdateService.openStore(update.storeUrl),
                    icon: const Icon(Icons.download),
                    label: const Text('Update now'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
