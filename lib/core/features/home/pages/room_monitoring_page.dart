import 'package:flutter/material.dart';

import '../../../models/device_profile.dart';
import '../../../models/electrical_data.dart';
import '../../../services/firebase_service.dart';
import '../widgets/home_widgets.dart';

class RoomMonitoringPage extends StatefulWidget {
  const RoomMonitoringPage({super.key, required this.firebaseService});

  final FirebaseService firebaseService;

  @override
  State<RoomMonitoringPage> createState() => _RoomMonitoringPageState();
}

class _RoomMonitoringPageState extends State<RoomMonitoringPage>
    with AutomaticKeepAliveClientMixin<RoomMonitoringPage> {
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
        const SectionTitle(title: 'Monitoring Konsumsi Tiap Ruangan'),
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
                  _DeviceMonitoringCard(
                    deviceId: deviceIds[index],
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

class _IconOption {
  const _IconOption(this.key, this.icon, this.label);

  final String key;
  final IconData icon;
  final String label;
}

class _DeviceMonitoringCard extends StatelessWidget {
  const _DeviceMonitoringCard({
    required this.deviceId,
    required this.firebaseService,
    required this.iconOptions,
    required this.defaultIconKey,
    required this.iconFromKey,
  });

  final String deviceId;
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
                                    color:
                                        option.key == selectedIconKey
                                            ? const Color(
                                              0xFF0A7A6F,
                                            ).withValues(alpha: 0.12)
                                            : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          option.key == selectedIconKey
                                              ? const Color(0xFF0A7A6F)
                                              : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Icon(
                                    option.icon,
                                    color:
                                        option.key == selectedIconKey
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DeviceProfile>(
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
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7A6F).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconFromKey(profile.iconKey),
                      color: const Color(0xFF0A7A6F),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
          const SizedBox(height: 12),
          StreamBuilder<ElectricalData>(
            stream: firebaseService.deviceMonitoringStream(deviceId),
            builder: (context, snapshot) {
              final data = snapshot.data ?? ElectricalData.empty();
              return MetricsGrid(data: data, elevated: false);
            },
          ),
        ],
      ),
    );
  }
}
