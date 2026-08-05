import 'dart:io'; // حل مشكلة FileSystemEntity و statSync
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/backup_service.dart';
import '../../providers/app_provider.dart';
import '../../services/license_service.dart';
import '../license/license_gate_screen.dart';
import '../license/license_activation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<FileSystemEntity> _backups = [];
  bool _creatingBackup = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backups = await BackupService().listBackups();
    setState(() {
      _backups = backups;
    });
  }

  Future<void> _createBackup() async {
    setState(() => _creatingBackup = true);
    try {
      await BackupService().createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء نسخة احتياطية بنجاح')),
        );
      }
      await _loadBackups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء النسخة الاحتياطية: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingBackup = false);
    }
  }

  Future<void> _deleteBackup(String path) async {
    await BackupService().deleteBackup(path);
    _loadBackups();
  }

  Future<void> _restoreBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text('سيتم استبدال البيانات الحالية بالبيانات من هذه النسخة. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (confirmed != true) return;
    await BackupService().restoreBackup(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الاستعادة بنجاح')),
      );
    }
  }

  Widget _buildLanguageSection() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final currentLang = appProvider.locale.languageCode;
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.language, color: Color(0xFF1E88E5)),
                    SizedBox(width: 8),
                    Text('اللغة / Langue / Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {currentLang},
                  onSelectionChanged: (selected) {
                    appProvider.setLocale(selected.first);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackupHeader() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.backup, color: Color(0xFF1E88E5)),
                SizedBox(width: 8),
                Text('النسخ الاحتياطي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creatingBackup ? null : _createBackup,
                icon: _creatingBackup
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: Text(_creatingBackup ? 'جارِ الإنشاء...' : 'إنشاء نسخة احتياطية الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivateLicense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء تفعيل الترخيص'),
        content: const Text(
          'هذا للاختبار فقط. سيتم مسح الترخيص المحفوظ على هذا الجهاز '
          'وستحتاج لإعادة التفعيل (أو استئناف فترة التجربة إن كانت لم تنتهِ بعد). '
          'هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم، ألغِ التفعيل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await LicenseService().clearAll();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LicenseGateScreen()),
      (route) => false,
    );
  }

  Widget _buildLicenseSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ListTile(
        leading: const Icon(Icons.verified_user, color: Color(0xFF1E88E5)),
        title: const Text('الترخيص'),
        subtitle: const Text('تفعيل مدى الحياة أو الاشتراك السنوي'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والنسخ الاحتياطي')),
      body: ListView(
        children: [
          _buildLicenseSection(),
          _buildLanguageSection(),
          _buildBackupHeader(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('النسخ الاحتياطية المحفوظة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (_backups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد نسخ احتياطية بعد')),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _backups.length,
            itemBuilder: (context, index) {
              final backup = _backups[index];
              final fileName = backup.path.split('/').last;
              final stat = backup.statSync();

              return ListTile(
                title: Text(fileName),
                subtitle: Text('الحجم: ${(stat.size / 1024).toStringAsFixed(2)} KB'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => BackupService().shareBackup(backup.path),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteBackup(backup.path),
                    ),
                  ],
                ),
                onTap: () => _restoreBackup(backup.path),
              );
            },
          ),
        ],
      ),
    );
  }
}
