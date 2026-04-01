import 'package:flutter/material.dart';

import '../../../models/device_connection_summary.dart';
import '../../../models/electrical_data.dart';
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
  late final Stream<ElectricalData> _electricalDataStream;
  late final Stream<DeviceConnectionSummary> _connectionSummaryStream;

  @override
  void initState() {
    super.initState();
    _classificationStream = widget.firebaseService.classificationStream;
    _electricalDataStream = widget.firebaseService.electricalDataStream;
    _connectionSummaryStream = widget.firebaseService
        .deviceConnectionSummaryStream(
          offlineThreshold: Duration(seconds: widget.onlineThresholdSeconds),
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SectionTitle(title: 'Status Konsumsi'),
        const SizedBox(height: 12),
        StreamBuilder<String>(
          stream: _classificationStream,
          builder: (context, snapshot) {
            final status = snapshot.data ?? 'Normal';
            return KnnStatusCard(status: status);
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle(
          title: 'Dashboard Monitoring Real-Time (Keseluruhan IoT)',
        ),
        const SizedBox(height: 12),
        StreamBuilder<ElectricalData>(
          stream: _electricalDataStream,
          builder: (context, snapshot) {
            final data = snapshot.data ?? ElectricalData.empty();
            return MetricsGrid(data: data);
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Status Koneksi Perangkat'),
        const SizedBox(height: 12),
        StreamBuilder<DeviceConnectionSummary>(
          stream: _connectionSummaryStream,
          builder: (context, snapshot) {
            return ConnectionStatusCard(
              summary: snapshot.data ?? DeviceConnectionSummary.empty(),
              thresholdSeconds: widget.onlineThresholdSeconds,
            );
          },
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
