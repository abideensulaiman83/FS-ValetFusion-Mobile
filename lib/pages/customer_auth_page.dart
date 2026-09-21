// lib/pages/customer_auth_page.dart
//
// Guest self-registration/login. Registration needs the property to scope the Customer account
// to one tenant - shown as a searchable dropdown of active properties (name + code) rather than
// a free-text code field the guest had to already know exactly. Login afterwards is just
// mobile + password, same as any other role, reusing the normal /auth/login.
import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import 'customer_home_page.dart';
import 'forgot_password_page.dart';

class CustomerAuthPage extends StatefulWidget {
  const CustomerAuthPage({super.key});

  @override
  State<CustomerAuthPage> createState() => _CustomerAuthPageState();
}

class _CustomerAuthPageState extends State<CustomerAuthPage> {
  final _authService = AuthenticationService();
  final _formKey = GlobalKey<FormState>();

  bool _isRegister = true;
  bool _loading = false;
  bool _rememberMe = false;
  bool _showPassword = false;

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricAuthenticating = false;

  List<PublicCompanyOption> _companies = [];
  bool _loadingCompanies = true;
  PublicCompanyOption? _selectedCompany;

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final saved = await _authService.getRememberedCredentials();
    if (saved != null && mounted) {
      setState(() {
        _mobileController.text = saved['username'] ?? '';
        _passwordController.text = saved['password'] ?? '';
        _rememberMe = true;
        _isRegister = false;
      });
    }
    if (saved != null) {
      final available = await _authService.isBiometricAvailable();
      final enabled = await _authService.isBiometricEnabled();
      if (mounted) {
        setState(() {
          _biometricAvailable = available;
          _biometricEnabled = enabled;
        });
      }
      if (available && enabled) {
        _attemptBiometricLogin();
      }
    }
  }

  Future<void> _attemptBiometricLogin() async {
    if (_biometricAuthenticating || _loading) return;
    setState(() => _biometricAuthenticating = true);
    final ok = await _authService.authenticateWithBiometrics(reason: 'Sign in to Valet Fusion');
    if (mounted) setState(() => _biometricAuthenticating = false);
    if (ok && mounted) {
      await _submit();
    }
  }

  Future<void> _maybeOfferBiometricEnrollment() async {
    if (!_rememberMe) return;
    if (await _authService.isBiometricEnabled()) return;
    final available = await _authService.isBiometricAvailable();
    if (!available || !mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable Face ID / Fingerprint?'),
        content: const Text('Sign in faster next time using your face or fingerprint instead of typing your password.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Enable')),
        ],
      ),
    );
    if (enable == true) {
      final confirmed = await _authService.authenticateWithBiometrics(
        reason: 'Confirm to enable Face ID / Fingerprint sign-in',
      );
      if (confirmed) {
        await _authService.setBiometricEnabled(true);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    try {
      final companies = await _authService.fetchPublicCompanies();
      if (mounted) setState(() => _companies = companies);
    } catch (_) {
      // Non-fatal - registration form just shows an empty list + a retry hint.
    } finally {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRegister && _selectedCompany == null) {
      _showSnack('Please select your property');
      return;
    }
    setState(() => _loading = true);
    try {
      final response = _isRegister
          ? await _authService.registerCustomer(
              companyCode: _selectedCompany!.code,
              mobile: _mobileController.text.trim(),
              password: _passwordController.text,
              firstName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
              email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            )
          : await _authService.loginApi(
              username: _mobileController.text.trim(),
              password: _passwordController.text,
            );

      await _authService.saveLoginData(token: response.accessToken, user: response.user);

      if (!_isRegister) {
        if (_rememberMe) {
          await _authService.saveRememberedCredentials(_mobileController.text.trim(), _passwordController.text);
          await _maybeOfferBiometricEnrollment();
        } else {
          await _authService.clearRememberedCredentials();
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(title: Text(_isRegister ? 'Guest Sign Up' : 'Guest Sign In')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.local_parking_rounded, size: 40, color: Colors.blue.shade600),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister ? 'Create your guest account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  if (_isRegister) ...[
                    _buildPropertyPicker(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        helperText: 'Lets you reset your password later',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  if (!_isRegister)
                    CheckboxListTile(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      title: const Text('Remember me', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isRegister ? 'Sign Up' : 'Sign In'),
                    ),
                  ),
                  if (!_isRegister && _biometricAvailable && _biometricEnabled) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: (_loading || _biometricAuthenticating) ? null : _attemptBiometricLogin,
                      icon: _biometricAuthenticating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.fingerprint),
                      label: Text(_biometricAuthenticating ? 'Authenticating...' : 'Sign in with Face ID / Fingerprint'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? 'Already have an account? Sign in' : "New guest? Sign up"),
                  ),
                  if (!_isRegister)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                              ),
                      child: const Text('Forgot Password?'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyPicker() {
    if (_loadingCompanies) {
      return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_companies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Could not load properties.', style: TextStyle(fontSize: 12))),
            TextButton(onPressed: _loadCompanies, child: const Text('Retry')),
          ],
        ),
      );
    }
    return DropdownButtonFormField<PublicCompanyOption>(
      value: _selectedCompany,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Property *', border: OutlineInputBorder()),
      items: _companies
          .map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (${c.code})', overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => _selectedCompany = v),
      validator: (v) => v == null ? 'Please select your property' : null,
    );
  }
}
