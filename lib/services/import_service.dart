import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import 'database_service.dart';

class ImportResult {
  final int importedCount;
  final List<String> errors;

  ImportResult({required this.importedCount, required this.errors});
}

/// Bulk product import from Excel (.xlsx) or CSV files.
///
/// Expected columns (header row required, order doesn't matter, Arabic or
/// English header names both accepted):
///   name / اسم المنتج / الاسم        (required)
///   barcode / باركود                  (optional)
///   purchase_price / سعر الشراء       (optional, default 0)
///   sale_price / سعر البيع            (required)
///   quantity / الكمية                 (optional, default 0)
///   category / الفئة / التصنيف        (optional)
///   min_stock / الحد الأدنى           (optional, default 0)
class ImportService {
  static const List<String> _nameHeaders = ['name', 'اسم المنتج', 'الاسم', 'اسم'];
  static const List<String> _barcodeHeaders = ['barcode', 'باركود', 'الباركود'];
  static const List<String> _purchasePriceHeaders = [
    'purchase_price', 'purchase price', 'سعر الشراء', 'سعر شراء'
  ];
  static const List<String> _salePriceHeaders = [
    'sale_price', 'sale price', 'price', 'سعر البيع', 'سعر بيع', 'السعر'
  ];
  static const List<String> _quantityHeaders = ['quantity', 'qty', 'الكمية', 'كمية'];
  static const List<String> _categoryHeaders = ['category', 'الفئة', 'التصنيف', 'فئة'];
  static const List<String> _minStockHeaders = [
    'min_stock', 'min stock', 'الحد الأدنى', 'الحد الادنى'
  ];

  /// Opens a file picker restricted to xlsx/csv, then imports whatever the
  /// user selects. Returns null if the user cancelled the picker.
  Future<ImportResult?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    final lower = path.toLowerCase();
    if (lower.endsWith('.csv')) {
      return _importCsv(File(path));
    }
    return _importXlsx(File(path));
  }

  int? _findColumnIndex(List<String> headerRow, List<String> candidates) {
    for (var i = 0; i < headerRow.length; i++) {
      final normalized = headerRow[i].trim().toLowerCase();
      for (final candidate in candidates) {
        if (normalized == candidate.toLowerCase()) return i;
      }
    }
    return null;
  }

  double _parseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0.0;
    final cleaned = raw.trim().replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  int _parseInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    return int.tryParse(raw.trim()) ?? (double.tryParse(raw.trim())?.round() ?? 0);
  }

  Future<ImportResult> _importRows(List<List<String>> rows) async {
    if (rows.isEmpty) {
      return ImportResult(importedCount: 0, errors: ['الملف فارغ']);
    }

    final header = rows.first;
    final nameIdx = _findColumnIndex(header, _nameHeaders);
    final barcodeIdx = _findColumnIndex(header, _barcodeHeaders);
    final purchaseIdx = _findColumnIndex(header, _purchasePriceHeaders);
    final saleIdx = _findColumnIndex(header, _salePriceHeaders);
    final qtyIdx = _findColumnIndex(header, _quantityHeaders);
    final categoryIdx = _findColumnIndex(header, _categoryHeaders);
    final minStockIdx = _findColumnIndex(header, _minStockHeaders);

    if (nameIdx == null || saleIdx == null) {
      return ImportResult(
        importedCount: 0,
        errors: ['لم يتم العثور على عمود "اسم المنتج" أو "سعر البيع" فـ الملف'],
      );
    }

    final db = DatabaseService();
    int imported = 0;
    final errors = <String>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      String cell(int? idx) => (idx != null && idx < row.length) ? row[idx].trim() : '';

      final name = cell(nameIdx);
      if (name.isEmpty) {
        errors.add('صف ${i + 1}: اسم المنتج فارغ، تم تجاهله');
        continue;
      }

      try {
        final now = DateTime.now();
        final product = Product(
          name: name,
          barcode: cell(barcodeIdx).isEmpty ? null : cell(barcodeIdx),
          purchasePrice: _parseDouble(cell(purchaseIdx)),
          salePrice: _parseDouble(cell(saleIdx)),
          quantity: _parseInt(cell(qtyIdx)),
          category: cell(categoryIdx).isEmpty ? null : cell(categoryIdx),
          minStock: _parseInt(cell(minStockIdx)),
          createdAt: now,
          updatedAt: now,
        );
        await db.insertProduct(product);
        imported++;
      } catch (e) {
        errors.add('صف ${i + 1} ($name): $e');
      }
    }

    return ImportResult(importedCount: imported, errors: errors);
  }

  Future<ImportResult> _importCsv(File file) async {
    final content = await file.readAsString();
    final rawRows = const CsvToListConverter().convert(content, eol: '\n');
    final rows = rawRows
        .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
        .toList();
    return _importRows(rows);
  }

  Future<ImportResult> _importXlsx(File file) async {
    final bytes = await file.readAsBytes();
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return ImportResult(importedCount: 0, errors: ['الملف لا يحتوي على أي ورقة عمل']);
    }
    final sheet = workbook.tables.values.first;
    final rows = <List<String>>[];
    for (final row in sheet.rows) {
      rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
    }
    return _importRows(rows);
  }
}
