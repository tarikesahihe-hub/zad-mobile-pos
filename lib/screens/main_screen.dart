import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'pos/pos_screen.dart';
import 'inventory/inventory_screen.dart';
import 'customers/customers_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import '../l10n/app_strings.dart';
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  Widget _safe(Widget Function() builder, String name) {
    try {
      return builder();
    } catch (e, st) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'خطأ في شاشة $name:\n$e',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  late final List<Widget> _screens = [
    _safe(() => const DashboardScreen(), 'Dashboard'),
    _safe(() => const PosScreen(), 'POS'),
    _safe(() => const InventoryScreen(), 'Inventory'),
    _safe(() => const CustomersScreen(), 'Customers'),
    _safe(() => const ReportsScreen(), 'Reports'),
    _safe(() => const SettingsScreen(), 'Settings'),
  ];

  List<String> _titles(BuildContext context) => [
    AppStrings.get(context, 'nav_home'),
    AppStrings.get(context, 'nav_pos'),
    AppStrings.get(context, 'nav_inventory'),
    AppStrings.get(context, 'nav_customers'),
    AppStrings.get(context, 'nav_reports'),
    AppStrings.get(context, 'nav_settings'),
  ];

  final List<IconData> _icons = [
    Icons.dashboard,
    Icons.point_of_sale,
    Icons.inventory_2,
    Icons.people,
    Icons.bar_chart,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: List.generate(
          _titles(context).length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            label: _titles(context)[index],
          ),
        ),
      ),
    );
  }
}
