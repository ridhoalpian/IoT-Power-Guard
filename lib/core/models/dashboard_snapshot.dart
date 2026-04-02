import 'electrical_data.dart';

enum ConsumptionLevel { low, medium, high }

extension ConsumptionLevelX on ConsumptionLevel {
  String get label {
    switch (this) {
      case ConsumptionLevel.low:
        return 'LOW';
      case ConsumptionLevel.medium:
        return 'MEDIUM';
      case ConsumptionLevel.high:
        return 'HIGH';
    }
  }
}

class RoomDashboardData {
  const RoomDashboardData({
    required this.roomName,
    required this.deviceId,
    required this.monitoring,
    required this.classification,
    required this.isOnline,
    required this.lastSeen,
    required this.hasAssignedDevice,
  });

  final String roomName;
  final String? deviceId;
  final ElectricalData monitoring;
  final ConsumptionLevel classification;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool hasAssignedDevice;

  factory RoomDashboardData.placeholder(String roomName) {
    return RoomDashboardData(
      roomName: roomName,
      deviceId: null,
      monitoring: ElectricalData.empty(),
      classification: ConsumptionLevel.low,
      isOnline: false,
      lastSeen: null,
      hasAssignedDevice: false,
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.rooms,
    required this.totalConsumption,
    required this.latestLastSeen,
  });

  final List<RoomDashboardData> rooms;
  final ElectricalData totalConsumption;
  final DateTime? latestLastSeen;

  bool get hasAssignedDevices => rooms.any((room) => room.hasAssignedDevice);

  int get assignedDeviceCount =>
      rooms.where((room) => room.hasAssignedDevice).length;

  int get onlineDevices => rooms.where((room) => room.isOnline).length;

  bool get allOnline =>
      hasAssignedDevices && onlineDevices == assignedDeviceCount;

  bool get allOffline => hasAssignedDevices && onlineDevices == 0;

  List<RoomDashboardData> get highConsumptionRooms {
    return rooms
        .where((room) => room.classification == ConsumptionLevel.high)
        .toList(growable: false);
  }

  factory DashboardSnapshot.empty() {
    return DashboardSnapshot(
      rooms: [
        RoomDashboardData.placeholder('Dapur'),
        RoomDashboardData.placeholder('Kamar'),
        RoomDashboardData.placeholder('Ruang Tengah'),
      ],
      totalConsumption: ElectricalData.empty(),
      latestLastSeen: null,
    );
  }
}
