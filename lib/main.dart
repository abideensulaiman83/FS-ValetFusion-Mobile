
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/landing_page.dart';
import 'pages/admin_complaints_page.dart';
import 'pages/driver_activity_page.dart';
import 'pages/admin_home_page.dart';
import 'pages/privacy_policy_page.dart';
import 'pages/splash_page.dart';
import 'pages/customer_home_page.dart';
import 'pages/parking_setup_page.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

// Import all pages directly from pages folder
import 'pages/create_company_page.dart';
import 'pages/create_user_page.dart';
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

  // FIX: Set preferred orientations and disable text selection toolbar
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
    SystemUiOverlay.top,
    SystemUiOverlay.bottom,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      title: 'Valet Fusion',
      theme: AppTheme.light,
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
        '/security/parking': (context) => const ParkingSetupPage(isHome: true),
        '/privacy-policy': (context) => const PrivacyPolicyPage(),

        // All pages directly in routes
        '/master/create-company': (context) => const CreateCompanyPage(),
        '/master/create-user': (context) => const CreateUserPage(),
        // '/master/vehicle-make': (context) => const VehicleMakePage(),
        // '/master/vehicle-colours': (context) => const VehicleColoursPage(),
        // '/master/parking-list': (context) => const ParkingListPage(),
        // '/master/parking-charges': (context) => const ParkingChargesPage(),
        // '/master/shops': (context) => const ShopsPage(),
        // '/master/switch-location': (context) => const SwitchLocationPage(),
        // '/master/company-details': (context) => const CompanyDetailsPage(),
        // '/master/ticket-details': (context) => const TicketDetailsPage(),
      },
    );
  }
}