// lib/pages/admin_home_page.dart
//
// The Admin's actual landing screen after login - previously admins landed on the exact same
// bare ticket-scan desk as line staff, which buried everything an admin actually needs behind no
// navigation at all. This is a real console: live Insights (today's operational snapshot),
// Operations (the modules an admin acts on day to day), and Reports - not a flat "Master" list.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/confirm_dialog.dart';
import '../services/authentication_service.dart';
import '../services/valet_service.dart';
import 'dashboard_page.dart';
import 'admin_complaints_page.dart';
import 'create_user_page.dart';
import 'create_company_page.dart';
import 'driver_activity_page.dart';
import 'privacy_policy_page.dart';
import 'parking_occupancy_page.dart';
import 'parking_setup_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _valetService = ValetService();
  final _authService = AuthenticationService();
  DashboardDetails? _details;
  bool _loading = true;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(AuthenticationService.userKey);
    if (userStr == null) return;
    final roles = List<String>.from(jsonDecode(userStr)['roles'] ?? []);
    if (mounted) setState(() => _isSuperAdmin = roles.contains('SUPER_ADMIN'));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final details = await _valetService.fetchDashboardDetails();
      if (mounted) setState(() => _details = details);
    } catch (_) {
      // Non-fatal - insights just stay empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed) return;
    await _authService.logoutApi();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _logout();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text('Admin Console'),
          actions: [
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Logout'),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('Insights'),
                  const SizedBox(height: 10),
                  _buildInsights(),
                  const SizedBox(height: 24),
                  _sectionLabel('Operations'),
                  const SizedBox(height: 10),
                  _buildOperationsGrid(),
                  const SizedBox(height: 24),
                  _sectionLabel('Reports'),
                  const SizedBox(height: 10),
                  _moduleTile(
                    icon: Icons.bar_chart_rounded,
                    color: Colors.indigo,
                    title: 'Operational Report',
                    subtitle: 'Today\'s throughput, inventory & payment mix',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverActivityPage())),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('More'),
                  const SizedBox(height: 10),
                  _moduleTile(
                    icon: Icons.privacy_tip_outlined,
                    color: Colors.grey,
                    title: 'Privacy & Policy',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.grey));
  }

  Widget _buildInsights() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
    }
    final d = _details;
    final stats = [
      ('Received', d?.receivedCount ?? 0, Icons.local_parking, Colors.blue),
      ('Delivered', d?.deliveredCount ?? 0, Icons.check_circle_outline, Colors.green),
      ('In Inventory', d?.currentInventory ?? 0, Icons.inventory_2_outlined, Colors.orange),
      ('Complimentary', d?.complimentaryCount ?? 0, Icons.card_giftcard_outlined, Colors.purple),
      ('Paid', d?.paidCount ?? 0, Icons.attach_money, Colors.teal),
      ('Tickets Left', d?.ticketsRemaining ?? 0, Icons.confirmation_number_outlined, Colors.red),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: stats.map((s) => _statCard(s.$1, s.$2, s.$3, s.$4)).toList(),
    );
  }

  Widget _statCard(String label, int value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade600, size: 20),
          const Spacer(),
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color.shade800)),
          Text(label, style: TextStyle(fontSize: 10.5, color: color.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildOperationsGrid() {
    final modules = <Map<String, dynamic>>[
      {
        'icon': Icons.directions_car_filled_outlined,
        'color': Colors.indigo,
        'title': 'Valet Desk',
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage())),
      },
      {
        'icon': Icons.local_parking_outlined,
        'color': Colors.teal,
        'title': 'Parking Occupancy',
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParkingOccupancyPage())),
      },
      {
        'icon': Icons.grid_view_outlined,
        'color': Colors.green,
        'title': 'Parking Setup',
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParkingSetupPage())),
      },
      {
        'icon': Icons.forum_outlined,
        'color': Colors.red,
        'title': 'Complaints',
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminComplaintsPage())),
      },
      {
        'icon': Icons.person_add_alt_outlined,
        'color': Colors.blue,
        'title': 'Users',
        'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateUserPage())),
      },
      if (_isSuperAdmin)
        {
          'icon': Icons.business_outlined,
          'color': Colors.purple,
          'title': 'Companies',
          'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateCompanyPage())),
        },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: modules.map((m) => _quickTile(m['icon'], m['color'], m['title'], m['onTap'])).toList(),
    );
  }

  Widget _quickTile(IconData icon, MaterialColor color, String title, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color.shade600, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moduleTile({required IconData icon, required MaterialColor color, required String title, String? subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
