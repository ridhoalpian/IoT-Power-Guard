import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/device_connection_summary.dart';
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
  static const int _uint32Mod = 4294967296;
  static const int _maxReasonableLastSeenDriftMs = 31536000000;
  static const String _userEmail = 'ridhoalpian8713@gmail.com';
  static const String _userPassword = 'ridho8733';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );
  late final DatabaseReference _root = _database.ref(_iotRootPath);
  late final DatabaseReference _deviceRoot = _database.ref('device');

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
    return _deviceRoot.onValue
        .map((event) {
          final map = _asMap(event.snapshot.value);
          var total = ElectricalData.empty();
          for (final value in map.values) {
            final deviceMap = _asMap(value);
            final monitoringMap = _asMap(deviceMap['monitoring']);
            total += ElectricalData.fromMap(monitoringMap);
          }
          return total;
        })
        .distinct(_electricalDataEquals);
  }

  Stream<ElectricalData> deviceMonitoringStream(String deviceId) {
    return _deviceRoot
        .child(deviceId)
        .child('monitoring')
        .onValue
        .map((event) {
          final map = _asMap(event.snapshot.value);
          return ElectricalData.fromMap(map);
        })
        .distinct(_electricalDataEquals);
  }

  Stream<DeviceProfile> deviceProfileStream(
    String deviceId, {
    required String fallbackName,
    required String fallbackIconKey,
  }) {
    return _deviceRoot
        .child(deviceId)
        .child('profile')
        .onValue
        .map((event) {
          final map = _asMap(event.snapshot.value);
          final nameValue = map['name']?.toString().trim();
          final iconValue = map['icon']?.toString().trim();
          return DeviceProfile(
            name:
                (nameValue == null || nameValue.isEmpty)
                    ? fallbackName
                    : nameValue,
            iconKey:
                (iconValue == null || iconValue.isEmpty)
                    ? fallbackIconKey
                    : iconValue,
          );
        })
        .distinct(_deviceProfileEquals);
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
    return _deviceRoot.onValue
        .map((event) {
          final map = _asMap(event.snapshot.value);
          final deviceIds =
              map.entries
                  .where((entry) => entry.value is Map)
                  .map((entry) => entry.key)
                  .toList();
          deviceIds.sort();
          return deviceIds;
        })
        .distinct(_stringListEquals);
  }

  Stream<Map<int, bool>> relayStateStream(String deviceId) {
    final query = _deviceRoot
        .child(deviceId)
        .orderByKey()
        .startAt('relay')
        .endAt('relay\uf8ff');
    return query.onValue
        .map((event) {
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
        })
        .distinct(_boolMapEquals);
  }

  Stream<Map<int, String>> relayLabelStream(
    String deviceId, {
    Map<int, String> fallbackLabels = const {},
  }) {
    return _deviceRoot
        .child(deviceId)
        .child('relay_labels')
        .onValue
        .map((event) {
          final map = _asMap(event.snapshot.value);
          final result = <int, String>{};
          for (final entry in map.entries) {
            final key = entry.key.toLowerCase();
            if (!key.startsWith('relay')) {
              continue;
            }
            final relayNumber = int.tryParse(key.replaceFirst('relay', ''));
            if (relayNumber == null) {
              continue;
            }
            final label = entry.value?.toString().trim();
            if (label == null || label.isEmpty) {
              continue;
            }
            result[relayNumber] = label;
          }
          for (final entry in fallbackLabels.entries) {
            result.putIfAbsent(entry.key, () => entry.value);
          }
          return result;
        })
        .distinct(_stringMapEquals);
  }

  Stream<DeviceConnectionSummary> deviceConnectionSummaryStream({
    Duration? offlineThreshold,
  }) {
    final threshold =
        offlineThreshold ??
        const Duration(milliseconds: _deviceOfflineThresholdMs);
    late final StreamController<DeviceConnectionSummary> controller;
    StreamSubscription<Map<String, dynamic>>? subscription;
    Timer? timer;
    Map<String, dynamic> latestDeviceState = const {};

    void emitSummary() {
      if (controller.isClosed) {
        return;
      }
      controller.add(
        _buildConnectionSummary(latestDeviceState, offlineThreshold: threshold),
      );
    }

    controller = StreamController<DeviceConnectionSummary>.broadcast(
      onListen: () {
        subscription = _deviceRoot.onValue
            .map((event) {
              return _asMap(event.snapshot.value);
            })
            .listen((value) {
              latestDeviceState = value;
              emitSummary();
            }, onError: controller.addError);
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          emitSummary();
        });
      },
      onCancel: () async {
        await subscription?.cancel();
        timer?.cancel();
      },
    );

    return controller.stream.distinct(_connectionSummaryEquals);
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

  Future<void> setRelayLabel(
    String deviceId, {
    required int relayNumber,
    String? name,
  }) {
    final label = name?.trim();
    final reference = _deviceRoot
        .child(deviceId)
        .child('relay_labels')
        .child('relay$relayNumber');
    if (label == null || label.isEmpty) {
      return reference.remove();
    }
    return reference.set(label);
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
      return value.toLowerCase() == 'true' ||
          value == '1' ||
          value.toLowerCase() == 'on';
    }
    return false;
  }

  static bool _deviceProfileEquals(DeviceProfile previous, DeviceProfile next) {
    return previous.name == next.name && previous.iconKey == next.iconKey;
  }

  static bool _stringListEquals(List<String> previous, List<String> next) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != next[index]) {
        return false;
      }
    }
    return true;
  }

  static bool _boolMapEquals(Map<int, bool> previous, Map<int, bool> next) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous.length != next.length) {
      return false;
    }
    for (final entry in previous.entries) {
      if (next[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _stringMapEquals(
    Map<int, String> previous,
    Map<int, String> next,
  ) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous.length != next.length) {
      return false;
    }
    for (final entry in previous.entries) {
      if (next[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _electricalDataEquals(
    ElectricalData previous,
    ElectricalData next,
  ) {
    return previous.voltage == next.voltage &&
        previous.current == next.current &&
        previous.power == next.power &&
        previous.energy == next.energy;
  }

  static bool _connectionSummaryEquals(
    DeviceConnectionSummary previous,
    DeviceConnectionSummary next,
  ) {
    return previous.totalDevices == next.totalDevices &&
        previous.onlineDevices == next.onlineDevices &&
        previous.offlineDevices == next.offlineDevices &&
        previous.latestLastSeen == next.latestLastSeen &&
        _stringListEquals(previous.onlineDeviceNames, next.onlineDeviceNames) &&
        _stringListEquals(previous.offlineDeviceNames, next.offlineDeviceNames);
  }

  DeviceConnectionSummary _buildConnectionSummary(
    Map<String, dynamic> deviceStateById, {
    required Duration offlineThreshold,
  }) {
    if (deviceStateById.isEmpty) {
      return DeviceConnectionSummary.empty();
    }

    final now = DateTime.now();
    var onlineDevices = 0;
    DateTime? latestLastSeen;
    final onlineDeviceNames = <String>[];
    final offlineDeviceNames = <String>[];

    for (final entry in deviceStateById.entries) {
      final deviceId = entry.key;
      final deviceMap = _asMap(entry.value);
      final profileMap = _asMap(deviceMap['profile']);
      final monitoringMap = _asMap(deviceMap['monitoring']);
      final deviceName = _resolveDeviceName(profileMap, deviceId);
      final monitoringTimestamp = _parseDateTime(monitoringMap['timestamp']);
      final lastSeen = _parseLastSeen(
        deviceMap['last_seen'],
        referenceTime: monitoringTimestamp ?? now,
      );

      if (lastSeen != null &&
          now.difference(lastSeen).inMilliseconds <=
              offlineThreshold.inMilliseconds) {
        onlineDevices++;
        onlineDeviceNames.add(deviceName);
      } else {
        offlineDeviceNames.add(deviceName);
      }
      if (lastSeen != null &&
          (latestLastSeen == null || lastSeen.isAfter(latestLastSeen))) {
        latestLastSeen = lastSeen;
      }
    }

    onlineDeviceNames.sort();
    offlineDeviceNames.sort();

    final totalDevices = deviceStateById.length;
    return DeviceConnectionSummary(
      totalDevices: totalDevices,
      onlineDevices: onlineDevices,
      offlineDevices: totalDevices - onlineDevices,
      latestLastSeen: latestLastSeen,
      onlineDeviceNames: onlineDeviceNames,
      offlineDeviceNames: offlineDeviceNames,
    );
  }

  static String _resolveDeviceName(
    Map<String, dynamic> profileMap,
    String deviceId,
  ) {
    final rawName = profileMap['name']?.toString().trim();
    if (rawName == null || rawName.isEmpty) {
      return 'Device $deviceId';
    }
    return rawName;
  }

  static DateTime? _parseLastSeen(dynamic value, {DateTime? referenceTime}) {
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
    } else {
      return null;
    }

    final reference = referenceTime ?? DateTime.now();
    final referenceMs = reference.millisecondsSinceEpoch;
    final candidates = <DateTime>[];

    if (numeric.abs() >= _epochSecondsThreshold) {
      candidates.add(DateTime.fromMillisecondsSinceEpoch(numeric * 1000));
    }

    final wrappedUnsigned = numeric & 0xFFFFFFFF;
    final wrappedMs = _unwrap32BitMilliseconds(
      wrappedUnsigned,
      referenceMilliseconds: referenceMs,
    );
    candidates.add(DateTime.fromMillisecondsSinceEpoch(wrappedMs));

    DateTime? best;
    var bestDiff = _maxReasonableLastSeenDriftMs + 1;

    for (final candidate in candidates) {
      final diff = (candidate.millisecondsSinceEpoch - referenceMs).abs();
      if (diff < bestDiff) {
        best = candidate;
        bestDiff = diff;
      }
    }

    if (bestDiff > _maxReasonableLastSeenDriftMs) {
      return null;
    }

    return best;
  }

  static int _unwrap32BitMilliseconds(
    int wrappedMilliseconds, {
    required int referenceMilliseconds,
  }) {
    final offset = referenceMilliseconds - wrappedMilliseconds;
    var cycles = offset ~/ _uint32Mod;

    final lowerCandidate = wrappedMilliseconds + (cycles * _uint32Mod);
    final upperCandidate = wrappedMilliseconds + ((cycles + 1) * _uint32Mod);

    if ((upperCandidate - referenceMilliseconds).abs() <
        (lowerCandidate - referenceMilliseconds).abs()) {
      cycles += 1;
    }

    return wrappedMilliseconds + (cycles * _uint32Mod);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final numeric = int.tryParse(value);
      if (numeric == null) {
        return DateTime.tryParse(value);
      }
      value = numeric;
    }
    int? numeric;
    if (value is int) {
      numeric = value;
    } else if (value is double) {
      numeric = value.toInt();
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

    return null;
  }
}
