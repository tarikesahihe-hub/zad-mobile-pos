import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import '../../services/database_service.dart';
import '../../services/license_service.dart';

class MultiDeviceSyncScreen extends StatefulWidget {
  const MultiDeviceSyncScreen({super.key});

  @override
  State<MultiDeviceSyncScreen> createState() => _MultiDeviceSyncScreenState();
}

class _MultiDeviceSyncScreenState extends State<MultiDeviceSyncScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _licenseInfo;
  int _deviceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    context.read<SyncProvider>().loadDevices();
  }

  Future<void> _loadData() async {
    final license = await LicenseService().getLicenseInfo();
    final db = DatabaseService();
    final count = await db.getDeviceCount();
    setState(() {
      _licenseInfo = license;
      _deviceCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('مزامنة الأجهزة')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
          await sync.loadDevices();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // License Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified, color: Color(0xFF43A047)),
                          SizedBox(width: 8),
                          Text('معلومات الترخيص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      if (_licenseInfo != null) ...[
                        _InfoRow(label: 'المحل:', value: _licenseInfo!['store_name'] ?? 'غير معروف'),
                        _InfoRow(label: 'معرف المحل:', value: _licenseInfo!['store_id'] ?? 'غير معروف'),
                        _InfoRow(label: 'مفتاح الترخيص:', value: _licenseInfo!['license_key'] ?? 'غير معروف'),
                        _InfoRow(
                          label: 'الأجهزة المسموحة:',
                          value: '${_licenseInfo!['max_devices'] ?? 1}',
                        ),
                        _InfoRow(
                          label: 'الأجهزة المسجلة:',
                          value: '$_deviceCount',
                          valueColor: _deviceCount >= (_licenseInfo!['max_devices'] ?? 1) ? Colors.red : const Color(0xFF43A047),
                        ),
                        if (_licenseInfo!['expires_at'] != null)
                          _InfoRow(
                            label: 'تاريخ الانتهاء:',
                            value: _licenseInfo!['expires_at'].toString().split('T')[0],
                          ),
                      ] else
                        const Text('لم يتم تفعيل الترخيص', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sync Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sync, color: Color(0xFF1E88E5)),
                          SizedBox(width: 8),
                          Text('حالة المزامنة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      _InfoRow(label: 'حالة الاتصال:', value: sync.status),
                      _InfoRow(
                        label: 'آخر مزامنة:',
                        value: sync.lastSyncTime != null
                            ? sync.lastSyncTime!.split('T').join(' ').split('.')[0]
                            : 'لم تتم بعد',
                      ),
                      _InfoRow(label: 'سجلات تمت مزامنتها:', value: '${sync.syncedRecords}'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: sync.isSyncing ? null : () => sync.syncNow(),
                          icon: sync.isSyncing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync),
                          label: Text(sync.isSyncing ? 'جاري المزامنة...' : 'مزامنة الآن'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Devices List
              const Text('الأجهزة المسجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (sync.devices.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('لا توجد أجهزة مسجلة')),
                  ),
                ),
              ...sync.devices.map((device) => Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_android, color: Color(0xFF1E88E5)),
                  title: Text(device['device_name'] ?? 'جهاز غير معروف'),
                  subtitle: Text('آخر مزامنة: ${device['last_sync']?.toString().split('T')[0] ?? 'غير معروف'}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (device['is_active'] == 1 ? const Color(0xFF43A047) : Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      device['is_active'] == 1 ? 'نشط' : 'غير نشط',
                      style: TextStyle(
                        color: device['is_active'] == 1 ? const Color(0xFF43A047) : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
