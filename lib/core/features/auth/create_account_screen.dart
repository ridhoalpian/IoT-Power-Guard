import 'package:flutter/material.dart';

import '../../services/device_offline_notification_service.dart';
import '../../services/push_notification_service.dart';
import 'auth_service.dart';
import 'pin_gate_screen.dart';
import 'widgets/auth_message_dialog.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authService.createAccount(
        email: _emailController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await DeviceOfflineNotificationService.instance.initialize();
      await PushNotificationService.instance.initialize();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PinGateScreen()),
        (_) => false,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      await _showCreateAccountFailedDialog(
        _createAccountFailureMessage(error.message),
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint('Create account failed: $error');
      await _showCreateAccountFailedDialog(
        'Akun gagal dibuat. Periksa kembali data Anda lalu coba lagi.',
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
      appBar: AppBar(title: const Text('Buat Akun')),
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
                      child: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 52,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Daftar Akun HETrack',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buat akun dengan email, username, dan password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 22),
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
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      decoration: _inputDecoration(
                        hintText: 'Username',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_isSubmitting,
                      decoration: _inputDecoration(
                        hintText: 'Password',
                        icon: Icons.lock_outline,
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
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          _isSubmitting ? 'Membuat akun...' : 'Buat Akun',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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

  Future<void> _showCreateAccountFailedDialog(String message) async {
    if (!mounted) return;
    await showAuthMessageDialog(
      context: context,
      title: 'Akun gagal dibuat',
      message: message,
      icon: Icons.person_off_outlined,
    );
  }

  String _createAccountFailureMessage(String message) {
    if (message == 'Email ini sudah terdaftar.' ||
        message == 'Username sudah dipakai.') {
      return 'Pendaftaran gagal. Gunakan data akun yang valid atau coba login jika sudah memiliki akun.';
    }

    return message;
  }
}
