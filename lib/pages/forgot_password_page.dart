// lib/pages/forgot_password_page.dart
//
// Shared between Driver/staff (LoginPage) and Customer (CustomerAuthPage) - both log in with the
// same CentralUser/email account underneath, so one reset flow covers everyone. Code-based rather
// than a clickable link, since the app has no deep-link handling set up: the user gets a 6-digit
// code by email and enters it back in-app, same pattern as a phone OTP.
import 'package:flutter/material.dart';
import '../services/authentication_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authService = AuthenticationService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _codeRequested = false;
  bool _done = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email address');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.requestPasswordReset(_emailController.text.trim());
      if (mounted) setState(() => _codeRequested = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.resetPassword(
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _done ? _buildDone() : (_codeRequested ? _buildResetForm() : _buildRequestForm()),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_reset_rounded, size: 48, color: Colors.blue.shade600),
        const SizedBox(height: 12),
        const Text(
          "Enter the email on your account (Customer accounts: your mobile number also works) "
          "and we'll send a 6-digit code to reset your password.",
          style: TextStyle(fontSize: 13.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email or Mobile Number', prefixIcon: Icon(Icons.alternate_email)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _requestCode,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send Reset Code'),
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.green.shade600),
          const SizedBox(height: 12),
          Text(
            "If ${_emailController.text.trim()} is registered, a code has been sent. Enter it below with your new password.",
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: '6-Digit Code', prefixIcon: Icon(Icons.pin_outlined)),
            validator: (v) => (v == null || v.trim().length != 6) ? 'Enter the 6-digit code' : null,
          ),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters, incl. a lowercase letter and a number' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitReset,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Reset Password'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : () => setState(() => _codeRequested = false),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 56, color: Colors.green.shade600),
        const SizedBox(height: 16),
        const Text('Password reset', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('You can now sign in with your new password.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Sign In'),
          ),
        ),
      ],
    );
  }
}
