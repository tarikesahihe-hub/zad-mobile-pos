import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';

class SyncProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool _isSyncing = false;
  String _status = 'غير متصل';
  double _progress = 0;
  String? _lastSyncTime;
  int _syncedRecords = 0;
  List<Map<String, dynamic>> _devices = [];

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String get status => _status;
  double get progress => _progress;
  String? get lastSyncTime => _lastSyncTime;
  int get syncedRecords => _syncedRecords;
  List<Map<String, dynamic>> get devices => _devices;

  final CloudSyncService _cloudSync = CloudSyncService();

  SyncProvider() {
    _initConnectivity();
    _loadLastSync();
    _loadSavedCloudConfig();
  }

  Future<void> _loadSavedCloudConfig() async {
    final found = await _cloudSync.loadSavedConfig();
    if (found) {
      _status = 'تم استرجاع إعدادات السحابة';
      notifyListeners();
    }
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((result) {
      _isOnline = result != ConnectivityResult.none;
      _status = _isOnline ? 'متصل' : 'غير متصل';
      notifyListeners();
    });
    Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      _status = _isOnline ? 'متصل' : 'غير متصل';
      notifyListeners();
    });
  }

  Future<void> _loadLastSync() async {
    final db = DatabaseService();
    final lastSync = await db.getSetting('last_sync');
    _lastSyncTime = lastSync;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!_isOnline || _isSyncing) return;

    _isSyncing = true;
    _status = 'جاري المزامنة...';
    _progress = 0;
    notifyListeners();

    final result = await _cloudSync.fullSync();

    _isSyncing = false;
    if (result['success']) {
      _status = 'تمت المزامنة';
      _lastSyncTime = DateTime.now().toIso8601String();
      final upload = result['upload'];
      _syncedRecords = upload['count'] ?? 0;

      final db = DatabaseService();
      await db.setSetting('last_sync', _lastSyncTime!);
    } else {
      _status = result['message'] ?? 'فشل المزامنة';
    }
    _progress = 1;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    _status = _isOnline ? 'متصل' : 'غير متصل';
    notifyListeners();
  }

  Future<void> syncWithDesktop(String ipAddress) async {
    _isSyncing = true;
    _status = 'جاري الربط مع Desktop...';
    notifyListeners();

    // Configure local sync
    _cloudSync.configure('http://$ipAddress');

    final connected = await _cloudSync.testConnection();

    _isSyncing = false;
    if (connected) {
      _status = 'تم الربط مع Desktop';
      await syncNow();
    } else {
      _status = 'فشل الربط مع Desktop';
    }
    notifyListeners();
  }

  Future<void> configureCloudSync(String baseUrl, {String? apiKey, String? storeId}) async {
    _cloudSync.configure(baseUrl, apiKey: apiKey, storeId: storeId);
    final connected = await _cloudSync.testConnection();
    if (connected) {
      await _cloudSync.saveConfig();
      _status = 'متصل بالسحابة';
      notifyListeners();
    } else {
      _status = 'تعذر الاتصال بالخادم';
      notifyListeners();
    }
  }

  Future<void> loadDevices() async {
    final db = DatabaseService();
    _devices = await db.getAllDevices();
    notifyListeners();
  }
}
