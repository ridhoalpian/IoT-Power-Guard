import 'package:flutter/material.dart';

import '../../../models/dashboard_snapshot.dart';
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
  static const List<_RoomOption> _roomOptions = [
    _RoomOption('Kamar', 'bed'),
    _RoomOption('Ruang Tengah', 'weekend'),
    _RoomOption('Dapur', 'kitchen'),
  ];
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
            if (snapshot.hasError) {
              return const RealtimeErrorCard(
                message: 'Gagal memuat daftar device realtime.',
              );
            }

            if (!snapshot.hasData) {
              return const RoomMonitoringLoadingSkeleton();
            }

            final deviceIds = snapshot.data!;

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
                    roomOptions: _roomOptions,
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

class _RoomOption {
  const _RoomOption(this.name, this.iconKey);

  final String name;
  final String iconKey;
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
    required this.roomOptions,
    required this.defaultIconKey,
    required this.iconFromKey,
  });

  final String deviceId;
  final FirebaseService firebaseService;
  final List<_RoomOption> roomOptions;
  final String defaultIconKey;
  final IconData Function(String? key) iconFromKey;

  void _showEditDialog(BuildContext context, DeviceProfile profile) {
    String selectedRoomName =
        roomOptions.any((option) => option.name == profile.name)
            ? profile.name
            : roomOptions.first.name;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Pilih Ruangan',
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
                      DropdownButtonFormField<String>(
                        value: selectedRoomName,
                        items: roomOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.name,
                                child: Row(
                                  children: [
                                    Icon(
                                      iconFromKey(option.iconKey),
                                      size: 20,
                                      color: const Color(0xFF0A7A6F),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(option.name),
                                  ],
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          final room = roomOptions.firstWhere(
                            (option) => option.name == value,
                          );
                          setState(() {
                            selectedRoomName = room.name;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Ruangan',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final selectedRoom = roomOptions.firstWhere(
                              (option) => option.name == selectedRoomName,
                            );
                            firebaseService.setDeviceProfile(
                              deviceId,
                              name: selectedRoomName,
                              iconKey: selectedRoom.iconKey,
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
                ),
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
              if (!snapshot.hasData) {
                return const DeviceHeaderLoadingSkeleton();
              }

              final profile = snapshot.data!;
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
                    onPressed: () => _showEditDialog(context, profile),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<ConsumptionLevel>(
            stream: firebaseService.deviceClassificationStream(deviceId),
            builder: (context, snapshot) {
              final classification = snapshot.data ?? ConsumptionLevel.low;
              return _ClassificationSummary(classification: classification);
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<ElectricalData>(
            stream: firebaseService.deviceMonitoringStream(deviceId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const DeviceMetricsLoadingSkeleton();
              }

              final data = snapshot.data ?? ElectricalData.empty();
              return MetricsGrid(
                data: data,
                elevated: false,
                useAggregateLabels: false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassificationSummary extends StatelessWidget {
  const _ClassificationSummary({required this.classification});

  final ConsumptionLevel classification;

  @override
  Widget build(BuildContext context) {
    final tone = _classificationTone(classification);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(tone.icon, color: tone.color, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Klasifikasi Konsumsi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tone.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              classification.label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tone.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_ClassificationTone _classificationTone(ConsumptionLevel level) {
  switch (level) {
    case ConsumptionLevel.low:
      return const _ClassificationTone(
        color: Color(0xFF16A34A),
        icon: Icons.check_circle_outline,
      );
    case ConsumptionLevel.medium:
      return const _ClassificationTone(
        color: Color(0xFFF59E0B),
        icon: Icons.warning_amber_rounded,
      );
    case ConsumptionLevel.high:
      return const _ClassificationTone(
        color: Color(0xFFDC2626),
        icon: Icons.priority_high_rounded,
      );
  }
}

class _ClassificationTone {
  const _ClassificationTone({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
