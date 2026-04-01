import 'package:flutter/material.dart';

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
  const MetricsGrid({super.key, required this.data, this.elevated = true});

  final ElectricalData data;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        MetricCard(
          title: 'Tegangan',
          value: data.voltage.toStringAsFixed(1),
          unit: 'Volt',
          icon: Icons.electric_bolt,
          elevated: elevated,
        ),
        MetricCard(
          title: 'Arus',
          value: data.current.toStringAsFixed(2),
          unit: 'Ampere',
          icon: Icons.speed,
          elevated: elevated,
        ),
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
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class KnnStatusCard extends StatelessWidget {
  const KnnStatusCard({super.key, required this.status});

  final String status;

  Color _statusColor(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'boros') {
      return const Color(0xFFDC2626);
    }
    if (normalized == 'waspada') {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
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
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield, color: color),
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
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
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
    final activeDevicesText =
        summary.onlineDeviceNames.isEmpty
            ? 'Tidak ada perangkat aktif.'
            : summary.onlineDeviceNames.join(', ');
    final offlineDevicesText =
        summary.offlineDeviceNames.isEmpty
            ? 'Tidak ada perangkat offline.'
            : summary.offlineDeviceNames.join(', ');
    final statusText =
        !summary.hasDevices
            ? 'Belum Ada Device'
            : summary.allOnline
            ? 'Semua Online'
            : summary.allOffline
            ? 'Semua Offline'
            : '${summary.onlineDevices} Online';
    final color =
        !summary.hasDevices
            ? const Color(0xFF6B7280)
            : summary.allOffline
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A);

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
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  summary.hasDevices && !summary.allOffline
                      ? Icons.wifi
                      : Icons.wifi_off,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Perangkat',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            !summary.hasDevices
                ? 'Belum ada perangkat terdaftar di Firebase.'
                : summary.latestLastSeen == null
                ? 'Belum ada pembaruan dari perangkat.'
                : 'Terakhir update: ${formatDateTime(summary.latestLastSeen!)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Text(
            summary.hasDevices
                ? 'Online: ${summary.onlineDevices} perangkat | Offline: ${summary.offlineDevices} perangkat.'
                : 'Menunggu data perangkat.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (summary.hasDevices) ...[
            const SizedBox(height: 6),
            Text(
              'Aktif: $activeDevicesText',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            if (summary.offlineDeviceNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Offline: $offlineDevicesText',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ],
          const SizedBox(height: 6),
        ],
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
    );
  }
}

String formatDateTime(DateTime dateTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final date =
      '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)}';
  final time =
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
  return '$date $time';
}
