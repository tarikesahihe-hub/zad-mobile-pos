import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_constants.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  String _selectedRole = 'seller';
  Map<String, bool> _permissions = {};
  bool _isLoading = true;

  final List<Map<String, String>> _permissionGroups = [
    {'id': 'view_dashboard', 'name': 'عرض لوحة التحكم', 'icon': 'dashboard'},
    {'id': 'view_sales', 'name': 'عرض المبيعات', 'icon': 'receipt'},
    {'id': 'create_sale', 'name': 'إنشاء فاتورة', 'icon': 'add'},
    {'id': 'edit_sale', 'name': 'تعديل فاتورة', 'icon': 'edit'},
    {'id': 'delete_sale', 'name': 'حذف فاتورة', 'icon': 'delete'},
    {'id': 'view_products', 'name': 'عرض المنتجات', 'icon': 'inventory'},
    {'id': 'add_product', 'name': 'إضافة منتج', 'icon': 'add_box'},
    {'id': 'edit_product', 'name': 'تعديل منتج', 'icon': 'edit'},
    {'id': 'delete_product', 'name': 'حذف منتج', 'icon': 'delete'},
    {'id': 'view_inventory', 'name': 'عرض المخزون', 'icon': 'warehouse'},
    {'id': 'edit_stock', 'name': 'تعديل المخزون', 'icon': 'sync'},
    {'id': 'stock_transfer', 'name': 'نقل مخزون', 'icon': 'swap_horiz'},
    {'id': 'stock_count', 'name': 'جرد المخزون', 'icon': 'count'},
    {'id': 'view_customers', 'name': 'عرض العملاء', 'icon': 'people'},
    {'id': 'add_customer', 'name': 'إضافة عميل', 'icon': 'person_add'},
    {'id': 'edit_customer', 'name': 'تعديل عميل', 'icon': 'edit'},
    {'id': 'delete_customer', 'name': 'حذف عميل', 'icon': 'delete'},
    {'id': 'view_suppliers', 'name': 'عرض الموردين', 'icon': 'local_shipping'},
    {'id': 'view_reports', 'name': 'عرض التقارير', 'icon': 'bar_chart'},
    {'id': 'export_reports', 'name': 'تصدير التقارير', 'icon': 'download'},
    {'id': 'view_profit', 'name': 'عرض الأرباح', 'icon': 'trending_up'},
    {'id': 'view_users', 'name': 'عرض المستخدمين', 'icon': 'group'},
    {'id': 'add_user', 'name': 'إضافة مستخدم', 'icon': 'person_add'},
    {'id': 'edit_user', 'name': 'تعديل مستخدم', 'icon': 'edit'},
    {'id': 'delete_user', 'name': 'حذف مستخدم', 'icon': 'delete'},
    {'id': 'manage_permissions', 'name': 'إدارة الصلاحيات', 'icon': 'security'},
    {'id': 'view_settings', 'name': 'عرض الإعدادات', 'icon': 'settings'},
    {'id': 'edit_settings', 'name': 'تعديل الإعدادات', 'icon': 'edit'},
    {'id': 'manage_printer', 'name': 'إدارة الطابعة', 'icon': 'print'},
    {'id': 'manage_backup', 'name': 'النسخ الاحتياطي', 'icon': 'backup'},
    {'id': 'view_license', 'name': 'عرض الترخيص', 'icon': 'verified'},
    {'id': 'manage_license', 'name': 'إدارة الترخيص', 'icon': 'key'},
    {'id': 'sync_data', 'name': 'مزامنة البيانات', 'icon': 'sync'},
    {'id': 'cloud_sync', 'name': 'مزامنة سحابية', 'icon': 'cloud'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final db = DatabaseService();
    final perms = await db.getRolePermissions(_selectedRole);
    setState(() {
      _permissions = {for (var p in _permissionGroups) p['id']!: perms.contains(p['id'])};
      _isLoading = false;
    });
  }

  Future<void> _savePermissions() async {
    final db = DatabaseService();
    for (final entry in _permissions.entries) {
      await db.updateRolePermission(_selectedRole, entry.key, entry.value);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الصلاحيات')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.hasPermission('manage_permissions')) {
      return Scaffold(
        appBar: AppBar(title: const Text('الصلاحيات')),
        body: const Center(child: Text('ليس لديك صلاحية الوصول')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصلاحيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePermissions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Role Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'اختر الدور',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.userRoles.map((role) {
                final index = AppConstants.userRoles.indexOf(role);
                return DropdownMenuItem(
                  value: role,
                  child: Text(AppConstants.userRoleNames[index]),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                    _isLoading = true;
                  });
                  _loadPermissions();
                }
              },
            ),
          ),

          // Permissions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _permissionGroups.length,
                    itemBuilder: (context, index) {
                      final perm = _permissionGroups[index];
                      final isGranted = _permissions[perm['id']] ?? false;
                      return SwitchListTile(
                        title: Text(perm['name']!),
                        subtitle: Text(perm['id']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        value: isGranted,
                        onChanged: (value) {
                          setState(() {
                            _permissions[perm['id']!] = value;
                          });
                        },
                        secondary: Icon(
                          _getIcon(perm['icon']!),
                          color: isGranted ? const Color(0xFF43A047) : Colors.grey,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savePermissions,
        icon: const Icon(Icons.save),
        label: const Text('حفظ'),
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'dashboard': return Icons.dashboard;
      case 'receipt': return Icons.receipt;
      case 'add': return Icons.add;
      case 'edit': return Icons.edit;
      case 'delete': return Icons.delete;
      case 'inventory': return Icons.inventory_2;
      case 'add_box': return Icons.add_box;
      case 'warehouse': return Icons.warehouse;
      case 'sync': return Icons.sync;
      case 'swap_horiz': return Icons.swap_horiz;
      case 'count': return Icons.format_list_numbered;
      case 'people': return Icons.people;
      case 'person_add': return Icons.person_add;
      case 'local_shipping': return Icons.local_shipping;
      case 'bar_chart': return Icons.bar_chart;
      case 'download': return Icons.download;
      case 'trending_up': return Icons.trending_up;
      case 'group': return Icons.group;
      case 'security': return Icons.security;
      case 'settings': return Icons.settings;
      case 'print': return Icons.print;
      case 'backup': return Icons.backup;
      case 'verified': return Icons.verified;
      case 'key': return Icons.key;
      case 'cloud': return Icons.cloud;
      default: return Icons.circle;
    }
  }
}
