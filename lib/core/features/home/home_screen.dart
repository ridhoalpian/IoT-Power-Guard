import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import 'pages/account_info_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/relay_control_page.dart';
import 'pages/room_monitoring_page.dart';

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
