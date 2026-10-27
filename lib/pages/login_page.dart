// lib/pages/login_page.dart
//
// Staff sign-in (plan §2.8 / C5): ink background, the ValetFusion mark, one card. Keeps the
// remembered-login and Face ID / fingerprint shortcut, and the first-login password change
// (plan B1). Guests use CustomerAuthPage.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/authentication_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_page.dart';
import 'change_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final AuthenticationService _authService = AuthenticationService();

  bool _showPassword = false;
  bool _keepLoggedIn = false;
  bool _loading = false;
  String _error = '';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedCredentials() async {
    final saved = await _authService.getRememberedCredentials();
    if (saved != null && mounted) {
      setState(() {
        _usernameController.text = saved['username'] ?? '';
        _passwordController.text = saved['password'] ?? '';
        _keepLoggedIn = true;
      });
      final available = await _authService.isBiometricAvailable();
      final enabled = await _authService.isBiometricEnabled();
      if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
      if (available && enabled) _attemptBiometricLogin();
    }
  }

  Future<void> _attemptBiometricLogin() async {
    if (_biometricAuthenticating || _loading) return;
    setState(() => _biometricAuthenticating = true);
    final ok = await _authService.authenticateWithBiometrics(reason: 'Sign in to ValetFusion');
    if (mounted) setState(() => _biometricAuthenticating = false);
    if (ok && mounted) await _handleLogin();
  }

  // Offered once, after a manual sign-in with "Remember me": biometrics only unlock those
  // remembered credentials, so there is nothing to offer before they exist.
  Future<void> _maybeOfferBiometricEnrollment() async {
    if (!_keepLoggedIn) return;
    if (await _authService.isBiometricEnabled()) return;
    if (!await _authService.isBiometricAvailable() || !mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use Face ID / fingerprint?'),
        content: const Text('Sign in faster next time with your face or fingerprint instead of typing your password.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Enable')),
        ],
      ),
    );
    if (enable == true && await _authService.authenticateWithBiometrics(reason: 'Confirm to enable Face ID / fingerprint sign-in')) {
      await _authService.setBiometricEnabled(true);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _error = ''; _loading = true; });
    try {
      var response = await _authService.loginApi(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        locationCode: null,
      );

      // Admin-set password: the user must choose their own before anything else (plan B1).
      if (response.passwordChangeRequired) {
        if (!mounted) return;
        final completed = await Navigator.of(context).push<LoginResponse>(
          MaterialPageRoute(builder: (_) => ChangePasswordPage(restrictedToken: response.accessToken, temporaryPassword: _passwordController.text)),
        );
        if (completed == null) return; // backed out - stay on the login screen
        response = completed;
        _passwordController.clear();
        _keepLoggedIn = false; // the temporary password must not be remembered
      }

      if (response.user.locationId == 0) {
        setState(() => _error = 'No location is assigned to your account. Please contact your administrator.');
        await _authService.clearStorage();
        return;
      }

      final userLocation = LocationDto(
        id: response.user.locationId,
        code: response.user.locationCode,
        name: response.user.locationName.isNotEmpty ? response.user.locationName : 'Default Location',
        tenantCode: response.user.tenantCode,
        defaultForUser: true,
      );
      await _authService.saveLoginData(token: response.accessToken, user: response.user, location: userLocation, refreshToken: response.refreshToken);

      if (_keepLoggedIn) {
        await _authService.saveRememberedCredentials(_usernameController.text.trim(), _passwordController.text);
        await _maybeOfferBiometricEnrollment();
      } else {
        await _authService.clearRememberedCredentials();
      }

      if (mounted) {
        final route = AuthenticationService.homeRouteFor(response.user.roles);
        Navigator.of(context).pushReplacementNamed(route == '/customer/home' ? '/dashboard' : route);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      await _authService.clearStorage();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // brand
                  Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon/app_icon.png', width: 44, height: 44)),
                      const SizedBox(width: 12),
                      const Text.rich(TextSpan(children: [
                        TextSpan(text: 'Valet', style: TextStyle(color: AppColors.inkText)),
                        TextSpan(text: 'Fusion', style: TextStyle(color: AppColors.brassOnDark)),
                      ]), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text('Staff sign in', style: TextStyle(color: AppColors.inkText, fontSize: 26, fontWeight: FontWeight.w700, height: 1.1)),
                  const SizedBox(height: 6),
                  const Text('Use the username and password your administrator gave you.',
                      style: TextStyle(color: AppColors.inkTextSecondary, fontSize: 13.5)),
                  const SizedBox(height: 22),

                  // card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.inkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inkLine),
                    ),
                    child: Theme(
                      data: AppTheme.ops,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerOnDark.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.dangerOnDark.withValues(alpha: 0.4)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline, color: AppColors.dangerOnDark, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_error, style: const TextStyle(color: AppColors.inkText, fontSize: 13))),
                                ]),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              enabled: !_loading,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                              decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              enabled: !_loading,
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Checkbox(
                                    value: _keepLoggedIn,
                                    onChanged: _loading ? null : (v) => setState(() => _keepLoggedIn = v ?? false),
                                    activeColor: AppColors.brassOnDark,
                                    checkColor: AppColors.ink,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Text('Remember me', style: TextStyle(color: AppColors.inkTextBody, fontSize: 13)),
                                ]),
                                TextButton(
                                  onPressed: _loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                                  child: const Text('Forgot password?', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _loading ? null : _handleLogin,
                                icon: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink))
                                    : const Icon(Icons.login_rounded, size: 20),
                                label: Text(_loading ? 'Signing in...' : 'Sign in', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            if (_biometricAvailable && _biometricEnabled) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: (_loading || _biometricAuthenticating) ? null : _attemptBiometricLogin,
                                icon: _biometricAuthenticating
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.fingerprint),
                                label: Text(_biometricAuthenticating ? 'Authenticating...' : 'Sign in with Face ID / fingerprint'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Center(
                    child: Text('Designed by FocalSoft IT Solution · Dubai',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkTextSecondary, fontSize: 11.5)),
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
