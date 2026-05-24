import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import 'pages/account_info_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/relay_control_page.dart';
import 'pages/room_monitoring_page.dart';
import 'widgets/custom_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _onlineThresholdSeconds = 20;

  final FirebaseService _firebaseService = FirebaseService.instance;
  late final PageController _pageController;
  late final List<Widget> _pages;
  int _currentIndex = 0;

  static const List<String> _titles = [
    'Dashboard Monitoring',
    'Monitoring Konsumsi',
    'Kontrol Perangkat',
    'Info Akun',
  ];
  static const List<String> _subtitles = [
    'Ringkasan realtime seluruh ruangan',
    'Detail konsumsi per ruangan',
    'Kelola relay tiap perangkat',
    'Profil dan informasi akun',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _pages = [
      DashboardPage(
        firebaseService: _firebaseService,
        onlineThresholdSeconds: _onlineThresholdSeconds,
      ),
      RoomMonitoringPage(firebaseService: _firebaseService),
      RelayControlPage(firebaseService: _firebaseService),
      const AccountInfoPage(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _AppBarTitle(
          title: _titles[_currentIndex],
          subtitle: _subtitles[_currentIndex],
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavItem(icon: Icons.home_outlined, label: 'Home'),
          BottomNavItem(icon: Icons.monitor_heart_outlined, label: 'Ruangan'),
          BottomNavItem(icon: Icons.toggle_on_outlined, label: 'Kontrol'),
          BottomNavItem(icon: Icons.person_outline, label: 'Akun'),
        ],
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: Color(0xFF0A7A6F),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
