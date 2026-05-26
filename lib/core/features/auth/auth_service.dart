import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseDatabase? firebaseDatabase,
    GoogleSignIn? googleSignIn,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _database =
           firebaseDatabase ??
           FirebaseDatabase.instanceFor(
             app: Firebase.app(),
             databaseURL: _databaseUrl,
           ),
       _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  static const String _databaseUrl =
      'https://home-electrical-tracking-54460-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const Duration _authTimeout = Duration(seconds: 20);
  static const Duration _databaseTimeout = Duration(seconds: 12);

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  bool get hasAuthenticatedSession => _auth.currentUser != null;

  Future<UserCredential> signInWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    final usernameOrEmail = username.trim();
    if (usernameOrEmail.isEmpty) {
      throw const AuthFailure('Username wajib diisi.');
    }
    if (password.isEmpty) {
      throw const AuthFailure('Password wajib diisi.');
    }

    final email = await _resolveEmail(usernameOrEmail);
    if (email == null || email.isEmpty) {
      throw const AuthFailure(
        'Username tidak ditemukan di database. Gunakan username yang terdaftar.',
      );
    }

    try {
      final credential = await _withAuthTimeout(
        _auth.signInWithEmailAndPassword(email: email, password: password),
      );
      await _saveUserProfile(
        credential.user,
        username: usernameOrEmail.contains('@') ? null : usernameOrEmail,
        provider: 'password',
      );
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseAuthMessage(error));
    }
  }

  Future<UserCredential> createAccount({
    required String email,
    required String username,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = _normalizeUsername(username);
    if (normalizedEmail.isEmpty) {
      throw const AuthFailure('Email wajib diisi.');
    }
    if (normalizedUsername.isEmpty) {
      throw const AuthFailure('Username wajib diisi.');
    }
    if (!_isValidUsername(normalizedUsername)) {
      throw const AuthFailure(
        'Username hanya boleh berisi huruf, angka, titik, garis bawah, atau strip.',
      );
    }
    if (password.length < 6) {
      throw const AuthFailure('Password minimal 6 karakter.');
    }

    final usernameSnapshot = await _withDatabaseTimeout(
      _database.ref('usernames/$normalizedUsername/email').get(),
    );
    if (usernameSnapshot.exists) {
      throw const AuthFailure('Username sudah dipakai.');
    }

    try {
      final credential = await _withAuthTimeout(
        _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        ),
      );
      await _withAuthTimeout(
        credential.user?.updateDisplayName(normalizedUsername) ??
            Future<void>.value(),
      );
      await _saveUserProfile(
        _auth.currentUser ?? credential.user,
        username: normalizedUsername,
        provider: 'password',
      );
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseAuthMessage(error));
    }
  }

  Future<void> sendPasswordResetCode({
    required String email,
    required String username,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = _normalizeUsername(username);
    if (normalizedEmail.isEmpty || normalizedUsername.isEmpty) {
      throw const AuthFailure('Email dan username wajib diisi.');
    }

    final isMatched = await isUsernameEmailMatched(
      email: normalizedEmail,
      username: normalizedUsername,
    );
    if (!isMatched) {
      throw const AuthFailure('Username dan email tidak cocok di database.');
    }

    try {
      await _withAuthTimeout(
        _auth.sendPasswordResetEmail(email: normalizedEmail),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseAuthMessage(error));
    }
  }

  Future<bool> isUsernameEmailMatched({
    required String email,
    required String username,
  }) async {
    final resolvedEmail = await _resolveEmail(_normalizeUsername(username));
    return resolvedEmail?.trim().toLowerCase() == email.trim().toLowerCase();
  }

  Future<String> verifyPasswordResetCode(String code) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      throw const AuthFailure('Kode reset wajib diisi.');
    }

    try {
      return await _withAuthTimeout(_auth.verifyPasswordResetCode(trimmedCode));
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseAuthMessage(error));
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw const AuthFailure('Password baru minimal 6 karakter.');
    }

    try {
      await _withAuthTimeout(
        _auth.confirmPasswordReset(
          code: code.trim(),
          newPassword: newPassword,
        ),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseAuthMessage(error));
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _withAuthTimeout(
          _auth.signInWithPopup(GoogleAuthProvider()),
        );
      } else {
        final googleUser = await _withAuthTimeout(_googleSignIn.signIn());
        if (googleUser == null) {
          throw const AuthFailure('Login Google dibatalkan.');
        }

        final googleAuth = await _withAuthTimeout(googleUser.authentication);
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _withAuthTimeout(
          _auth.signInWithCredential(oauthCredential),
        );
      }

      await _saveUserProfile(credential.user, provider: 'google');
      return credential;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseAuthMessage(error));
    }
  }

  Future<void> signOut() async {
    await _withAuthTimeout(_auth.signOut());
    if (!kIsWeb) {
      await _withAuthTimeout(_googleSignIn.signOut());
    }
  }

  Future<String?> _resolveEmail(String usernameOrEmail) async {
    if (usernameOrEmail.contains('@')) {
      return usernameOrEmail;
    }

    final username = _normalizeUsername(usernameOrEmail);
    final directPaths = <String>[
      'usernames/$username/email',
      'auth_users/$username/email',
      'accounts/$username/email',
      'users/$username/email',
    ];

    for (final path in directPaths) {
      final snapshot = await _withDatabaseTimeout(_database.ref(path).get());
      final value = snapshot.value?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final collectionPaths = <String>['app_users', 'users', 'accounts'];
    for (final path in collectionPaths) {
      final snapshot = await _withDatabaseTimeout(
        _database.ref(path).orderByChild('username').equalTo(username).get(),
      );
      final email = _firstEmailFromCollection(snapshot.value);
      if (email != null) {
        return email;
      }
    }

    return null;
  }

  String? _firstEmailFromCollection(Object? value) {
    if (value is! Map) {
      return null;
    }
    for (final entry in value.values) {
      if (entry is! Map) {
        continue;
      }
      final email = entry['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }
    return null;
  }

  Future<void> _saveUserProfile(
    User? user, {
    String? username,
    required String provider,
  }) async {
    if (user == null) {
      return;
    }

    final email = user.email?.trim();
    final normalizedUsername =
        (username == null || username.trim().isEmpty)
            ? email?.split('@').first.toLowerCase()
            : _normalizeUsername(username);

    final updates = <String, Object?>{
      'app_users/${user.uid}/uid': user.uid,
      'app_users/${user.uid}/email': email,
      'app_users/${user.uid}/name': user.displayName,
      'app_users/${user.uid}/photo_url': user.photoURL,
      'app_users/${user.uid}/provider': provider,
      'app_users/${user.uid}/last_login_at': ServerValue.timestamp,
    };

    if (normalizedUsername != null &&
        normalizedUsername.isNotEmpty &&
        _isValidUsername(normalizedUsername)) {
      updates['app_users/${user.uid}/username'] = normalizedUsername;
      if (email != null && email.isNotEmpty) {
        updates['usernames/$normalizedUsername/email'] = email;
        updates['usernames/$normalizedUsername/uid'] = user.uid;
      }
    }

    await _withDatabaseTimeout(_database.ref().update(updates));
  }

  Future<T> _withAuthTimeout<T>(Future<T> future) {
    return future.timeout(
      _authTimeout,
      onTimeout: () {
        throw const AuthFailure(
          'Login terlalu lama merespons. Periksa koneksi internet lalu coba lagi.',
        );
      },
    );
  }

  Future<T> _withDatabaseTimeout<T>(Future<T> future) {
    return future.timeout(
      _databaseTimeout,
      onTimeout: () {
        throw const AuthFailure(
          'Database terlalu lama merespons. Periksa koneksi internet lalu coba lagi.',
        );
      },
    );
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar.';
      case 'invalid-email':
        return 'Format email pada akun tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Username atau password salah.';
      case 'network-request-failed':
        return 'Koneksi bermasalah. Periksa internet lalu coba lagi.';
      case 'account-exists-with-different-credential':
        return 'Email ini sudah terhubung dengan metode login lain.';
      case 'expired-action-code':
        return 'Kode reset sudah kedaluwarsa. Kirim ulang email reset.';
      case 'invalid-action-code':
        return 'Kode reset tidak valid.';
      default:
        return 'Login gagal. Coba lagi beberapa saat.';
    }
  }

  String _normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  bool _isValidUsername(String value) {
    return RegExp(r'^[a-z0-9._-]+$').hasMatch(value);
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
