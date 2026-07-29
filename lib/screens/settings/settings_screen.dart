import 'dart:io'; // حل مشكلة FileSystemEntity و statSync
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<FileSystemEntity> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backups = await BackupService().getBackupFiles();
    setState(() {
      _backups = backups;
    });
  }

  Future<void> _deleteBackup(String path) async {
    await BackupService().deleteBackup(path);
    _loadBackups();
  }

  Future<void> _restoreBackup(String path) async {
    await BackupService().restoreBackup(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والنسخ الاحتياطي')),
      body: ListView.builder(
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
    );
  }
}
