import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
  int _currentIndex = 0;

  static const List<String> _titles = [
    'Dashboard Monitoring',
    'Monitoring Konsumsi',
    'Kontrol Perangkat',
    'Info Akun',
  ];

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
    final pages = [
      DashboardPage(
        firebaseService: _firebaseService,
        onlineThresholdSeconds: _onlineThresholdSeconds,
      ),
      RoomMonitoringPage(firebaseService: _firebaseService),
      RelayControlPage(firebaseService: _firebaseService),
      const AccountInfoPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Ruangan',
          ),
          NavigationDestination(
            icon: Icon(Icons.toggle_on_outlined),
            selectedIcon: Icon(Icons.toggle_on),
            label: 'Kontrol',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.firebaseService,
    required this.onlineThresholdSeconds,
  });

  final FirebaseService firebaseService;
  final int onlineThresholdSeconds;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _SectionTitle(
          title: 'Dashboard Monitoring Real-Time (Keseluruhan IoT)',
        ),
        const SizedBox(height: 12),
        StreamBuilder<ElectricalData>(
          stream: firebaseService.electricalDataStream,
          builder: (context, snapshot) {
            final data = snapshot.data ?? ElectricalData.empty();
            return _MetricsGrid(data: data);
          },
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'Status Konsumsi'),
        const SizedBox(height: 12),
        StreamBuilder<String>(
          stream: firebaseService.classificationStream,
          builder: (context, snapshot) {
            final status = snapshot.data ?? 'Normal';
            return _KnnStatusCard(status: status);
          },
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'Status Koneksi ESP32'),
        const SizedBox(height: 12),
        StreamBuilder<DateTime?>(
          stream: firebaseService.lastSeenStream,
          builder: (context, snapshot) {
            final lastSeen = snapshot.data;
            final now = DateTime.now();
            final isOnline = lastSeen != null &&
                now.difference(lastSeen).inSeconds <= onlineThresholdSeconds;
            return _ConnectionStatusCard(
              isOnline: isOnline,
              lastSeen: lastSeen,
              thresholdSeconds: onlineThresholdSeconds,
            );
          },
        ),
      ],
    );
  }
}

class RoomMonitoringPage extends StatelessWidget {
  RoomMonitoringPage({super.key, required this.firebaseService});

  final FirebaseService firebaseService;

  final List<_RoomInfo> rooms = const [
    _RoomInfo(id: 'dapur', name: 'Dapur', icon: Icons.kitchen_outlined),
    _RoomInfo(id: 'kamar_tidur', name: 'Kamar Tidur', icon: Icons.bed_outlined),
    _RoomInfo(id: 'ruang_depan', name: 'Ruang Depan', icon: Icons.chair_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _SectionTitle(title: 'Monitoring Konsumsi Tiap Ruangan'),
        const SizedBox(height: 12),
        for (final room in rooms) ...[
          _RoomMetricsCard(
            room: room,
            stream: firebaseService.roomDataStream(room.id),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class RelayControlPage extends StatelessWidget {
  RelayControlPage({super.key, required this.firebaseService});

  final FirebaseService firebaseService;

  final List<_RoomRelayConfig> rooms = const [
    _RoomRelayConfig(
      name: 'Dapur',
      icon: Icons.kitchen_outlined,
      devices: [
        _RelayDevice(relayNumber: 1, name: 'Perangkat 1'),
        _RelayDevice(relayNumber: 2, name: 'Perangkat 2'),
        _RelayDevice(relayNumber: 3, name: 'Perangkat 3'),
      ],
    ),
    _RoomRelayConfig(
      name: 'Kamar Tidur',
      icon: Icons.bed_outlined,
      devices: [
        _RelayDevice(relayNumber: 4, name: 'Perangkat 1'),
        _RelayDevice(relayNumber: 5, name: 'Perangkat 2'),
        _RelayDevice(relayNumber: 6, name: 'Perangkat 3'),
      ],
    ),
    _RoomRelayConfig(
      name: 'Ruang Depan',
      icon: Icons.chair_outlined,
      devices: [
        _RelayDevice(relayNumber: 7, name: 'Perangkat 1'),
        _RelayDevice(relayNumber: 8, name: 'Perangkat 2'),
        _RelayDevice(relayNumber: 9, name: 'Perangkat 3'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _SectionTitle(title: 'Kontrol Perangkat Listrik Per Ruangan'),
        const SizedBox(height: 12),
        StreamBuilder<Map<int, bool>>(
          stream: firebaseService.relayStateStream,
          builder: (context, snapshot) {
            final relayState = snapshot.data ?? <int, bool>{};
            return Column(
              children: [
                for (final room in rooms) ...[
                  _RoomRelayCard(
                    room: room,
                    relayState: relayState,
                    onChanged: (relay, value) {
                      firebaseService.setRelay(relay, value);
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
  }
}

class AccountInfoPage extends StatelessWidget {
  const AccountInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Belum tersedia';
    final createdAt = user?.metadata.creationTime;
    final lastSignIn = user?.metadata.lastSignInTime;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _SectionTitle(title: 'Informasi Akun'),
        const SizedBox(height: 12),
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
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A7A6F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF0A7A6F),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengguna IoT Power Guard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: email,
        ),
        const SizedBox(height: 12),
        const _InfoTile(
          icon: Icons.verified_user_outlined,
          label: 'Status',
          value: 'Aktif',
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.calendar_today_outlined,
          label: 'Terdaftar',
          value: createdAt == null ? 'Belum tersedia' : _formatDateTime(createdAt),
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.update_outlined,
          label: 'Login Terakhir',
          value: lastSignIn == null
              ? 'Belum tersedia'
              : _formatDateTime(lastSignIn),
        ),
      ],
    );
  }
}

class _RoomInfo {
  const _RoomInfo({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

class _RoomMetricsCard extends StatelessWidget {
  const _RoomMetricsCard({
    required this.room,
    required this.stream,
  });

  final _RoomInfo room;
  final Stream<ElectricalData> stream;

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
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A7A6F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(room.icon, color: const Color(0xFF0A7A6F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'Realtime',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<ElectricalData>(
            stream: stream,
            builder: (context, snapshot) {
              final data = snapshot.data ?? ElectricalData.empty();
              return _MetricsGrid(data: data, elevated: false);
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
  const _MetricsGrid({required this.data, this.elevated = true});

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
        _MetricCard(
          title: 'Tegangan',
          value: data.voltage.toStringAsFixed(1),
          unit: 'Volt',
          icon: Icons.electric_bolt,
          elevated: elevated,
        ),
        _MetricCard(
          title: 'Arus',
          value: data.current.toStringAsFixed(2),
          unit: 'Ampere',
          icon: Icons.speed,
          elevated: elevated,
        ),
        _MetricCard(
          title: 'Daya',
          value: data.power.toStringAsFixed(1),
          unit: 'Watt',
          icon: Icons.bolt,
          elevated: elevated,
        ),
        _MetricCard(
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
        border:
            elevated ? null : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: elevated
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

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.isOnline,
    required this.lastSeen,
    required this.thresholdSeconds,
  });

  final bool isOnline;
  final DateTime? lastSeen;
  final int thresholdSeconds;

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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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

String _formatDateTime(DateTime dateTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final date =
      '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)}';
  final time =
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
  return '$date $time';
}
