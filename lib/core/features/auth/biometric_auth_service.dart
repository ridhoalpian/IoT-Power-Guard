import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAuthStatus { success, unavailable, canceled, error }

class BiometricAuthResult {
  const BiometricAuthResult({required this.status, this.message});

  final BiometricAuthStatus status;
  final String? message;

  bool get isSuccess => status == BiometricAuthStatus.success;
}

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await _localAuthentication.isDeviceSupported();
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      if (!isSupported || !canCheckBiometrics) {
        return false;
      }

      final availableBiometrics =
          await _localAuthentication.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricAuthResult> authenticate() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return const BiometricAuthResult(
          status: BiometricAuthStatus.unavailable,
        );
      }

      final didAuthenticate = await _localAuthentication.authenticate(
        localizedReason: 'Verifikasi biometrik untuk masuk ke aplikasi.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        return const BiometricAuthResult(status: BiometricAuthStatus.success);
      }

      return const BiometricAuthResult(status: BiometricAuthStatus.canceled);
    } on PlatformException catch (error) {
      return BiometricAuthResult(
        status: BiometricAuthStatus.error,
        message: error.message ?? 'Autentikasi biometrik gagal dijalankan.',
      );
    } catch (_) {
      return const BiometricAuthResult(
        status: BiometricAuthStatus.error,
        message: 'Terjadi kesalahan saat memproses autentikasi biometrik.',
      );
    }
  }
}
