import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/electrical_data.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  static const String _databaseUrl =
      'https://home-electrical-tracking-54460-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _relayRootPath = 'relay';
  static const String _iotRootPath = 'iot_power_guard';
  static const String _userEmail = 'ridhoalpian8713@gmail.com';
  static const String _userPassword = 'ridho8733';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );
  late final DatabaseReference _root = _database.ref(_iotRootPath);
  late final DatabaseReference _relayRoot = _database.ref(_relayRootPath);

  Future<void> initialize() async {
    if (_auth.currentUser != null) {
      return;
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: _userEmail,
        password: _userPassword,
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase auth failed: ${error.code}');
    }
  }

  Stream<ElectricalData> get electricalDataStream {
    return _root.child('sensors').onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      return ElectricalData.fromMap(map);
    });
  }

  Stream<String> get classificationStream {
    return _root.child('knn').child('classification').onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) {
        return 'Normal';
      }
      return value.toString();
    }).distinct();
  }

  Stream<Map<int, bool>> get relayStateStream {
    return _relayRoot.onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      final result = <int, bool>{};
      for (final entry in map.entries) {
        final key = entry.key.toLowerCase();
        if (!key.startsWith('relay')) {
          continue;
        }
        final relayNumber = int.tryParse(key.replaceFirst('relay', ''));
        if (relayNumber == null) {
          continue;
        }
        result[relayNumber] = _toBool(entry.value);
      }
      result.putIfAbsent(1, () => false);
      result.putIfAbsent(2, () => false);
      return result;
    });
  }

  Stream<DateTime?> get lastSeenStream {
    return _root.child('device').child('last_seen').onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) {
        return null;
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is double) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsed);
        }
        return DateTime.tryParse(value);
      }
      return null;
    });
  }

  Future<void> setRelay(int relayNumber, bool isOn) {
    return _relayRoot.child('relay$relayNumber').set(isOn);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1' || value.toLowerCase() == 'on';
    }
    return false;
  }
}
