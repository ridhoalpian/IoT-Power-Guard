import 'package:flutter/material.dart';

import 'auth_service.dart';

enum _ForgotPasswordStep { identity, code, newPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  _ForgotPasswordStep _step = _ForgotPasswordStep.identity;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _verifiedEmail;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _authService.sendPasswordResetCode(
        email: _emailController.text,
        username: _usernameController.text,
      );
      if (!mounted) return;
      setState(() {
        _step = _ForgotPasswordStep.code;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final email = await _authService.verifyPasswordResetCode(
        _codeController.text,
      );
      if (!mounted) return;
      setState(() {
        _verifiedEmail = email;
        _step = _ForgotPasswordStep.newPassword;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _saveNewPassword() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _authService.confirmPasswordReset(
        code: _codeController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _step = _ForgotPasswordStep.done;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0A7A6F);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(title: const Text('Lupa Password')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_stepIcon, size: 52, color: accent),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildStepContent(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              decoration: _inputDecoration(
                hintText: 'Email',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              decoration: _inputDecoration(
                hintText: 'Username',
                icon: Icons.person_outline,
                errorText: _error,
              ),
              onSubmitted: (_) => _sendResetEmail(),
            ),
            const SizedBox(height: 16),
            _primaryButton(
              label: _isSubmitting ? 'Memeriksa...' : 'Kirim Kode',
              onPressed: _isSubmitting ? null : _sendResetEmail,
            ),
          ],
        );
      case _ForgotPasswordStep.code:
        return Column(
          children: [
            TextField(
              controller: _codeController,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              decoration: _inputDecoration(
                hintText: 'Kode reset dari email',
                icon: Icons.key_outlined,
                errorText: _error,
              ),
              onSubmitted: (_) => _verifyCode(),
            ),
            const SizedBox(height: 10),
            const Text(
              'Buka email reset dari Firebase, salin nilai oobCode dari link, lalu tempel di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            _primaryButton(
              label: _isSubmitting ? 'Memverifikasi...' : 'Verifikasi Kode',
              onPressed: _isSubmitting ? null : _verifyCode,
            ),
          ],
        );
      case _ForgotPasswordStep.newPassword:
        return Column(
          children: [
            if (_verifiedEmail != null) ...[
              Text(
                _verifiedEmail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A7A6F),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              decoration: _inputDecoration(
                hintText: 'Password baru',
                icon: Icons.lock_outline,
                errorText: _error,
                suffixIcon: IconButton(
                  onPressed:
                      _isSubmitting
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
              ),
              onSubmitted: (_) => _saveNewPassword(),
            ),
            const SizedBox(height: 16),
            _primaryButton(
              label: _isSubmitting ? 'Menyimpan...' : 'Simpan Password Baru',
              onPressed: _isSubmitting ? null : _saveNewPassword,
            ),
          ],
        );
      case _ForgotPasswordStep.done:
        return Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 52,
              color: Color(0xFF0A7A6F),
            ),
            const SizedBox(height: 16),
            _primaryButton(
              label: 'Kembali ke Login',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
    }
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A7A6F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  IconData get _stepIcon {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return Icons.manage_accounts_outlined;
      case _ForgotPasswordStep.code:
        return Icons.mark_email_read_outlined;
      case _ForgotPasswordStep.newPassword:
        return Icons.lock_reset_outlined;
      case _ForgotPasswordStep.done:
        return Icons.check_circle_outline;
    }
  }

  String get _title {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return 'Verifikasi Akun';
      case _ForgotPasswordStep.code:
        return 'Masukkan Kode Reset';
      case _ForgotPasswordStep.newPassword:
        return 'Password Baru';
      case _ForgotPasswordStep.done:
        return 'Password Berhasil Diubah';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return 'Masukkan email dan username yang terdaftar.';
      case _ForgotPasswordStep.code:
        return 'Kode dikirim lewat email reset password Firebase.';
      case _ForgotPasswordStep.newPassword:
        return 'Masukkan password baru untuk akun ini.';
      case _ForgotPasswordStep.done:
        return 'Silakan login ulang dengan password baru.';
    }
  }
}
