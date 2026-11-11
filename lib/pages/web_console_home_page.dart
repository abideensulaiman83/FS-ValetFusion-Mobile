// lib/pages/web_console_home_page.dart
//
// Home for roles whose work lives in the web console (Operations head, Report viewer, Partner
// admin; an outlet login has its own screen, shop_home_page.dart). They used to fall through to the Valet Desk, whose calls the server
// refuses for them. Here they keep the bell (complaint and other alerts reach them live) and get
// one tap to the console.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/confirm_dialog.dart';
import '../components/notification_bell.dart';
import '../components/premium.dart' show kWebConsoleUrl;
import '../l10n/app_strings.dart';
import '../services/authentication_service.dart';
import '../theme/app_theme.dart';

class WebConsoleHomePage extends StatelessWidget {
  const WebConsoleHomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed) return;
    await AuthenticationService().logoutApi();
    if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _logout(context);
      },
      child: Scaffold(
        backgroundColor: context.vf.page,
        appBar: AppBar(
          title: Text(tr(context, 'ValetFusion')),
          actions: [
            const NotificationBell(),
            IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout), tooltip: tr(context, 'Logout')),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.desktop_windows_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(tr(context, 'Your reports and dashboards are in the web console'),
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(tr(context, 'Alerts still reach you here - tap the bell to see them.'),
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse(kWebConsoleUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(tr(context, 'Open web console')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
