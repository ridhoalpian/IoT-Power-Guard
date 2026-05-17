import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'widgets/auth_message_dialog.dart';

enum _ForgotPasswordStep { identity, emailSent }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final AuthService _authService = AuthService();

  _ForgotPasswordStep _step = _ForgotPasswordStep.identity;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authService.sendPasswordResetCode(
        email: _emailController.text,
        username: _usernameController.text,
      );
      if (!mounted) return;
      setState(() {
        _step = _ForgotPasswordStep.emailSent;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      await _showResetPasswordFailedDialog(error.message);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Reset password failed: $error');
      await _showResetPasswordFailedDialog(
        'Link reset gagal dikirim. Periksa kembali data Anda lalu coba lagi.',
      );
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
              ),
              onSubmitted: (_) => _sendResetEmail(),
            ),
            const SizedBox(height: 16),
            _primaryButton(
              label: _isSubmitting ? 'Memeriksa...' : 'Kirim Link Reset',
              onPressed: _isSubmitting ? null : _sendResetEmail,
            ),
          ],
        );
      case _ForgotPasswordStep.emailSent:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Link reset password sudah dikirim. Buka email dari Firebase, lalu ikuti tautan reset password. Jika tidak muncul di Inbox, periksa folder Spam atau Promotions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
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

  Future<void> _showResetPasswordFailedDialog(String message) async {
    if (!mounted) return;
    await showAuthMessageDialog(
      context: context,
      title: 'Reset password gagal',
      message: message,
      icon: Icons.mark_email_unread_outlined,
    );
  }

  IconData get _stepIcon {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return Icons.manage_accounts_outlined;
      case _ForgotPasswordStep.emailSent:
        return Icons.mark_email_read_outlined;
    }
  }

  String get _title {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return 'Verifikasi Akun';
      case _ForgotPasswordStep.emailSent:
        return 'Cek Email Anda';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _ForgotPasswordStep.identity:
        return 'Masukkan email dan username yang terdaftar.';
      case _ForgotPasswordStep.emailSent:
        return 'Gunakan link reset password yang dikirim oleh Firebase.';
    }
  }
}
