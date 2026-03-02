import 'package:flutter/material.dart';

import '../../../services/firebase_service.dart';
import '../widgets/home_widgets.dart';

class RelayControlPage extends StatefulWidget {
  const RelayControlPage({super.key, required this.firebaseService});

  final FirebaseService firebaseService;

  @override
  State<RelayControlPage> createState() => _RelayControlPageState();
}

class _RelayControlPageState extends State<RelayControlPage> {
  String? _selectedDeviceId;

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

            if (_selectedDeviceId == null ||
                !deviceIds.contains(_selectedDeviceId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _selectedDeviceId = deviceIds.first;
                });
              });
            }

            final selectedId = _selectedDeviceId ?? deviceIds.first;

            return Column(
              children: [
                Container(
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
                  child: DropdownButtonFormField<String>(
                    value: selectedId,
                    isExpanded: true,
                    items: deviceIds
                        .map(
                          (deviceId) => DropdownMenuItem(
                            value: deviceId,
                            child: Text(deviceId),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedDeviceId = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Pilih Device',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<Map<int, bool>>(
                  stream:
                      widget.firebaseService.relayStateStream(selectedId),
                  builder: (context, snapshot) {
                    final relayState = snapshot.data ?? <int, bool>{};
                    return Column(
                      children: [
                        for (final room in _rooms) ...[
                          _RoomRelayCard(
                            room: room,
                            relayState: relayState,
                            onChanged: (relay, value) {
                              widget.firebaseService
                                  .setRelay(relay, value, selectedId);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
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
