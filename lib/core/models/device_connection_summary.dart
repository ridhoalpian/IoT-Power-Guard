class DeviceConnectionSummary {
  const DeviceConnectionSummary({
    required this.totalDevices,
    required this.onlineDevices,
    required this.offlineDevices,
    required this.latestLastSeen,
    required this.onlineDeviceNames,
    required this.offlineDeviceNames,
  });

  final int totalDevices;
  final int onlineDevices;
  final int offlineDevices;
  final DateTime? latestLastSeen;
  final List<String> onlineDeviceNames;
  final List<String> offlineDeviceNames;

  bool get hasDevices => totalDevices > 0;
  bool get allOnline => hasDevices && onlineDevices == totalDevices;
  bool get allOffline => hasDevices && offlineDevices == totalDevices;

  factory DeviceConnectionSummary.empty() {
    return const DeviceConnectionSummary(
      totalDevices: 0,
      onlineDevices: 0,
      offlineDevices: 0,
      latestLastSeen: null,
      onlineDeviceNames: <String>[],
      offlineDeviceNames: <String>[],
    );
  }
}
