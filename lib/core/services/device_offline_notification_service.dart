import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/device_connection_summary.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class DeviceOfflineNotificationService with WidgetsBindingObserver {
  DeviceOfflineNotificationService._();

  static final DeviceOfflineNotificationService instance =
      DeviceOfflineNotificationService._();

  StreamSubscription<DeviceConnectionSummary>? _summarySubscription;
  Set<String>? _offlineDeviceNames;
  bool _initialized = false;
  bool _isListening = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    await _startListening();
    _initialized = true;
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _stopListening();
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startListening());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_stopListening());
        break;
    }
  }

  Future<void> _startListening() async {
    if (_isListening) {
      return;
    }

    _summarySubscription = FirebaseService.instance
        .deviceConnectionSummaryStream(
          offlineThreshold: FirebaseService.deviceOfflineThreshold,
        )
        .listen(_handleSummary);
    _isListening = true;
  }

  Future<void> _stopListening() async {
    if (!_isListening) {
      return;
    }

    await _summarySubscription?.cancel();
    _summarySubscription = null;
    _offlineDeviceNames = null;
    _isListening = false;
  }

  Future<void> _handleSummary(DeviceConnectionSummary summary) async {
    final currentOfflineDeviceNames = summary.offlineDeviceNames.toSet();
    final previousOfflineDeviceNames = _offlineDeviceNames;
    _offlineDeviceNames = currentOfflineDeviceNames;

    if (previousOfflineDeviceNames == null) {
      return;
    }

    final newlyOfflineDeviceNames =
        currentOfflineDeviceNames
            .difference(previousOfflineDeviceNames)
            .toList()
          ..sort();
    if (newlyOfflineDeviceNames.isNotEmpty) {
      await NotificationService.instance.showDeviceOfflineAlert(
        newlyOfflineDeviceNames,
      );
      return;
    }

    if (previousOfflineDeviceNames.isNotEmpty &&
        currentOfflineDeviceNames.isEmpty) {
      await NotificationService.instance.clearDeviceOfflineAlert();
    }
  }
}
