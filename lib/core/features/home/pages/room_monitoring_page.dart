import 'package:flutter/material.dart';

import '../../../models/electrical_data.dart';
import '../../../services/firebase_service.dart';
import '../widgets/home_widgets.dart';

class RoomMonitoringPage extends StatelessWidget {
  const RoomMonitoringPage({super.key, required this.firebaseService});

  final FirebaseService firebaseService;

  final List<_RoomInfo> _rooms = const [
    _RoomInfo(id: 'dapur', name: 'Dapur', icon: Icons.kitchen_outlined),
    _RoomInfo(id: 'kamar_tidur', name: 'Kamar Tidur', icon: Icons.bed_outlined),
    _RoomInfo(id: 'ruang_depan', name: 'Ruang Depan', icon: Icons.chair_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SectionTitle(title: 'Monitoring Konsumsi Tiap Ruangan'),
        const SizedBox(height: 12),
        for (final room in _rooms) ...[
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
              return MetricsGrid(data: data, elevated: false);
            },
          ),
        ],
      ),
    );
  }
}
