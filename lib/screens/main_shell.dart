import 'package:flutter/material.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/screens/alerts_screen.dart';
import 'package:monu/screens/dashboard_screen.dart';
import 'package:monu/screens/history_screen.dart';
import 'package:monu/screens/info_screen.dart';
import 'package:monu/screens/sensors_screen.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:provider/provider.dart';

/// Kerangka app: 5 tab + menu bawah.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<NavItemData> _items = [
    NavItemData(
      label: 'Ringkasan',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    NavItemData(
      label: 'Sensor',
      icon: Icons.sensors,
      activeIcon: Icons.sensors,
    ),
    NavItemData(
      label: 'Peringatan',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
    ),
    NavItemData(
      label: 'Riwayat',
      icon: Icons.show_chart,
      activeIcon: Icons.show_chart,
    ),
    NavItemData(
      label: 'Info',
      icon: Icons.info_outline,
      activeIcon: Icons.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final int activeAlerts =
        context.select<MonitorProvider, int>((m) => m.activeAlerts.length);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              DashboardScreen(onSeeAlerts: () => setState(() => _index = 2)),
              const SensorsScreen(),
              const AlertsScreen(),
              const HistoryScreen(),
              const InfoScreen(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassNavBar(
              items: _items,
              currentIndex: _index,
              badges: <int, int>{2: activeAlerts},
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}