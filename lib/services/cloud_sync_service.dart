import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  String? _baseUrl;
  String? _apiKey;
  String? _storeId;

  void configure(String baseUrl, {String? apiKey, String? storeId}) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _apiKey = apiKey;
    _storeId = storeId;
  }

  bool get isConfigured => _baseUrl != null;
  String? get baseUrl => _baseUrl;

  /// Persists the current cloud config so it survives app restarts.
  Future<void> saveConfig() async {
    if (_baseUrl == null) return;
    final db = DatabaseService();
    await db.setSetting('cloud_base_url', _baseUrl!);
    await db.setSetting('cloud_api_key', _apiKey ?? '');
    await db.setSetting('cloud_store_id', _storeId ?? '');
  }

  /// Loads a previously saved cloud config, if any. Returns true if found.
  Future<bool> loadSavedConfig() async {
    final db = DatabaseService();
    final url = await db.getSetting('cloud_base_url');
    if (url == null || url.isEmpty) return false;

    final apiKey = await db.getSetting('cloud_api_key');
    final storeId = await db.getSetting('cloud_store_id');
    configure(
      url,
      apiKey: (apiKey != null && apiKey.isNotEmpty) ? apiKey : null,
      storeId: (storeId != null && storeId.isNotEmpty) ? storeId : null,
    );
    return true;
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<bool> testConnection() async {
    if (_baseUrl == null) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> syncToCloud() async {
    if (!await isOnline() || _baseUrl == null) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت أو لم يتم تكوين الخادم'};
    }

    try {
      final db = DatabaseService();
      final unsyncedSales = await db.getUnsyncedSales();

      if (unsyncedSales.isEmpty) {
        return {'success': true, 'message': 'جميع البيانات متزامنة', 'count': 0};
      }

      final salesData = unsyncedSales.map((s) => s.toMap()).toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/sync/sales'),
        headers: {
          'Content-Type': 'application/json',
          if (_apiKey != null) 'X-API-Key': _apiKey!,
          if (_storeId != null) 'X-Store-ID': _storeId!,
        },
        body: jsonEncode({'sales': salesData}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        for (final sale in unsyncedSales) {
          await db.markSaleSynced(sale.id!);
        }
        return {
          'success': true,
          'message': 'تمت المزامنة بنجاح',
          'count': unsyncedSales.length,
        };
      } else {
        return {
          'success': false,
          'message': 'خطأ في الخادم: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  Future<Map<String, dynamic>> syncFromCloud() async {
    if (!await isOnline() || _baseUrl == null) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/sync/products'),
        headers: {
          if (_apiKey != null) 'X-API-Key': _apiKey!,
          if (_storeId != null) 'X-Store-ID': _storeId!,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'تم استلام البيانات',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'خطأ في الخادم: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  Future<Map<String, dynamic>> fullSync() async {
    final uploadResult = await syncToCloud();
    if (!uploadResult['success']) return uploadResult;

    final downloadResult = await syncFromCloud();
    return {
      'success': uploadResult['success'] && downloadResult['success'],
      'upload': uploadResult,
      'download': downloadResult,
    };
  }
}
