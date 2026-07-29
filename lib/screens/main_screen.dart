import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'pos/pos_screen.dart';
import 'inventory/inventory_screen.dart';
import 'customers/customers_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PosScreen(),
    const InventoryScreen(),
    const CustomersScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = [
    'الرئيسية',
    'نقطة البيع',
    'المخزون',
    'العملاء',
    'التقارير',
    'الإعدادات',
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
          _titles.length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            label: _titles[index],
          ),
        ),
      ),
    );
  }
}
