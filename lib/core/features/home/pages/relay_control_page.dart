import 'package:flutter/material.dart';

import '../../../models/device_profile.dart';
import '../../../models/electrical_data.dart';
import '../../../services/firebase_service.dart';
import '../widgets/home_widgets.dart';

class RelayControlPage extends StatefulWidget {
  const RelayControlPage({super.key, required this.firebaseService});

  final FirebaseService firebaseService;

  @override
  State<RelayControlPage> createState() => _RelayControlPageState();
}

class _RelayControlPageState extends State<RelayControlPage>
    with AutomaticKeepAliveClientMixin<RelayControlPage> {
  static const String _defaultIconKey = 'device';
  static const List<_IconOption> _iconOptions = [
    _IconOption('device', Icons.memory_outlined, 'Device'),
    _IconOption('kitchen', Icons.kitchen_outlined, 'Dapur'),
    _IconOption('bed', Icons.bed_outlined, 'Kamar'),
    _IconOption('chair', Icons.chair_outlined, 'Ruang Depan'),
    _IconOption('meeting', Icons.meeting_room_outlined, 'Ruang Rapat'),
    _IconOption('weekend', Icons.weekend_outlined, 'Ruang Tamu'),
    _IconOption('warehouse', Icons.warehouse_outlined, 'Gudang'),
    _IconOption('store', Icons.store_outlined, 'Toko'),
    _IconOption('bulb', Icons.lightbulb_outline, 'Lampu'),
    _IconOption('power', Icons.electrical_services_outlined, 'Perangkat'),
  ];

  static IconData _iconFromKey(String? key) {
    final normalized = (key ?? '').toLowerCase();
    for (final option in _iconOptions) {
      if (option.key == normalized) {
        return option.icon;
      }
    }
    return Icons.memory_outlined;
  }

  final List<_RoomRelayConfig> _rooms = const [
    _RoomRelayConfig(
      name: 'Kontrol Utama',
      icon: Icons.power_outlined,
      devices: [
        _RelayDevice(relayNumber: 1, defaultName: 'Perangkat 1'),
        _RelayDevice(relayNumber: 2, defaultName: 'Perangkat 2'),
        _RelayDevice(relayNumber: 3, defaultName: 'Perangkat 3'),
      ],
    ),
  ];

  late final Stream<List<String>> _deviceIdListStream;

  @override
  void initState() {
    super.initState();
    _deviceIdListStream = widget.firebaseService.deviceIdListStream;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SectionTitle(title: 'Kontrol Perangkat Listrik Per Ruangan'),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: _deviceIdListStream,
          builder: (context, snapshot) {
            final deviceIds = snapshot.data ?? const <String>[];

            if (deviceIds.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Belum ada device terdaftar di /device.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (var index = 0; index < deviceIds.length; index++) ...[
                  _DeviceRelaySection(
                    deviceId: deviceIds[index],
                    rooms: _rooms,
                    firebaseService: widget.firebaseService,
                    iconOptions: _iconOptions,
                    defaultIconKey: _defaultIconKey,
                    iconFromKey: _iconFromKey,
                  ),
                  if (index != deviceIds.length - 1) const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _DeviceRelaySection extends StatelessWidget {
  const _DeviceRelaySection({
    required this.deviceId,
    required this.rooms,
    required this.firebaseService,
    required this.iconOptions,
    required this.defaultIconKey,
    required this.iconFromKey,
  });

  final String deviceId;
  final List<_RoomRelayConfig> rooms;
  final FirebaseService firebaseService;
  final List<_IconOption> iconOptions;
  final String defaultIconKey;
  final IconData Function(String? key) iconFromKey;

  Map<int, String> get _defaultRelayLabels => {
    for (final room in rooms)
      for (final device in room.devices) device.relayNumber: device.defaultName,
  };

  void _showRelayNameSheet(
    BuildContext context, {
    required int relayNumber,
    required String currentName,
    required String fallbackName,
  }) {
    final controller = TextEditingController(text: currentName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rename Relay $relayNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Nama Perangkat',
                  hintText: fallbackName,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kosongkan nama untuk kembali ke label default.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    firebaseService.setRelayLabel(
                      deviceId,
                      relayNumber: relayNumber,
                      name: controller.text,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A7A6F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<DeviceProfile>(
                  stream: firebaseService.deviceProfileStream(
                    deviceId,
                    fallbackName: 'Device $deviceId',
                    fallbackIconKey: defaultIconKey,
                  ),
                  builder: (context, snapshot) {
                    final profile =
                        snapshot.data ??
                        DeviceProfile(
                          name: 'Device $deviceId',
                          iconKey: defaultIconKey,
                        );
                    return Row(
                      children: [
                        Icon(
                          iconFromKey(profile.iconKey),
                          color: const Color(0xFF0A7A6F),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profile.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              StreamBuilder<ElectricalData>(
                stream: firebaseService.deviceMonitoringStream(deviceId),
                builder: (context, snapshot) {
                  final power = snapshot.data?.power ?? 0;
                  return _PowerBadge(power: power);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<Map<int, String>>(
            stream: firebaseService.relayLabelStream(
              deviceId,
              fallbackLabels: _defaultRelayLabels,
            ),
            builder: (context, snapshot) {
              final relayLabels = snapshot.data ?? _defaultRelayLabels;
              return StreamBuilder<Map<int, bool>>(
                stream: firebaseService.relayStateStream(deviceId),
                builder: (context, snapshot) {
                  final relayState = snapshot.data ?? <int, bool>{};
                  return Column(
                    children: [
                      for (final room in rooms) ...[
                        _RoomRelayCard(
                          room: room,
                          relayState: relayState,
                          relayLabels: relayLabels,
                          onChanged: (relay, value) {
                            firebaseService.setRelay(relay, value, deviceId);
                          },
                          onRename: (relayNumber, currentName, fallbackName) {
                            _showRelayNameSheet(
                              context,
                              relayNumber: relayNumber,
                              currentName: currentName,
                              fallbackName: fallbackName,
                            );
                          },
                        ),
                        if (room != rooms.last) const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoomRelayConfig {
  const _RoomRelayConfig({
    required this.name,
    required this.icon,
    required this.devices,
  });

  final String name;
  final IconData icon;
  final List<_RelayDevice> devices;
}

class _IconOption {
  const _IconOption(this.key, this.icon, this.label);

  final String key;
  final IconData icon;
  final String label;
}

class _RelayDevice {
  const _RelayDevice({required this.relayNumber, required this.defaultName});

  final int relayNumber;
  final String defaultName;
}

class _PowerBadge extends StatelessWidget {
  const _PowerBadge({required this.power});

  final double power;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_outlined, size: 16, color: Color(0xFF0F766E)),
          const SizedBox(width: 4),
          Text(
            '${power.toStringAsFixed(1)} W',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomRelayCard extends StatelessWidget {
  const _RoomRelayCard({
    required this.room,
    required this.relayState,
    required this.relayLabels,
    required this.onChanged,
    required this.onRename,
  });

  final _RoomRelayConfig room;
  final Map<int, bool> relayState;
  final Map<int, String> relayLabels;
  final void Function(int relay, bool value) onChanged;
  final void Function(int relayNumber, String currentName, String fallbackName)
  onRename;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(room.icon, color: const Color(0xFF0A7A6F)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${room.devices.length} perangkat',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < room.devices.length; index++) ...[
            _RelayDeviceTile(
              title:
                  relayLabels[room.devices[index].relayNumber] ??
                  room.devices[index].defaultName,
              relayNumber: room.devices[index].relayNumber,
              value: relayState[room.devices[index].relayNumber] ?? false,
              onChanged:
                  (value) => onChanged(room.devices[index].relayNumber, value),
              onRename:
                  () => onRename(
                    room.devices[index].relayNumber,
                    relayLabels[room.devices[index].relayNumber] ??
                        room.devices[index].defaultName,
                    room.devices[index].defaultName,
                  ),
            ),
            if (index != room.devices.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RelayDeviceTile extends StatelessWidget {
  const _RelayDeviceTile({
    required this.title,
    required this.relayNumber,
    required this.value,
    required this.onChanged,
    required this.onRename,
  });

  final String title;
  final int relayNumber;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      secondary: const Icon(
        Icons.electrical_services_outlined,
        color: Color(0xFF0A7A6F),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Rename perangkat',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0A7A6F),
    );
  }
}
