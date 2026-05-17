import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../../services/device_offline_notification_service.dart';
import '../../services/push_notification_service.dart';
import 'auth_service.dart';
import 'biometric_auth_service.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import 'widgets/auth_message_dialog.dart';

class PinGateScreen extends StatefulWidget {
  const PinGateScreen({super.key});

  @override
  State<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends State<PinGateScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  final AuthService _authService = AuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();

  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  bool _isBiometricLoading = false;
  bool _isCheckingBiometricAvailability = true;
  bool _isBiometricAvailable = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBiometricAuth();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeBiometricAuth() async {
    final hasSession = _authService.hasAuthenticatedSession;
    final isAvailable =
        hasSession && await _biometricAuthService.isBiometricAvailable();
    if (!mounted) return;

    setState(() {
      _isBiometricAvailable = isAvailable;
      _isCheckingBiometricAvailability = false;
    });

    if (isAvailable) {
      await _authenticateWithBiometric(isAutoTriggered: true);
      return;
    }

    _focusUsernameField();
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authService.signInWithUsernameAndPassword(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await _goToHomePage();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      await _showLoginFailedDialog(error.message);
      _focusUsernameField();
    } catch (error) {
      if (!mounted) return;
      const message = 'Email/username atau password tidak valid.';
      debugPrint('Login failed: $error');
      await _showLoginFailedDialog(message);
      _focusUsernameField();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitGoogle() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isGoogleSubmitting = true;
    });

    try {
      await _authService.signInWithGoogle();
      await _goToHomePage();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _showSnackbar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSubmitting = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBiometric({
    bool isAutoTriggered = false,
  }) async {
    if (_isBusy) {
      return;
    }

    if (!_authService.hasAuthenticatedSession) {
      if (!isAutoTriggered) {
        _showSnackbar(
          'Login dengan username/password atau Google terlebih dahulu.',
        );
      }
      _focusUsernameField();
      return;
    }

    setState(() {
      _isBiometricLoading = true;
    });

    final result = await _biometricAuthService.authenticate();
    if (!mounted) return;

    setState(() {
      _isBiometricLoading = false;
      if (result.status == BiometricAuthStatus.unavailable) {
        _isBiometricAvailable = false;
      }
    });

    switch (result.status) {
      case BiometricAuthStatus.success:
        await _goToHomePage();
        return;
      case BiometricAuthStatus.unavailable:
        if (!isAutoTriggered) {
          _showSnackbar('Biometrik tidak tersedia di perangkat ini.');
        }
        _focusUsernameField();
        return;
      case BiometricAuthStatus.canceled:
        _focusUsernameField();
        return;
      case BiometricAuthStatus.error:
        _showSnackbar(
          result.message ?? 'Autentikasi biometrik gagal dijalankan.',
        );
        _focusUsernameField();
        return;
    }
  }

  Future<void> _goToHomePage() async {
    if (!mounted) return;
    await DeviceOfflineNotificationService.instance.initialize();
    await PushNotificationService.instance.initialize();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _focusUsernameField() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_usernameFocusNode);
  }

  bool get _isBusy =>
      _isSubmitting || _isGoogleSubmitting || _isBiometricLoading;

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLoginFailedDialog(String message) async {
    if (!mounted) return;
    await showAuthMessageDialog(
      context: context,
      title: 'Login gagal',
      message: message,
      icon: Icons.lock_person_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF0A7A6F);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 56,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Masuk ke HETrack',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gunakan username, password, atau akun Google.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        focusNode: _usernameFocusNode,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        enabled: !_isBusy,
                        decoration: InputDecoration(
                          hintText: 'Username atau email',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !_isBusy,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const CreateAccountScreen(),
                                        ),
                                      );
                                    },
                            child: const Text('Buat akun'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                            child: const Text('Lupa password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(_isSubmitting ? 'Memeriksa...' : 'Masuk'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isBusy ? null : _submitGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon:
                              _isGoogleSubmitting
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.account_circle_outlined),
                          label: const Text('Masuk dengan Google'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              (_isBusy || _isCheckingBiometricAvailability)
                                  ? null
                                  : () => _authenticateWithBiometric(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(
                              color:
                                  _isBiometricAvailable
                                      ? accent
                                      : const Color(0xFFCBD5E1),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon:
                              _isCheckingBiometricAvailability
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.fingerprint_outlined),
                          label: const Text('Gunakan Sidik Jari'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
