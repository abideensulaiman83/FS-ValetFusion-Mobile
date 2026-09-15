// lib/pages/landing_page.dart
//
// The app's front door. Deliberately not a stack of identical cards - Admin is a different kind
// of thing from Driver/Customer (a management portal, not a "role you perform"), so it gets its
// own visual treatment: Driver and Customer sit as a bento-style pair up top (equal weight, the
// two everyday roles), Admin is a distinct dark "portal" strip below it.
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'customer_auth_page.dart';
import 'feedback_page.dart';
import 'privacy_policy_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The gradient Container below sizes to its scrollable content, not the screen - on a
      // tall device with short content that leaves the Scaffold's own (white) background
      // showing underneath. Setting it here too means there's never a white gap regardless of
      // content height.
      backgroundColor: const Color(0xFF0B1220),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1220), Color(0xFF141F38)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF059669)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_parking_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'VALET FUSION',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Who\'s using the app right now?',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13.5),
                ),
                const SizedBox(height: 28),

                // Driver + Customer - the everyday roles, equal weight, side by side.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _RoleTile(
                        title: 'Valet Team',
                        subtitle: 'Drivers, key control & lobby desk',
                        icon: Icons.directions_car_filled_rounded,
                        color: const Color(0xFF059669),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RoleTile(
                        title: 'Customer',
                        subtitle: 'Track & request my car',
                        icon: Icons.person_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerAuthPage())),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Admin - a distinct "portal" strip, not another role tile: darker, wider, more
                // formal, signaling "management console" rather than "a job you do".
                Material(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C3AED), size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Admin Console', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                SizedBox(height: 3),
                                Text(
                                  'Insights, operations, reports & full management',
                                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackPage())),
                        icon: Icon(Icons.feedback_outlined, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                        label: Text('Report an issue', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                        icon: Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                        label: Text('Privacy & Policy', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.06)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
