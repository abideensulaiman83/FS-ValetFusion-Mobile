




import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import '../services/authentication_service.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _keepLoggedIn = false;
  bool _loading = false;
  String _error = '';

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricAuthenticating = false;

  // Add this: Focus nodes to prevent keyboard issues
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  final AuthenticationService _authService = AuthenticationService();

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();

    // Add this: Prevent automatic keyboard dismissal
    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        // Try to regain focus if lost unexpectedly
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_usernameFocusNode.hasFocus && !_passwordFocusNode.hasFocus) {
            _usernameFocusNode.requestFocus();
          }
        });
      }
    });

    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_passwordFocusNode.hasFocus && !_usernameFocusNode.hasFocus) {
            _passwordFocusNode.requestFocus();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
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
    }
    // Only worth checking device biometric support/enrollment when there's actually something
    // for it to unlock - no remembered credentials means no auto-fill target either way.
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
    final ok = await _authService.authenticateWithBiometrics(
      reason: 'Sign in to Valet Fusion',
    );
    if (mounted) setState(() => _biometricAuthenticating = false);
    if (ok && mounted) {
      await _handleLogin();
    }
  }

  // Offered once, right after a manual sign-in with "Remember me" checked - biometric login is
  // just a faster way to submit those same remembered credentials, so there's nothing to offer
  // until they exist and the device can actually prompt for Face ID/fingerprint.
  Future<void> _maybeOfferBiometricEnrollment() async {
    if (!_keepLoggedIn) return;
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _error = '';
      _loading = true;
    });

    try {

      final response = await _authService.loginApi(
        username: _usernameController.text,
        password: _passwordController.text,
        locationCode: null,
      );


      if (response.user.locationId == 0) {
        setState(() {
          _error = 'No location assigned to your account. Please contact support.';
        });
        await _authService.clearStorage();
        return;
      }


      final userLocation = LocationDto(
        id: response.user.locationId,
        code: response.user.locationCode,
        name: response.user.locationName.isNotEmpty
            ? response.user.locationName
            : 'Default Location',
        tenantCode: response.user.tenantCode,
        defaultForUser: true,
      );


      await _authService.saveLoginData(
        token: response.accessToken,
        user: response.user,
        location: userLocation,
      );

      if (_keepLoggedIn) {
        await _authService.saveRememberedCredentials(_usernameController.text, _passwordController.text);
        await _maybeOfferBiometricEnrollment();
      } else {
        await _authService.clearRememberedCredentials();
      }

      if (mounted) {
        final route = AuthenticationService.homeRouteFor(response.user.roles);
        // Customers use their own sign-in; a CUSTOMER account here still gets the desk as before.
        Navigator.of(context).pushReplacementNamed(route == '/customer/home' ? '/dashboard' : route);
      }
    } catch (e, stackTrace) {


      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
      await _authService.clearStorage();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _dismissKeyboard() {
    if (_usernameFocusNode.hasFocus) {
      _usernameFocusNode.unfocus();
    }
    if (_passwordFocusNode.hasFocus) {
      _passwordFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true, // IMPORTANT: Keep this true
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          height: screenHeight,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/login-bg-image.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: GestureDetector(
                  onTap: _dismissKeyboard,
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: isKeyboardOpen ? 40 : 80,
                      bottom: isKeyboardOpen ? 20 : 40,
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 400,
                        minHeight: isKeyboardOpen ? screenHeight * 0.5 : screenHeight * 0.6,
                      ),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header - simplified
                          if (!isKeyboardOpen)
                            Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(35),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'VF',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'VALET FUSION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),

                          if (isKeyboardOpen)
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'VF',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'VALET FUSION',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),

                          // Error Message
                          if (_error.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red[300],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _usernameController,
                                  focusNode: _usernameFocusNode,
                                  enabled: !_loading,
                                  autofocus: false,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                    hintText: 'Enter username',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Username is required';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  enabled: !_loading,
                                  autofocus: false,
                                  obscureText: !_showPassword,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                    hintText: 'Enter password',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _keepLoggedIn,
                                          onChanged: (value) {
                                            setState(() {
                                              _keepLoggedIn = value ?? false;
                                            });
                                          },
                                          fillColor: MaterialStateProperty.all(Colors.white),
                                          checkColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                              ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                        : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'SIGN IN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (_biometricAvailable && _biometricEnabled) ...[
                                  const SizedBox(height: 14),
                                  TextButton.icon(
                                    onPressed: (_loading || _biometricAuthenticating) ? null : _attemptBiometricLogin,
                                    icon: _biometricAuthenticating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.fingerprint, color: Colors.white),
                                    label: Text(
                                      _biometricAuthenticating ? 'Authenticating...' : 'Sign in with Face ID / Fingerprint',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          if (!isKeyboardOpen) ...[
                            const SizedBox(height: 32),
                            Column(
                              children: [
                                Divider(
                                  color: Colors.white.withOpacity(0.2),
                                  height: 1,
                                ),

                                const SizedBox(height: 4),
                                Text(
                                  'Powered by FocalSoft IT Solutions',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}