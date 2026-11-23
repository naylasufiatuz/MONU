import 'package:flutter/material.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/screens/alerts_screen.dart';
import 'package:monu/screens/dashboard_screen.dart';
import 'package:monu/screens/sensors_screen.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:monu/widgets/page_header.dart';
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
              const _ComingSoon(title: 'Riwayat', icon: Icons.show_chart),
              const _ComingSoon(title: 'Informasi', icon: Icons.info_outline),
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

/// Sementara untuk tab yang dibuat di tahap berikutnya.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ForestBackground(
      strong: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(title: title),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, kNavSpace),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 40),
                        const SizedBox(height: 12),
                        Text('Segera hadir', style: AppText.title),
                        const SizedBox(height: 6),
                        Text(
                          'Halaman ini dibuat di tahap berikutnya.',
                          textAlign: TextAlign.center,
                          style: AppText.bodySoft,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}