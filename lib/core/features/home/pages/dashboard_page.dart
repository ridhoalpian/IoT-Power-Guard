import 'package:flutter/material.dart';

import '../../../models/electrical_data.dart';
import '../../../services/firebase_service.dart';
import '../widgets/home_widgets.dart';

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
        const SectionTitle(
          title: 'Dashboard Monitoring Real-Time (Keseluruhan IoT)',
        ),
        const SizedBox(height: 12),
        StreamBuilder<ElectricalData>(
          stream: firebaseService.electricalDataStream,
          builder: (context, snapshot) {
            final data = snapshot.data ?? ElectricalData.empty();
            return MetricsGrid(data: data);
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Status Konsumsi'),
        const SizedBox(height: 12),
        StreamBuilder<String>(
          stream: firebaseService.classificationStream,
          builder: (context, snapshot) {
            final status = snapshot.data ?? 'Normal';
            return KnnStatusCard(status: status);
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Status Koneksi ESP32'),
        const SizedBox(height: 12),
        StreamBuilder<bool>(
          stream: firebaseService.deviceOnlineByLastSeenStream,
          builder: (context, onlineSnapshot) {
            return StreamBuilder<DateTime?>(
              stream: firebaseService.deviceLastSeenStream,
              builder: (context, snapshot) {
                final lastSeen = snapshot.data;
                final isOnline = onlineSnapshot.data ?? false;
                return ConnectionStatusCard(
                  isOnline: isOnline,
                  lastSeen: lastSeen,
                  thresholdSeconds: onlineThresholdSeconds,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
