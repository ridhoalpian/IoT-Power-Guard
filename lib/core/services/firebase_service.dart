import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/device_profile.dart';
import '../models/electrical_data.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  static const String _databaseUrl =
      'https://home-electrical-tracking-54460-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _iotRootPath = 'iot_power_guard';
  static const int _defaultRelayCount = 3;
  static const int _deviceOfflineThresholdMs = 5000;
  static const int _epochMsThreshold = 1000000000000;
  static const int _epochSecondsThreshold = 1000000000;
  static const String _userEmail = 'ridhoalpian8713@gmail.com';
  static const String _userPassword = 'ridho8733';
  static const String _defaultDeviceId = '6800';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );
  late final DatabaseReference _root = _database.ref(_iotRootPath);
  late final DatabaseReference _deviceRoot = _database.ref('device');
  late final DatabaseReference _defaultDeviceRoot =
      _deviceRoot.child(_defaultDeviceId);
  int? _deviceBootEpochMs;
  int? _lastUptimeMs;
  DateTime? _cachedLastSeen;

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

  Stream<ElectricalData> deviceMonitoringStream(String deviceId) {
    return _deviceRoot
        .child(deviceId)
        .child('monitoring')
        .onValue
        .map((event) {
      final map = _asMap(event.snapshot.value);
      return ElectricalData.fromMap(map);
    });
  }

  Stream<DeviceProfile> deviceProfileStream(
    String deviceId, {
    required String fallbackName,
    required String fallbackIconKey,
  }) {
    return _deviceRoot.child(deviceId).child('profile').onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      final nameValue = map['name']?.toString().trim();
      final iconValue = map['icon']?.toString().trim();
      return DeviceProfile(
        name: (nameValue == null || nameValue.isEmpty)
            ? fallbackName
            : nameValue,
        iconKey: (iconValue == null || iconValue.isEmpty)
            ? fallbackIconKey
            : iconValue,
      );
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

  Stream<List<String>> get deviceIdListStream {
    return _deviceRoot.onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      final deviceIds = map.entries
          .where((entry) => entry.value is Map)
          .map((entry) => entry.key)
          .toList();
      deviceIds.sort();
      return deviceIds;
    });
  }

  Stream<Map<int, bool>> relayStateStream(String deviceId) {
    final query = _deviceRoot
        .child(deviceId)
        .orderByKey()
        .startAt('relay')
        .endAt('relay\uf8ff');
    return query.onValue.map((event) {
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
      for (var index = 1; index <= _defaultRelayCount; index++) {
        result.putIfAbsent(index, () => false);
      }
      return result;
    });
  }

  Stream<DateTime?> get lastSeenStream {
    return _root.child('device').child('last_seen').onValue.map((event) {
      return _parseDateTime(event.snapshot.value);
    });
  }

  Stream<DateTime?> get deviceLastSeenStream {
    return _defaultDeviceRoot.child('last_seen').onValue.map((event) {
      final parsed = _parseDateTime(event.snapshot.value);
      _cachedLastSeen = parsed;
      return parsed;
    });
  }

  Stream<bool> get deviceOnlineByLastSeenStream async* {
  // listen firebase sekali
  deviceLastSeenStream.listen((_) {});

  while (true) {
    await Future.delayed(const Duration(seconds: 1));

    if (_cachedLastSeen == null) {
      yield false;
      continue;
    }

    final now = DateTime.now();
    final diff = now.difference(_cachedLastSeen!).inMilliseconds;

    yield diff < _deviceOfflineThresholdMs;
  }
}

  Future<void> setDeviceProfile(
    String deviceId, {
    String? name,
    String? iconKey,
  }) {
    final updates = <String, dynamic>{};
    if (name != null) {
      updates['name'] = name;
    }
    if (iconKey != null) {
      updates['icon'] = iconKey;
    }
    if (updates.isEmpty) {
      return Future.value();
    }
    return _deviceRoot.child(deviceId).child('profile').update(updates);
  }

  Future<void> setRelay(int relayNumber, bool isOn, String deviceId) {
    return _deviceRoot.child(deviceId).child('relay$relayNumber').set(isOn);
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

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    int? numeric;
    if (value is int) {
      numeric = value;
    } else if (value is double) {
      numeric = value.toInt();
    } else if (value is String) {
      numeric = int.tryParse(value);
      if (numeric == null) {
        return DateTime.tryParse(value);
      }
    }

    if (numeric == null) {
      return null;
    }

    if (numeric >= _epochMsThreshold) {
      return DateTime.fromMillisecondsSinceEpoch(numeric);
    }

    if (numeric >= _epochSecondsThreshold) {
      return DateTime.fromMillisecondsSinceEpoch(numeric * 1000);
    }

    if (_deviceBootEpochMs == null ||
        _lastUptimeMs == null ||
        numeric < _lastUptimeMs!) {
      _deviceBootEpochMs = DateTime.now().millisecondsSinceEpoch - numeric;
    }
    _lastUptimeMs = numeric;
    final bootEpochMs = _deviceBootEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(bootEpochMs + numeric);
  }
}
