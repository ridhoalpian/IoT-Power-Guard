import 'package:flutter/material.dart';

import '../../../models/dashboard_snapshot.dart';
import '../../../services/firebase_service.dart';
import '../widgets/home_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.firebaseService,
    required this.onlineThresholdSeconds,
  });

  final FirebaseService firebaseService;
  final int onlineThresholdSeconds;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin<DashboardPage> {
  late final Stream<DashboardSnapshot> _dashboardSnapshotStream;
  String? _lastHandledClassification;
  bool _isBorosRecommendationOpen = false;

  @override
  void initState() {
    super.initState();
    _dashboardSnapshotStream = widget.firebaseService.dashboardSnapshotStream(
      offlineThreshold: Duration(seconds: widget.onlineThresholdSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<DashboardSnapshot>(
      stream: _dashboardSnapshotStream,
      builder: (context, dashboardSnapshot) {
        if (dashboardSnapshot.hasError) {
          return RealtimeErrorCard(message: 'Gagal memuat data realtime.');
        }

        if (!dashboardSnapshot.hasData) {
          return const DashboardLoadingSkeleton();
        }

        final dashboard = dashboardSnapshot.data!;
        _handleClassificationChange(dashboard);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const SectionTitle(title: 'Status Konsumsi'),
            const SizedBox(height: 12),
            GlobalStatusCard(status: dashboard.globalClassificationLabel),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Konsumsi per Ruangan'),
            const SizedBox(height: 12),
            DeviceClassificationCard(rooms: dashboard.rooms),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Total Konsumsi Rumah'),
            const SizedBox(height: 12),
            TotalConsumptionCard(
              totalConsumption: dashboard.totalConsumption,
              onResetEnergy:
                  dashboard.deviceIds.isNotEmpty || dashboard.hasAssignedDevices
                      ? () => _confirmAndResetEnergy(dashboard)
                      : null,
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Parameter Listrik Real-Time'),
            const SizedBox(height: 12),
            MetricsGrid(
              data: dashboard.totalConsumption,
              showPowerAndEnergy: false,
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Status Koneksi Perangkat'),
            const SizedBox(height: 12),
            DeviceStatusCard(snapshot: dashboard),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndResetEnergy(DashboardSnapshot dashboard) async {
    final deviceIds =
        dashboard.deviceIds.isNotEmpty
            ? dashboard.deviceIds
            : dashboard.rooms
                .map((room) => room.deviceId)
                .whereType<String>()
                .toList(growable: false);
    if (deviceIds.isEmpty) {
      return;
    }

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Energi?'),
          content: const Text(
            'Nilai energy pada perangkat yang terpasang akan diatur menjadi 0. Estimasi biaya ikut kembali dari awal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true || !mounted) {
      return;
    }

    try {
      await widget.firebaseService.resetEnergyConsumption(deviceIds);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Data energy dan estimasi biaya berhasil direset.'),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Gagal reset energy: $error'),
          ),
        );
    }
  }

  void _handleClassificationChange(DashboardSnapshot dashboard) {
    final classification = dashboard.globalClassificationLabel.toLowerCase();
    if (_lastHandledClassification == classification) {
      return;
    }
    _lastHandledClassification = classification;

    if (classification == 'waspada') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showWaspadaPopup();
      });
      return;
    }

    if (classification == 'boros') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isBorosRecommendationOpen) {
          return;
        }
        _showBorosPrompt(dashboard);
      });
    }
  }

  void _showWaspadaPopup() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFF59E0B),
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Klasifikasi WASPADA. Pantau konsumsi listrik selama beberapa menit.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showBorosPrompt(DashboardSnapshot dashboard) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          action: SnackBarAction(
            label: 'Atur',
            textColor: Colors.white,
            onPressed: () {
              if (!mounted || _isBorosRecommendationOpen) {
                return;
              }
              _showBorosRecommendation(dashboard);
            },
          ),
          content: Row(
            children: const [
              Icon(Icons.priority_high_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Klasifikasi BOROS. Atur relay untuk menurunkan beban.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _showBorosRecommendation(DashboardSnapshot dashboard) async {
    final recommendedRooms = _recommendedRooms(dashboard);
    _isBorosRecommendationOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.68,
        maxWidth: 560,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekomendasi Boros',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Matikan relay yang tidak dipakai untuk menurunkan beban.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (recommendedRooms.isEmpty)
                  const _EmptyRecommendationCard()
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var index = 0;
                            index < recommendedRooms.length;
                            index++
                          ) ...[
                            _RecommendedRelayCard(
                              room: recommendedRooms[index],
                              firebaseService: widget.firebaseService,
                            ),
                            if (index != recommendedRooms.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    _isBorosRecommendationOpen = false;
  }

  List<RoomDashboardData> _recommendedRooms(DashboardSnapshot dashboard) {
    final assignedRooms =
        dashboard.rooms.where((room) => room.hasAssignedDevice).toList();
    final highRooms =
        assignedRooms
            .where((room) => room.classification == ConsumptionLevel.high)
            .toList();
    if (highRooms.isNotEmpty) {
      return highRooms;
    }
    assignedRooms.sort(
      (a, b) => b.monitoring.power.compareTo(a.monitoring.power),
    );
    return assignedRooms.take(3).toList(growable: false);
  }

  @override
  bool get wantKeepAlive => true;
}

class _RecommendedRelayCard extends StatelessWidget {
  const _RecommendedRelayCard({
    required this.room,
    required this.firebaseService,
  });

  static const Map<int, String> _defaultRelayLabels = {
    1: 'Perangkat 1',
    2: 'Perangkat 2',
    3: 'Perangkat 3',
  };

  final RoomDashboardData room;
  final FirebaseService firebaseService;

  @override
  Widget build(BuildContext context) {
    final deviceId = room.deviceId;
    if (deviceId == null) {
      return const _EmptyRecommendationCard();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.electrical_services_outlined,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.roomName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '${room.monitoring.power.toStringAsFixed(1)} W',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<Map<int, String>>(
            stream: firebaseService.relayLabelStream(
              deviceId,
              fallbackLabels: _defaultRelayLabels,
            ),
            builder: (context, labelSnapshot) {
              final labels = labelSnapshot.data ?? _defaultRelayLabels;
              return StreamBuilder<Map<int, bool>>(
                stream: firebaseService.relayStateStream(deviceId),
                builder: (context, stateSnapshot) {
                  final states = stateSnapshot.data ?? const <int, bool>{};
                  return Column(
                    children: [
                      for (var relay = 1; relay <= 3; relay++) ...[
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            states[relay] ?? false
                                ? Icons.power_settings_new_rounded
                                : Icons.power_off_rounded,
                            color:
                                states[relay] ?? false
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF6B7280),
                          ),
                          title: Text(
                            labels[relay] ?? 'Perangkat $relay',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Relay $relay'),
                          value: states[relay] ?? false,
                          activeColor: const Color(0xFFDC2626),
                          onChanged: (value) {
                            firebaseService.setRelay(relay, value, deviceId);
                          },
                        ),
                        if (relay != 3) const Divider(height: 1),
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

class _EmptyRecommendationCard extends StatelessWidget {
  const _EmptyRecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        'Belum ada perangkat yang bisa direkomendasikan.',
        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
      ),
    );
  }
}
