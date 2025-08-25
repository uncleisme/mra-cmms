import 'package:flutter/material.dart';
import 'primary_nav.dart';
import '../../main.dart' show DashboardPage, OrdersPage, LeavesPage, SettingsPage; // reuse existing pages

class HomeShell extends StatefulWidget {
  final int initialIndex;
  final String? ordersFilter;
  const HomeShell({super.key, this.initialIndex = 0, this.ordersFilter});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    // Pages rendered without their own bottom navigation
    final pages = [
      const DashboardPage(showNav: false),
      OrdersPage(showNav: false, initialFilter: widget.ordersFilter),
      const LeavesPage(showNav: false),
      const SettingsPage(showNav: false),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: Text('Orders')),
                    NavigationRailDestination(icon: Icon(Icons.beach_access_outlined), selectedIcon: Icon(Icons.beach_access), label: Text('Leaves')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                  ],
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IconButton(
                      tooltip: 'Profile',
                      icon: const Icon(Icons.person_outline),
                      onPressed: () => Navigator.of(context).pushNamed('/profile'),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: IndexedStack(index: _index, children: pages)),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: PrimaryNavBar(
            currentIndex: _index,
            onSelected: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}
