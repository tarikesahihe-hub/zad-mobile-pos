import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final DatabaseService _db = DatabaseService();

  Future<String> createBackup() async {
    final data = await _db.exportAllData();
    final backup = {
      'version': '1.0.0',
      'created_at': DateTime.now().toIso8601String(),
      'app_name': 'ZAD Mobile POS',
      'data': data,
    };

    final jsonString = jsonEncode(backup);
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(directory.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[:\s]'), '-');
    final fileName = 'zad_backup_$timestamp.json';
    final filePath = path.join(backupDir.path, fileName);

    final file = File(filePath);
    await file.writeAsString(jsonString);

    return filePath;
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(directory.path, 'backups'));
    if (!await backupDir.exists()) return [];
    final files = await backupDir.list().toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files.where((f) => f.path.endsWith('.json')).toList();
  }

  Future<void> restoreBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('ملف النسخ الاحتياطي غير موجود');

    final jsonString = await file.readAsString();
    final backup = jsonDecode(jsonString) as Map<String, dynamic>;
    final data = backup['data'] as Map<String, dynamic>;

    final parsedData = <String, List<Map<String, dynamic>>>{ };
    for (final entry in data.entries) {
      parsedData[entry.key] = (entry.value as List).cast<Map<String, dynamic>>();
    }

    await _db.importData(parsedData);
  }

  Future<void> deleteBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> shareBackup(String filePath) async {
    await Share.shareXFiles([XFile(filePath)], text: 'نسخة احتياطية ZAD Mobile POS');
  }

  Future<String> exportToCSV() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(directory.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[:\s]'), '-');
    final filePath = path.join(exportDir.path, 'zad_export_$timestamp.csv');

    // Export sales as CSV
    final db = DatabaseService();
    final sales = await db.getAllSales();
    final buffer = StringBuffer();
    buffer.writeln('رقم الفاتورة,التاريخ,العميل,المجموع,الخصم,الضريبة,الإجمالي,طريقة الدفع,الحالة');

    for (final sale in sales) {
      buffer.writeln(
        '${sale.invoiceNumber},${sale.date},${sale.customerName ?? ''},'
        '${sale.subtotal},${sale.discount},${sale.tax},${sale.total},'
        '${sale.paymentMethod},${sale.status}'
      );
    }

    final file = File(filePath);
    await file.writeAsString(buffer.toString());
    return filePath;
  }
}
