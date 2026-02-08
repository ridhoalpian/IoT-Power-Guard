import 'package:firebase_database/firebase_database.dart';

import '../models/electrical_data.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  final DatabaseReference _root = FirebaseDatabase.instance.ref('iot_power_guard');

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
    return _root.child('relays').onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      return {
        1: _toBool(map['relay1']),
        2: _toBool(map['relay2']),
        3: _toBool(map['relay3']),
        4: _toBool(map['relay4']),
      };
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
    return _root.child('relays').child('relay$relayNumber').set(isOn);
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
