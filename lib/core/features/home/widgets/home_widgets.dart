import 'package:flutter/material.dart';

import '../../../models/dashboard_snapshot.dart';
import '../../../models/device_connection_summary.dart';
import '../../../models/electrical_data.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }
}

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({
    super.key,
    required this.data,
    this.elevated = true,
    this.showPowerAndEnergy = true,
    this.useAggregateLabels = true,
  });

  final ElectricalData data;
  final bool elevated;
  final bool showPowerAndEnergy;
  final bool useAggregateLabels;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      MetricCard(
        title: useAggregateLabels ? 'Rata-Rata Tegangan' : 'Tegangan',
        value: data.voltage.toStringAsFixed(1),
        unit: 'Volt',
        icon: Icons.electric_bolt,
        elevated: elevated,
      ),
      MetricCard(
        title: useAggregateLabels ? 'Total Arus' : 'Arus',
        value: data.current.toStringAsFixed(2),
        unit: 'Ampere',
        icon: Icons.speed,
        elevated: elevated,
      ),
      if (showPowerAndEnergy) ...[
        MetricCard(
          title: 'Daya',
          value: data.power.toStringAsFixed(1),
          unit: 'Watt',
          icon: Icons.bolt,
          elevated: elevated,
        ),
        MetricCard(
          title: 'Energi',
          value: data.energy.toStringAsFixed(3),
          unit: 'kWh',
          icon: Icons.battery_charging_full,
          elevated: elevated,
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= 640 && metrics.length > 2 ? 4 : 2;
        final aspectRatio = crossAxisCount == 4 ? 1.05 : 1.4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: metrics,
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.elevated = true,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return _DashboardSurfaceCard(
      elevated: elevated,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFF0A7A6F)),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GlobalStatusCard extends StatelessWidget {
  const GlobalStatusCard({
    super.key,
    required this.status,
    this.description = 'Berdasarkan rata-rata konsumsi seluruh perangkat',
  });

  final String status;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tone = _globalStatusTone(status);
    return _DashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: tone.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, color: tone.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Klasifikasi Konsumsi',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tone.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(label: status, color: tone.color),
          ],
        ),
      ),
    );
  }
}

class DeviceClassificationCard extends StatelessWidget {
  const DeviceClassificationCard({super.key, required this.rooms});

  final List<RoomDashboardData> rooms;

  @override
  Widget build(BuildContext context) {
    return _DashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 20,
                  color: Color(0xFF0A7A6F),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Klasifikasi Konsumsi per Ruangan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < rooms.length; index++) ...[
              _ClassificationRow(room: rooms[index]),
              if (index != rooms.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class TotalConsumptionCard extends StatelessWidget {
  const TotalConsumptionCard({
    super.key,
    required this.totalConsumption,
    this.onResetEnergy,
  });

  static const double _plnTariffPerKwh = 1352;

  final ElectricalData totalConsumption;
  final VoidCallback? onResetEnergy;

  @override
  Widget build(BuildContext context) {
    final estimatedCost = totalConsumption.energy * _plnTariffPerKwh;
    return _DashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.home_work_outlined, color: Color(0xFF0A7A6F)),
                SizedBox(width: 8),
                Text(
                  'Total Konsumsi Rumah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 420;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _SummaryMetricTile(
                          title: 'Total Power',
                          value: totalConsumption.power.toStringAsFixed(1),
                          unit: 'Watt',
                          icon: Icons.bolt_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryMetricTile(
                          title: 'Total Energy',
                          value: totalConsumption.energy.toStringAsFixed(3),
                          unit: 'kWh',
                          icon: Icons.query_stats_outlined,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _SummaryMetricTile(
                      title: 'Total Power',
                      value: totalConsumption.power.toStringAsFixed(1),
                      unit: 'Watt',
                      icon: Icons.bolt_outlined,
                    ),
                    const SizedBox(height: 12),
                    _SummaryMetricTile(
                      title: 'Total Energy',
                      value: totalConsumption.energy.toStringAsFixed(3),
                      unit: 'kWh',
                      icon: Icons.query_stats_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 420;
                  final costInfo = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi Biaya Listrik',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatRupiah(estimatedCost),
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${totalConsumption.energy.toStringAsFixed(3)} kWh x Rp1.352/kWh',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  );
                  final resetButton = OutlinedButton.icon(
                    onPressed: onResetEnergy,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset Energi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: costInfo),
                        const SizedBox(width: 12),
                        resetButton,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      costInfo,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: resetButton),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRupiah(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final remaining = rounded.length - index;
    buffer.write(rounded[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp$buffer';
}

class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tone = _connectionTone(snapshot);
    final statusText =
        !snapshot.hasAssignedDevices
            ? 'Belum Ada Device'
            : snapshot.allOnline
            ? 'Semua Online'
            : snapshot.allOffline
            ? 'Semua Offline'
            : '${snapshot.onlineDevices}/${snapshot.rooms.length} Online';

    return _DashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: tone.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tone.icon, color: tone.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Perangkat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tone.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              !snapshot.hasAssignedDevices
                  ? 'Menunggu perangkat Dapur, Kamar, dan Ruang Tengah tersambung.'
                  : snapshot.latestLastSeen == null
                  ? 'Belum ada pembaruan waktu koneksi perangkat.'
                  : 'Terakhir update: ${formatDateTime(snapshot.latestLastSeen!)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < snapshot.rooms.length; index++) ...[
              _DeviceStatusRow(room: snapshot.rooms[index]),
              if (index != snapshot.rooms.length - 1)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.rooms});

  final List<RoomDashboardData> rooms;

  @override
  Widget build(BuildContext context) {
    final roomNames = rooms.map((room) => room.roomName).join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konsumsi tinggi terdeteksi di $roomNames',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Periksa perangkat pada ruangan terkait untuk mencegah lonjakan daya.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KnnStatusCard extends StatelessWidget {
  const KnnStatusCard({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return GlobalStatusCard(status: status);
  }
}

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({
    super.key,
    required this.summary,
    required this.thresholdSeconds,
  });

  final DeviceConnectionSummary summary;
  final int thresholdSeconds;

  @override
  Widget build(BuildContext context) {
    final rooms = [
      RoomDashboardData(
        roomName: 'Dapur',
        deviceName: null,
        deviceId: null,
        monitoring: ElectricalData.empty(),
        classification: ConsumptionLevel.low,
        isOnline: summary.onlineDeviceNames.any(
          (name) => name.toLowerCase().contains('dapur'),
        ),
        lastSeen: summary.latestLastSeen,
        hasAssignedDevice: true,
      ),
      RoomDashboardData(
        roomName: 'Kamar',
        deviceName: null,
        deviceId: null,
        monitoring: ElectricalData.empty(),
        classification: ConsumptionLevel.low,
        isOnline: summary.onlineDeviceNames.any(
          (name) => name.toLowerCase().contains('kamar'),
        ),
        lastSeen: summary.latestLastSeen,
        hasAssignedDevice: true,
      ),
      RoomDashboardData(
        roomName: 'Ruang Tengah',
        deviceName: null,
        deviceId: null,
        monitoring: ElectricalData.empty(),
        classification: ConsumptionLevel.low,
        isOnline: summary.onlineDeviceNames.any(
          (name) => name.toLowerCase().contains('ruang tengah'),
        ),
        lastSeen: summary.latestLastSeen,
        hasAssignedDevice: true,
      ),
    ];

    return DeviceStatusCard(
      snapshot: DashboardSnapshot(
        rooms: rooms,
        totalConsumption: ElectricalData.empty(),
        latestLastSeen: summary.latestLastSeen,
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _DashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0A7A6F).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF0A7A6F), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSurfaceCard extends StatelessWidget {
  const _DashboardSurfaceCard({required this.child, this.elevated = true});

  final Widget child;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: elevated ? Colors.white : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: elevated ? null : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow:
            elevated
                ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ]
                : null,
      ),
      child: child,
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  const _ClassificationRow({required this.room});

  final RoomDashboardData room;

  @override
  Widget build(BuildContext context) {
    final tone = _consumptionTone(room.classification);
    final probability = room.probabilities[room.prediction];
    final label = room.prediction ?? room.classification.label;
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: tone.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(tone.icon, color: tone.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.roomName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              if (probability != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Probabilitas ${(probability * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ),
        _StatusChip(label: label, color: tone.color),
      ],
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0A7A6F).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0A7A6F), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusRow extends StatelessWidget {
  const _DeviceStatusRow({required this.room});

  final RoomDashboardData room;

  @override
  Widget build(BuildContext context) {
    final color =
        room.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final label = room.isOnline ? 'Online' : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(
            room.isOnline ? Icons.wifi : Icons.wifi_off,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              room.deviceName ?? room.roomName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          _StatusChip(label: label, color: color),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

_StatusTone _globalStatusTone(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'boros' || normalized == 'high') {
    return const _StatusTone(
      color: Color(0xFFDC2626),
      icon: Icons.priority_high_rounded,
    );
  }
  if (normalized == 'waspada' || normalized == 'medium') {
    return const _StatusTone(
      color: Color(0xFFF59E0B),
      icon: Icons.remove_rounded,
    );
  }
  return const _StatusTone(color: Color(0xFF16A34A), icon: Icons.check_rounded);
}

_StatusTone _consumptionTone(ConsumptionLevel level) {
  switch (level) {
    case ConsumptionLevel.low:
      return const _StatusTone(
        color: Color(0xFF16A34A),
        icon: Icons.south_east_rounded,
      );
    case ConsumptionLevel.medium:
      return const _StatusTone(
        color: Color(0xFFF59E0B),
        icon: Icons.horizontal_rule_rounded,
      );
    case ConsumptionLevel.high:
      return const _StatusTone(
        color: Color(0xFFDC2626),
        icon: Icons.north_east_rounded,
      );
  }
}

_StatusTone _connectionTone(DashboardSnapshot snapshot) {
  if (!snapshot.hasAssignedDevices) {
    return const _StatusTone(
      color: Color(0xFF6B7280),
      icon: Icons.wifi_tethering_off_rounded,
    );
  }
  if (snapshot.allOnline) {
    return const _StatusTone(
      color: Color(0xFF16A34A),
      icon: Icons.wifi_rounded,
    );
  }
  if (snapshot.allOffline) {
    return const _StatusTone(
      color: Color(0xFFDC2626),
      icon: Icons.wifi_off_rounded,
    );
  }
  return const _StatusTone(
    color: Color(0xFFF59E0B),
    icon: Icons.router_outlined,
  );
}

class _StatusTone {
  const _StatusTone({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

String formatDateTime(DateTime dateTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final date =
      '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)}';
  final time =
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
  return '$date $time';
}
