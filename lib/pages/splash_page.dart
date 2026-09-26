// lib/pages/splash_page.dart
//
// A brief animated intro before the landing/dashboard - the logo mark scales/fades in, then the
// wordmark follows. The token was already being saved to SharedPreferences on login and only
// ever cleared on explicit logout, but nothing on startup ever checked for it - every cold start
// went straight to the landing page regardless, forcing a re-login every single time the app was
// closed and reopened. This now checks for a saved session and, if one exists, skips straight to
// the right home screen for that role - "stay logged in until you log out" actually working.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/authentication_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1500), _routeAfterSplash);
  }

  Future<void> _routeAfterSplash() async {
    if (!mounted) return;
    final route = await _resolveStartRoute();
    if (mounted) Navigator.of(context).pushReplacementNamed(route);
  }

  Future<String> _resolveStartRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthenticationService.tokenKey);
    final userStr = prefs.getString(AuthenticationService.userKey);
    if (token == null || userStr == null) return '/';
    if (_isJwtExpired(token)) {
      await prefs.remove(AuthenticationService.tokenKey);
      await prefs.remove(AuthenticationService.userKey);
      return '/';
    }

    try {
      final roles = List<String>.from(jsonDecode(userStr)['roles'] ?? []);
      // Push alerts go to whoever is signed in on this phone - refresh the token on every start.
      NotificationService.instance.registerDevice();
      // Driver/Key Controller/Lobby/Valet Staff share the desk; Security goes to Parking Setup.
      return AuthenticationService.homeRouteFor(roles);
    } catch (_) {
      return '/';
    }
  }

  // Decodes the JWT payload's "exp" claim without any extra package - if the saved token has
  // already expired, silently landing on a dashboard would just mean every API call 401s with
  // no explanation. Any decode failure is treated as "not expired" (fail open to the saved
  // session) rather than logging someone out over a parsing hiccup.
  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      String payload = parts[1];
      payload = base64Url.normalize(payload);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      final exp = decoded['exp'];
      if (exp is! int) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF059669)]),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.local_parking_rounded, color: Colors.white, size: 52),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _textSlide,
                  child: Opacity(
                    opacity: _textOpacity.value,
                    child: const Column(
                      children: [
                        Text(
                          'VALET FUSION',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Smarter valet, from arrival to delivery',
                          style: TextStyle(color: Colors.white54, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
