import 'package:flutter/material.dart';

import '../../../models/electrical_data.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
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
  static const List<String> _statusOptions = ['Normal', 'Waspada', 'Boros'];

  bool _testMode = true;
  String _selectedStatus = _statusOptions.first;
  String? _lastTestNotifiedStatus;
  bool _dialogShowing = false;

  Future<void> _handleTestStatusChange(String value) async {
    setState(() {
      _selectedStatus = value;
    });
    if (_testMode) {
      await _notifyTestStatus(value, force: true);
    }
  }

  Future<void> _notifyTestStatus(String status, {bool force = false}) async {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'normal') {
      _lastTestNotifiedStatus = null;
      return;
    }

    if (!force && _lastTestNotifiedStatus == normalized) {
      return;
    }

    _lastTestNotifiedStatus = normalized;
    await _showStatusDialog(status);

    if (normalized == 'boros') {
      await NotificationService.instance.showBorosAlert();
    } else if (normalized == 'waspada') {
      await NotificationService.instance.showWaspadaAlert();
    }
  }

  Future<void> _showStatusDialog(String status) async {
    if (_dialogShowing || !mounted) {
      return;
    }

    _dialogShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _StatusAlertDialog(status: status),
    );
    _dialogShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SectionTitle(title: 'Status Konsumsi'),
        // const SizedBox(height: 12),
        // _TestStatusPanel(
        //   enabled: _testMode,
        //   selectedStatus: _selectedStatus,
        //   onToggle: (value) async {
        //     setState(() {
        //       _testMode = value;
        //       if (!value) {
        //         _lastTestNotifiedStatus = null;
        //       }
        //     });
        //     if (value) {
        //       await _notifyTestStatus(_selectedStatus, force: true);
        //     }
        //   },
        //   onStatusChanged: _handleTestStatusChange,
        // ),
        const SizedBox(height: 12),
        _testMode
            ? KnnStatusCard(status: _selectedStatus)
            : StreamBuilder<String>(
                stream: widget.firebaseService.classificationStream,
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
          stream: widget.firebaseService.electricalDataStream,
          builder: (context, snapshot) {
            final data = snapshot.data ?? ElectricalData.empty();
            return MetricsGrid(data: data);
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Status Koneksi ESP32'),
        const SizedBox(height: 12),
        StreamBuilder<bool>(
          stream: widget.firebaseService.deviceOnlineByLastSeenStream,
          builder: (context, onlineSnapshot) {
            return StreamBuilder<DateTime?>(
              stream: widget.firebaseService.deviceLastSeenStream,
              builder: (context, snapshot) {
                final lastSeen = snapshot.data;
                final isOnline = onlineSnapshot.data ?? false;
                return ConnectionStatusCard(
                  isOnline: isOnline,
                  lastSeen: lastSeen,
                  thresholdSeconds: widget.onlineThresholdSeconds,
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _TestStatusPanel extends StatelessWidget {
  const _TestStatusPanel({
    required this.enabled,
    required this.selectedStatus,
    required this.onToggle,
    required this.onStatusChanged,
  });

  final bool enabled;
  final String selectedStatus;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onStatusChanged;

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
              const Expanded(
                child: Text(
                  'Mode Tes Klasifikasi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeColor: const Color(0xFF0A7A6F),
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              items: _DashboardPageState._statusOptions
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onStatusChanged(value);
                }
              },
              decoration: InputDecoration(
                labelText: 'Pilih status',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusAlertDialog extends StatelessWidget {
  const _StatusAlertDialog({required this.status});

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
    final normalized = status.toLowerCase();
    final isBoros = normalized == 'boros';
    final color = _statusColor(status);

    return Dialog(
      backgroundColor: const Color(0xFF6B7280),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Konsumsi Daya Listrik\nMemasuki Status',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            if (isBoros) ...[
              const SizedBox(height: 16),
              const Text(
                'Rekomendasi Alat\nyang Harus Dimatikan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _RecommendationTile(title: 'Dapur'),
              const SizedBox(height: 8),
              _RecommendationTile(title: 'Kulkas'),
              const SizedBox(height: 8),
              _RecommendationTile(title: 'Rice Cooker'),
              const SizedBox(height: 8),
              _RecommendationTile(title: 'Mesin Cuci'),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.toggle_off_rounded, color: Colors.white),
        ],
      ),
    );
  }
}
