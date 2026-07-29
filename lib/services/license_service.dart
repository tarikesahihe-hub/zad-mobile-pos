import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class LicenseService {
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

  final DatabaseService _db = DatabaseService();

  // Generate a license key based on store info
  String generateLicenseKey(String storeName, String storeId) {
    final data = '$storeName|$storeId|ZAD2026';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    final hash = digest.toString().substring(0, 16).toUpperCase();

    // Format: XXXX-XXXX-XXXX-XXXX
    return '${hash.substring(0, 4)}-${hash.substring(4, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}';
  }

  Future<bool> activateLicense(String licenseKey, {
    String? storeName,
    String? storeId,
    int maxDevices = 1,
    DateTime? expiresAt,
  }) async {
    // Validate license key format
    final regex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    if (!regex.hasMatch(licenseKey)) return false;

    final actualStoreId = storeId ?? _generateStoreId();
    final expectedKey = generateLicenseKey(storeName ?? 'ZAD Store', actualStoreId);

    // Simple validation - in production, verify against server
    if (licenseKey != expectedKey) {
      // Allow demo mode with any valid format key
      // In production, check against server
    }

    await _db.saveLicense({
      'id': 1,
      'license_key': licenseKey,
      'store_name': storeName ?? 'ZAD Store',
      'store_id': actualStoreId,
      'activated_at': DateTime.now().toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'max_devices': maxDevices,
      'is_active': 1,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('license_key', licenseKey);
    await prefs.setString('store_id', actualStoreId);

    return true;
  }

  Future<bool> validateLicense() async {
    return await _db.isLicenseValid();
  }

  Future<Map<String, dynamic>?> getLicenseInfo() async {
    return await _db.getLicense();
  }

  Future<bool> canAddDevice() async {
    final license = await _db.getLicense();
    if (license == null) return false;

    final maxDevices = license['max_devices'] as int? ?? 1;
    final currentDevices = await _db.getDeviceCount();
    return currentDevices < maxDevices;
  }

  Future<bool> registerDevice(String deviceId, String? deviceName) async {
    if (!await canAddDevice()) return false;

    await _db.insertDevice({
      'device_id': deviceId,
      'device_name': deviceName ?? 'جهاز $deviceId',
      'last_sync': DateTime.now().toIso8601String(),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  String _generateStoreId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 12).toUpperCase();
  }

  Future<void> deactivateLicense() async {
    final db = DatabaseService();
    final license = await db.getLicense();
    if (license != null) {
      license['is_active'] = 0;
      await db.saveLicense(license);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('license_key');
  }
}
