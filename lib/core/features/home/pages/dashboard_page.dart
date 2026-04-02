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
  late final Stream<String> _classificationStream;
  late final Stream<DashboardSnapshot> _dashboardSnapshotStream;

  @override
  void initState() {
    super.initState();
    _classificationStream = widget.firebaseService.classificationStream;
    _dashboardSnapshotStream = widget.firebaseService.dashboardSnapshotStream(
      offlineThreshold: Duration(seconds: widget.onlineThresholdSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<String>(
      stream: _classificationStream,
      builder: (context, classificationSnapshot) {
        final globalStatus = classificationSnapshot.data ?? 'Normal';
        return StreamBuilder<DashboardSnapshot>(
          stream: _dashboardSnapshotStream,
          builder: (context, dashboardSnapshot) {
            final dashboard =
                dashboardSnapshot.data ?? DashboardSnapshot.empty();
            final highRooms = dashboard.highConsumptionRooms;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const SectionTitle(title: 'Status Konsumsi'),
                const SizedBox(height: 12),
                GlobalStatusCard(status: globalStatus),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Konsumsi per Ruangan'),
                const SizedBox(height: 12),
                DeviceClassificationCard(rooms: dashboard.rooms),
                if (highRooms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AlertCard(rooms: highRooms),
                ],
                const SizedBox(height: 24),
                const SectionTitle(title: 'Total Konsumsi Rumah'),
                const SizedBox(height: 12),
                TotalConsumptionCard(
                  totalConsumption: dashboard.totalConsumption,
                ),
                const SizedBox(height: 24),
                const SectionTitle(
                  title: 'Parameter Listrik Real-Time',
                ),
                const SizedBox(height: 12),
                MetricsGrid(data: dashboard.totalConsumption),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Status Koneksi Perangkat'),
                const SizedBox(height: 12),
                DeviceStatusCard(snapshot: dashboard),
              ],
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
