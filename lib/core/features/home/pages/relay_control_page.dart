import 'package:flutter/material.dart';

import '../../../models/device_profile.dart';
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
        _RelayDevice(relayNumber: 1, name: 'Perangkat 1'),
        _RelayDevice(relayNumber: 2, name: 'Perangkat 2'),
        _RelayDevice(relayNumber: 3, name: 'Perangkat 3'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SectionTitle(title: 'Kontrol Perangkat Listrik Per Ruangan'),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: widget.firebaseService.deviceIdListStream,
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
                  if (index != deviceIds.length - 1)
                    const SizedBox(height: 16),
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

  void _showEditSheet(BuildContext context, DeviceProfile profile) {
    final controller = TextEditingController(text: profile.name);
    String selectedIconKey =
        iconOptions.any((option) => option.key == profile.iconKey)
            ? profile.iconKey
            : defaultIconKey;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                      const Expanded(
                        child: Text(
                          'Edit Nama & Icon',
                          style: TextStyle(
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
                    decoration: InputDecoration(
                      labelText: 'Nama Device',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih Icon',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in iconOptions)
                        SizedBox(
                          width: 72,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                selectedIconKey = option.key;
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: option.key == selectedIconKey
                                        ? const Color(0xFF0A7A6F)
                                            .withValues(alpha: 0.12)
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: option.key == selectedIconKey
                                          ? const Color(0xFF0A7A6F)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Icon(
                                    option.icon,
                                    color: option.key == selectedIconKey
                                        ? const Color(0xFF0A7A6F)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final trimmed = controller.text.trim();
                        final name =
                            trimmed.isEmpty ? 'Device $deviceId' : trimmed;
                        firebaseService.setDeviceProfile(
                          deviceId,
                          name: name,
                          iconKey: selectedIconKey,
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
                    final profile = snapshot.data ??
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
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          color: const Color(0xFF6B7280),
                          onPressed: () => _showEditSheet(context, profile),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<Map<int, bool>>(
            stream: firebaseService.relayStateStream(deviceId),
            builder: (context, snapshot) {
              final relayState = snapshot.data ?? <int, bool>{};
              return Column(
                children: [
                  for (final room in rooms) ...[
                    _RoomRelayCard(
                      room: room,
                      relayState: relayState,
                      onChanged: (relay, value) {
                        firebaseService.setRelay(relay, value, deviceId);
                      },
                    ),
                    if (room != rooms.last) const SizedBox(height: 12),
                  ],
                ],
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
  const _RelayDevice({
    required this.relayNumber,
    required this.name,
  });

  final int relayNumber;
  final String name;
}

class _RoomRelayCard extends StatelessWidget {
  const _RoomRelayCard({
    required this.room,
    required this.relayState,
    required this.onChanged,
  });

  final _RoomRelayConfig room;
  final Map<int, bool> relayState;
  final void Function(int relay, bool value) onChanged;

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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
              title: room.devices[index].name,
              relayNumber: room.devices[index].relayNumber,
              value: relayState[room.devices[index].relayNumber] ?? false,
              onChanged: (value) =>
                  onChanged(room.devices[index].relayNumber, value),
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
  });

  final String title;
  final int relayNumber;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      secondary: const Icon(
        Icons.electrical_services_outlined,
        color: Color(0xFF0A7A6F),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Relay $relayNumber'),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0A7A6F),
    );
  }
}
