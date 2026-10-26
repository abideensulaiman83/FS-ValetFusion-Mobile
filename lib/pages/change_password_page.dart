// First-login password change (plan B1). Login returned passwordChangeRequired=true with a
// 10-minute token that only works on /auth/change-password. The page collects the new password
// and hands the full login response back to the caller, which finishes the sign-in as usual.
import 'package:flutter/material.dart';
import '../services/authentication_service.dart';

class ChangePasswordPage extends StatefulWidget {
  final String restrictedToken;
  final String temporaryPassword;

  const ChangePasswordPage({super.key, required this.restrictedToken, required this.temporaryPassword});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthenticationService();
  bool _show = false;
  bool _loading = false;
  String _error = '';

  static final _rules = <String, bool Function(String)>{
    'At least 10 characters': (p) => p.length >= 10,
    'An upper-case letter': (p) => RegExp(r'[A-Z]').hasMatch(p),
    'A lower-case letter': (p) => RegExp(r'[a-z]').hasMatch(p),
    'A number': (p) => RegExp(r'\d').hasMatch(p),
  };

  bool get _rulesOk => _rules.values.every((t) => t(_next.text));
  bool get _canSubmit => _rulesOk && _next.text == _confirm.text && !_loading;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final response = await _auth.changePassword(
        token: widget.restrictedToken,
        currentPassword: widget.temporaryPassword,
        newPassword: _next.text,
      );
      if (mounted) Navigator.of(context).pop(response);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The password you signed in with was set for you. Pick one only you know - you have 10 minutes before you need to sign in again.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (_error.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _next,
                obscureText: !_show,
                autofocus: true,
                enabled: !_loading,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._rules.entries.map((r) {
                final ok = r.value(_next.text);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Icon(Icons.check, size: 18, color: ok ? Colors.green : theme.disabledColor),
                    const SizedBox(width: 8),
                    Text(r.key, style: TextStyle(color: ok ? Colors.green.shade800 : theme.textTheme.bodySmall?.color)),
                  ]),
                );
              }),
              const SizedBox(height: 16),
              TextField(
                controller: _confirm,
                obscureText: !_show,
                enabled: !_loading,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Repeat new password',
                  border: const OutlineInputBorder(),
                  errorText: _confirm.text.isNotEmpty && _confirm.text != _next.text ? 'Passwords do not match' : null,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Save and continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
