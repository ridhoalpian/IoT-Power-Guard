import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/home_screen.dart';
import 'biometric_auth_service.dart';

class PinGateScreen extends StatefulWidget {
  const PinGateScreen({super.key});

  @override
  State<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends State<PinGateScreen> {
  static const String _pin = '1234';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();

  bool _isSubmitting = false;
  bool _isBiometricLoading = false;
  bool _isCheckingBiometricAvailability = true;
  bool _isBiometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBiometricAuth();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeBiometricAuth() async {
    final isAvailable = await _biometricAuthService.isBiometricAvailable();
    if (!mounted) return;

    setState(() {
      _isBiometricAvailable = isAvailable;
      _isCheckingBiometricAvailability = false;
    });

    if (isAvailable) {
      await _authenticateWithBiometric(isAutoTriggered: true);
      return;
    }

    _focusPinField();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isBiometricLoading) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final input = _controller.text.trim();
    if (input != _pin) {
      setState(() {
        _isSubmitting = false;
        _error = 'PIN salah. Coba lagi.';
      });
      _focusPinField();
      return;
    }

    _goToHomePage();
  }

  Future<void> _authenticateWithBiometric({
    bool isAutoTriggered = false,
  }) async {
    if (_isSubmitting || _isBiometricLoading) {
      return;
    }

    setState(() {
      _isBiometricLoading = true;
      _error = null;
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
        _goToHomePage();
        return;
      case BiometricAuthStatus.unavailable:
        if (!isAutoTriggered) {
          _showSnackbar('Biometrik tidak tersedia di perangkat ini.');
        }
        _focusPinField();
        return;
      case BiometricAuthStatus.canceled:
        _focusPinField();
        return;
      case BiometricAuthStatus.error:
        _showSnackbar(
          result.message ?? 'Autentikasi biometrik gagal dijalankan.',
        );
        _focusPinField();
        return;
    }
  }

  void _goToHomePage() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _focusPinField() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_pinFocusNode);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF0A7A6F);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_outline, size: 56, color: accent),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Masukkan PIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masukkan 4 digit PIN untuk masuk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _controller,
                      focusNode: _pinFocusNode,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      enabled: !_isBiometricLoading,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '****',
                        errorText: _error,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_isSubmitting || _isBiometricLoading)
                                ? null
                                : _submit,
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
                        onPressed:
                            (_isSubmitting ||
                                    _isBiometricLoading ||
                                    _isCheckingBiometricAvailability)
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
          ),
        ],
      ),
    );
  }
}
