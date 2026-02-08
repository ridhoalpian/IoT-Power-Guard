import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/electrical_data.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _onlineThresholdSeconds = 30;

  final FirebaseService _firebaseService = FirebaseService.instance;
  StreamSubscription<String>? _statusSubscription;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _statusSubscription =
        _firebaseService.classificationStream.listen(_handleStatusUpdate);
  }

  void _handleStatusUpdate(String status) {
    final normalized = status.trim();
    if (_lastStatus != normalized && normalized.toLowerCase() == 'boros') {
      NotificationService.instance.showBorosAlert();
    }
    _lastStatus = normalized;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Monitoring'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _SectionTitle(title: 'Dashboard Monitoring (Real-Time)'),
          const SizedBox(height: 12),
          StreamBuilder<ElectricalData>(
            stream: _firebaseService.electricalDataStream,
            builder: (context, snapshot) {
              final data = snapshot.data ?? ElectricalData.empty();
              return _MetricsGrid(data: data);
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Status KNN'),
          const SizedBox(height: 12),
          StreamBuilder<String>(
            stream: _firebaseService.classificationStream,
            builder: (context, snapshot) {
              final status = snapshot.data ?? 'Normal';
              return _KnnStatusCard(status: status);
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Kontrol Relay'),
          const SizedBox(height: 12),
          StreamBuilder<Map<int, bool>>(
            stream: _firebaseService.relayStateStream,
            builder: (context, snapshot) {
              final relayState = snapshot.data ?? {1: false, 2: false};
              return _RelayControlCard(
                relayState: relayState,
                onChanged: (relay, value) {
                  _firebaseService.setRelay(relay, value);
                },
              );
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Status Koneksi ESP32'),
          const SizedBox(height: 12),
          StreamBuilder<DateTime?>(
            stream: _firebaseService.lastSeenStream,
            builder: (context, snapshot) {
              final lastSeen = snapshot.data;
              final now = DateTime.now();
              final isOnline = lastSeen != null &&
                  now.difference(lastSeen).inSeconds <=
                      _onlineThresholdSeconds;
              return _ConnectionStatusCard(
                isOnline: isOnline,
                lastSeen: lastSeen,
                thresholdSeconds: _onlineThresholdSeconds,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

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

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data});

  final ElectricalData data;

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
        _MetricCard(
          title: 'Tegangan',
          value: data.voltage.toStringAsFixed(1),
          unit: 'Volt',
          icon: Icons.electric_bolt,
        ),
        _MetricCard(
          title: 'Arus',
          value: data.current.toStringAsFixed(2),
          unit: 'Ampere',
          icon: Icons.speed,
        ),
        _MetricCard(
          title: 'Daya',
          value: data.power.toStringAsFixed(1),
          unit: 'Watt',
          icon: Icons.bolt,
        ),
        _MetricCard(
          title: 'Energi',
          value: data.energy.toStringAsFixed(3),
          unit: 'kWh',
          icon: Icons.battery_charging_full,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xFF0A7A6F)),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnnStatusCard extends StatelessWidget {
  const _KnnStatusCard({required this.status});

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
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
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

class _RelayControlCard extends StatelessWidget {
  const _RelayControlCard({
    required this.relayState,
    required this.onChanged,
  });

  final Map<int, bool> relayState;
  final void Function(int relay, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final relays = relayState.keys.toList()..sort();
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
          for (var index = 0; index < relays.length; index++) ...[
            _RelayTile(
              title: 'Relay ${relays[index]}',
              value: relayState[relays[index]] ?? false,
              onChanged: (value) => onChanged(relays[index], value),
            ),
            if (index != relays.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RelayTile extends StatelessWidget {
  const _RelayTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0A7A6F),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.isOnline,
    required this.lastSeen,
    required this.thresholdSeconds,
  });

  final bool isOnline;
  final DateTime? lastSeen;
  final int thresholdSeconds;

  String _formatDateTime(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final date =
        '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)}';
    final time =
        '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final statusText = isOnline ? 'Online' : 'Offline';
    final color =
        isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

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
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Column(
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
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lastSeen == null
                ? 'Belum ada pembaruan dari perangkat.'
                : 'Terakhir update: ${_formatDateTime(lastSeen!)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Perangkat dianggap online jika update < $thresholdSeconds detik.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
