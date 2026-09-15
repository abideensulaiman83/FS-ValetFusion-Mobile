// lib/components/protected_route.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProtectedRoute extends StatefulWidget {
  final Widget child;
  final List<String>? allowedRoles;
  final String redirectTo;

  const ProtectedRoute({
    Key? key,
    required this.child,
    this.allowedRoles,
    this.redirectTo = '/dashboard',
  }) : super(key: key);

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    debugPrint('🔒 ProtectedRoute Check started');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vf_token');
    final userStr = prefs.getString('vf_user');

    debugPrint('🔒 Auth Check: token=${token?.substring(0, 20) ?? 'null'}...');
    debugPrint('🔒 Auth Check: user=${userStr != null ? 'exists' : 'missing'}');

    // First check: Is user authenticated?
    if (token == null || userStr == null) {
      debugPrint('❌ Not authenticated - Redirecting to /login');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });

      if (mounted) {
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }
      return;
    }

    setState(() {
      _isAuthenticated = true;
    });

    // Second check: Does user have required role?
    if (widget.allowedRoles != null && widget.allowedRoles!.isNotEmpty) {
      final user = jsonDecode(userStr);
      final userRoles = List<String>.from(user['roles'] ?? []);

      debugPrint('🔐 Role Check:');
      debugPrint('   User roles: ${userRoles.join(', ')}');
      debugPrint('   Required roles: ${widget.allowedRoles!.join(', ')}');

      // Check if user has at least one of the allowed roles
      final hasAccess = userRoles.any((role) => widget.allowedRoles!.contains(role));

      if (!hasAccess) {
        debugPrint('❌ Access Denied - User does not have required role');
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });

        if (mounted) {
          Future.microtask(() {
            Navigator.of(context).pushReplacementNamed(widget.redirectTo);
          });
        }
        return;
      }

      debugPrint('✅ Access Granted - User has required role');
      setState(() {
        _hasAccess = true;
        _isLoading = false;
      });
    } else {
      debugPrint('✅ Authenticated - Rendering protected content (no specific role required)');
      setState(() {
        _hasAccess = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated || !_hasAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.child;
  }
}

// Helper functions for auth service
class AuthService {
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vf_token');
    final user = prefs.getString('vf_user');
    return token != null && user != null;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('vf_user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<List<String>> getUserRoles() async {
    final user = await getCurrentUser();
    if (user != null && user['roles'] != null) {
      return List<String>.from(user['roles']);
    }
    return [];
  }
}