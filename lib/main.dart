
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_strings.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/landing_page.dart';
import 'pages/admin_complaints_page.dart';
import 'pages/driver_activity_page.dart';
import 'pages/admin_home_page.dart';
import 'pages/privacy_policy_page.dart';
import 'pages/splash_page.dart';
import 'pages/customer_home_page.dart';
import 'pages/supervisor_home_page.dart';
import 'pages/parking_setup_page.dart';
import 'pages/notifications_inbox_page.dart';
import 'components/premium.dart';
import 'services/app_update_service.dart';
import 'services/notification_service.dart';
import 'services/plan_service.dart';
import 'services/offline_queue.dart';
import 'theme/app_theme.dart';

// import 'pages/vehicle_make_page.dart';
// import 'pages/vehicle_colours_page.dart';
// import 'pages/parking_list_page.dart';
// import 'pages/parking_charges_page.dart';
// import 'pages/shops_page.dart';
// import 'pages/switch_location_page.dart';
// import 'pages/company_details_page.dart';
// import 'pages/ticket_details_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local notifications always; Firebase push only once google-services.json is configured.
  await NotificationService.instance.init();
  await LocaleController.load();

  // Anything a driver saved without signal (basement parking) is sent once the network is back.
  OfflineQueue.instance.start();

  // Crash reporting (Firebase Crashlytics) - only when Firebase came up, and only collecting from
  // release builds so developers' debug crashes don't mix with real ones from the field.
  if (Firebase.apps.isNotEmpty) {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {}
  }

  // FIX: Set preferred orientations and disable text selection toolbar
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
    SystemUiOverlay.top,
    SystemUiOverlay.bottom,
  ]);

  // Any call refused with PLAN_REQUIRED shows the "Part of Premium" sheet, wherever it came from.
  PlanController.onBlocked = presentPlanRequired;
  WidgetsBinding.instance.addObserver(_ResumeChecks());

  runApp(const MyApp());
}

/// When the app comes back to the front: refresh the plan (a trial may have ended) and re-check
/// the app version (a long-running session is blocked too once the minimum is raised).
class _ResumeChecks with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (PlanController.instance.plan.value != null) PlanController.instance.load();
    AppUpdateService.recheck();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // English by default; Arabic (right-to-left) once someone picks it with the language switch
    // (landing, guest screens and the staff drawer), remembered on the phone.
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.locale,
      builder: (context, locale, _) => ValueListenableBuilder<Color?>(
        valueListenable: BrandController.accent,
        builder: (context, accent, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      title: 'ValetFusion',
      // Control-room theme (plan §2.8 / C5); the venue's accent colour replaces brass after
      // login (plan B2). Follows the phone's light/dark setting: screens read surface, text and
      // status colours through context.vf / the ColorScheme. Screens that are always dark
      // (splash, landing, login) paint the ink tokens or wrap themselves in AppTheme.ops.
      theme: AppTheme.light(accent: accent),
      darkTheme: AppTheme.dark(accent: accent),
      themeMode: ThemeMode.system,
      locale: locale ?? const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/master/complaints': (context) => const AdminComplaintsPage(),
        '/driver/activity': (context) => const DriverActivityPage(),
        '/admin/home': (context) => const AdminHomePage(),
        '/customer/home': (context) => const CustomerHomePage(),
        '/supervisor/home': (context) => const SupervisorHomePage(),
        '/security/parking': (context) => const ParkingSetupPage(isHome: true),
        '/privacy-policy': (context) => const PrivacyPolicyPage(),
        '/notifications': (context) => const NotificationsInboxPage(),

        // Users and companies are managed in the admin portal (plan §7.5); no app screens for them.
        // '/master/vehicle-make': (context) => const VehicleMakePage(),
        // '/master/vehicle-colours': (context) => const VehicleColoursPage(),
        // '/master/parking-list': (context) => const ParkingListPage(),
        // '/master/parking-charges': (context) => const ParkingChargesPage(),
        // '/master/shops': (context) => const ShopsPage(),
        // '/master/switch-location': (context) => const SwitchLocationPage(),
        // '/master/company-details': (context) => const CompanyDetailsPage(),
        // '/master/ticket-details': (context) => const TicketDetailsPage(),
      },
      ),
      ),
    );
  }
}