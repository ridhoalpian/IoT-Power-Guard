import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/dashboard_snapshot.dart';
import '../models/device_connection_summary.dart';
import '../models/device_profile.dart';
import '../models/electrical_data.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();
  static const Duration deviceOfflineThreshold = Duration(
    milliseconds: _deviceOfflineThresholdMs,
  );

  static const String _databaseUrl =
      'https://home-electrical-tracking-54460-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _iotRootPath = 'iot_power_guard';
  static const int _defaultRelayCount = 3;
  static const int _deviceOfflineThresholdMs = 20000;
  static const int _epochMsThreshold = 1000000000000;
  static const int _epochSecondsThreshold = 1000000000;
  static const int _uint32Mod = 4294967296;
  static const int _maxReasonableLastSeenDriftMs = 31536000000;
  static const String _userEmail = 'ridhoalpian8713@gmail.com';
  static const String _userPassword = 'ridho8733';
  static const double _lowConsumptionThresholdWatts = 150;
  static const double _mediumConsumptionThresholdWatts = 400;
  static const List<_DashboardRoomConfig> _dashboardRoomConfigs = [
    _DashboardRoomConfig(
      label: 'Dapur',
      aliases: ['dapur', 'kitchen', 'device1', 'esp32_1'],
    ),
    _DashboardRoomConfig(
      label: 'Kamar',
      aliases: ['kamar', 'bedroom', 'bed', 'device2', 'esp32_2'],
    ),
    _DashboardRoomConfig(
      label: 'Ruang Tengah',
      aliases: [
        'ruang tengah',
        'ruang_tengah',
        'living room',
        'living',
        'device3',
        'esp32_3',
      ],
    ),
  ];

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
          final readings = <ElectricalData>[];
          for (final value in map.values) {
            final deviceMap = _asMap(value);
            final monitoringMap = _asMap(deviceMap['monitoring']);
            readings.add(ElectricalData.fromMap(monitoringMap));
          }
          return ElectricalData.aggregate(readings);
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

  Stream<DashboardSnapshot> dashboardSnapshotStream({
    Duration? offlineThreshold,
  }) {
    final threshold =
        offlineThreshold ??
        const Duration(milliseconds: _deviceOfflineThresholdMs);
    late final StreamController<DashboardSnapshot> controller;
    StreamSubscription<Map<String, dynamic>>? subscription;
    Timer? timer;
    Map<String, dynamic> latestDeviceState = const {};

    void emitSnapshot() {
      if (controller.isClosed) {
        return;
      }
      controller.add(
        _buildDashboardSnapshot(latestDeviceState, offlineThreshold: threshold),
      );
    }

    controller = StreamController<DashboardSnapshot>.broadcast(
      onListen: () {
        subscription = _deviceRoot.onValue
            .map((event) {
              return _asMap(event.snapshot.value);
            })
            .listen((value) {
              latestDeviceState = value;
              emitSnapshot();
            }, onError: controller.addError);
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          emitSnapshot();
        });
      },
      onCancel: () async {
        await subscription?.cancel();
        timer?.cancel();
      },
    );

    return controller.stream.distinct(_dashboardSnapshotEquals);
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

  Future<void> saveNotificationToken(String token) {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      return Future.value();
    }

    final encodedToken = base64Url.encode(utf8.encode(trimmedToken));
    return _root.child('notification_tokens').child(encodedToken).set({
      'token': trimmedToken,
      'updated_at': ServerValue.timestamp,
      'platform': defaultTargetPlatform.name,
    });
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

  static bool _dashboardSnapshotEquals(
    DashboardSnapshot previous,
    DashboardSnapshot next,
  ) {
    if (!_electricalDataEquals(
      previous.totalConsumption,
      next.totalConsumption,
    )) {
      return false;
    }
    if (previous.latestLastSeen != next.latestLastSeen) {
      return false;
    }
    if (previous.rooms.length != next.rooms.length) {
      return false;
    }
    for (var index = 0; index < previous.rooms.length; index++) {
      final prevRoom = previous.rooms[index];
      final nextRoom = next.rooms[index];
      if (prevRoom.roomName != nextRoom.roomName ||
          prevRoom.deviceId != nextRoom.deviceId ||
          prevRoom.classification != nextRoom.classification ||
          prevRoom.isOnline != nextRoom.isOnline ||
          prevRoom.lastSeen != nextRoom.lastSeen ||
          prevRoom.hasAssignedDevice != nextRoom.hasAssignedDevice ||
          !_electricalDataEquals(prevRoom.monitoring, nextRoom.monitoring)) {
        return false;
      }
    }
    return true;
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

  DashboardSnapshot _buildDashboardSnapshot(
    Map<String, dynamic> deviceStateById, {
    required Duration offlineThreshold,
  }) {
    if (deviceStateById.isEmpty) {
      return DashboardSnapshot.empty();
    }

    final now = DateTime.now();
    final resolvedDevices = <_ResolvedDashboardDevice>[];
    final totalReadings = <ElectricalData>[];
    DateTime? latestLastSeen;

    for (final entry in deviceStateById.entries) {
      final deviceId = entry.key;
      final deviceMap = _asMap(entry.value);
      final profileMap = _asMap(deviceMap['profile']);
      final monitoringMap = _asMap(deviceMap['monitoring']);
      final monitoring = ElectricalData.fromMap(monitoringMap);
      final deviceName = _resolveDeviceName(profileMap, deviceId);
      final monitoringTimestamp = _parseDateTime(monitoringMap['timestamp']);
      final lastSeen = _parseLastSeen(
        deviceMap['last_seen'],
        referenceTime: monitoringTimestamp ?? now,
      );
      final isOnline =
          lastSeen != null &&
          now.difference(lastSeen).inMilliseconds <=
              offlineThreshold.inMilliseconds;

      resolvedDevices.add(
        _ResolvedDashboardDevice(
          deviceId: deviceId,
          name: deviceName,
          monitoring: monitoring,
          classification:
              _resolveConsumptionLevel(deviceMap, monitoringMap) ??
              _classifyByPower(monitoring.power),
          isOnline: isOnline,
          lastSeen: lastSeen,
        ),
      );
      totalReadings.add(monitoring);
      if (lastSeen != null &&
          (latestLastSeen == null || lastSeen.isAfter(latestLastSeen))) {
        latestLastSeen = lastSeen;
      }
    }

    final roomAssignments = _assignDashboardRooms(resolvedDevices);
    final rooms = _dashboardRoomConfigs
        .map((config) {
          final assignedDevice = roomAssignments[config.label];
          if (assignedDevice == null) {
            return RoomDashboardData.placeholder(config.label);
          }
          return RoomDashboardData(
            roomName: config.label,
            deviceId: assignedDevice.deviceId,
            monitoring: assignedDevice.monitoring,
            classification: assignedDevice.classification,
            isOnline: assignedDevice.isOnline,
            lastSeen: assignedDevice.lastSeen,
            hasAssignedDevice: true,
          );
        })
        .toList(growable: false);

    return DashboardSnapshot(
      rooms: rooms,
      totalConsumption: ElectricalData.aggregate(totalReadings),
      latestLastSeen: latestLastSeen,
    );
  }

  Map<String, _ResolvedDashboardDevice> _assignDashboardRooms(
    List<_ResolvedDashboardDevice> devices,
  ) {
    final assignments = <String, _ResolvedDashboardDevice>{};
    final remainingDevices = List<_ResolvedDashboardDevice>.from(devices);

    for (final config in _dashboardRoomConfigs) {
      _ResolvedDashboardDevice? match;
      for (final device in remainingDevices) {
        if (_matchesRoomConfig(device, config)) {
          match = device;
          break;
        }
      }
      if (match == null) {
        continue;
      }
      assignments[config.label] = match;
      remainingDevices.remove(match);
    }

    for (final config in _dashboardRoomConfigs) {
      if (assignments.containsKey(config.label) || remainingDevices.isEmpty) {
        continue;
      }
      assignments[config.label] = remainingDevices.removeAt(0);
    }

    return assignments;
  }

  bool _matchesRoomConfig(
    _ResolvedDashboardDevice device,
    _DashboardRoomConfig config,
  ) {
    final normalizedName = device.name.toLowerCase();
    final normalizedId = device.deviceId.toLowerCase();
    for (final alias in config.aliases) {
      if (normalizedName.contains(alias) || normalizedId.contains(alias)) {
        return true;
      }
    }
    return false;
  }

  ConsumptionLevel _classifyByPower(double power) {
    if (power >= _mediumConsumptionThresholdWatts) {
      return ConsumptionLevel.high;
    }
    if (power >= _lowConsumptionThresholdWatts) {
      return ConsumptionLevel.medium;
    }
    return ConsumptionLevel.low;
  }

  ConsumptionLevel? _resolveConsumptionLevel(
    Map<String, dynamic> deviceMap,
    Map<String, dynamic> monitoringMap,
  ) {
    final knnMap = _asMap(deviceMap['knn']);
    return _parseConsumptionLevel(knnMap['classification']) ??
        _parseConsumptionLevel(deviceMap['classification']) ??
        _parseConsumptionLevel(deviceMap['knn_classification']) ??
        _parseConsumptionLevel(monitoringMap['classification']);
  }

  ConsumptionLevel? _parseConsumptionLevel(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized == 'low' || normalized == 'normal' || normalized == 'aman') {
      return ConsumptionLevel.low;
    }
    if (normalized == 'medium' ||
        normalized == 'sedang' ||
        normalized == 'waspada') {
      return ConsumptionLevel.medium;
    }
    if (normalized == 'high' ||
        normalized == 'tinggi' ||
        normalized == 'boros') {
      return ConsumptionLevel.high;
    }
    return null;
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

class _DashboardRoomConfig {
  const _DashboardRoomConfig({required this.label, required this.aliases});

  final String label;
  final List<String> aliases;
}

class _ResolvedDashboardDevice {
  const _ResolvedDashboardDevice({
    required this.deviceId,
    required this.name,
    required this.monitoring,
    required this.classification,
    required this.isOnline,
    required this.lastSeen,
  });

  final String deviceId;
  final String name;
  final ElectricalData monitoring;
  final ConsumptionLevel classification;
  final bool isOnline;
  final DateTime? lastSeen;
}
