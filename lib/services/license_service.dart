import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum LicenseState {
  trial,               // within the 7-day free trial, fully offline
  trialExpired,       // trial over, nothing activated yet
  lifetimeActive,      // permanently activated offline (HMAC key)
  subscriptionActive,  // annual subscription, verified within grace period
  subscriptionGrace,   // subscription active but hasn't reached server in a while — still usable, warns user
  subscriptionLocked,  // subscription grace period exceeded — must connect to renew
  subscriptionExpired, // subscription end date passed
}

class LicenseService {
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

  final _storage = const FlutterSecureStorage();

  static const int trialDays = 7;
  // Subscription must reach the server at least once every N days, or it
  // locks pending re-connection (this is what makes the annual plan
  // "بالنت" as opposed to the lifetime key which never needs it again).
  static const int subscriptionGraceDays = 14;

  // ⚠️ IMPORTANT: this secret must be IDENTICAL to the one used in the
  // offline key-generator script (tools/generate_lifetime_key.js) that
  // produces lifetime keys for customers. If you change one, change both,
  // or every previously-sold lifetime key stops validating.
  static const String _hmacSecret = 'ZAD-DZ-2026-8f3K9pQ2mN7vR4xL-LIFETIME-SECRET';

  static const _kInstallDate = 'zad_install_date';
  static const _kLifetimeActive = 'zad_lifetime_active';
  static const _kSubToken = 'zad_sub_token';
  static const _kSubExpiresAt = 'zad_sub_expires_at';
  static const _kSubLastVerified = 'zad_sub_last_verified';

  // ---------------------------------------------------------------------
  // Device identity
  // ---------------------------------------------------------------------

  /// Full precision fingerprint — used for subscription (server-side) binding.
  Future<String> getDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String raw;
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        raw = '${info.id}-${info.board}-${info.brand}-${info.device}';
      } else {
        raw = 'unknown-platform';
      }
      return sha256.convert(utf8.encode(raw)).toString();
    } catch (e) {
      return sha256.convert(utf8.encode('fallback-device-error')).toString();
    }
  }

  /// Short, human-typeable code shown to the customer, who sends it to you
  /// so you can generate their lifetime key with the offline script.
  /// Deterministic from the same device info as the full fingerprint.
  Future<String> getDeviceCode() async {
    final fingerprint = await getDeviceFingerprint();
    final short = fingerprint.substring(0, 12).toUpperCase();
    return '${short.substring(0, 4)}-${short.substring(4, 8)}-${short.substring(8, 12)}';
  }

  // ---------------------------------------------------------------------
  // Trial
  // ---------------------------------------------------------------------

  Future<DateTime> _ensureInstallDate() async {
    final stored = await _storage.read(key: _kInstallDate);
    if (stored != null) return DateTime.parse(stored);
    final now = DateTime.now();
    await _storage.write(key: _kInstallDate, value: now.toIso8601String());
    return now;
  }

  Future<int> trialDaysRemaining() async {
    final installDate = await _ensureInstallDate();
    final elapsed = DateTime.now().difference(installDate).inDays;
    final remaining = trialDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  // ---------------------------------------------------------------------
  // Lifetime activation (fully offline, HMAC-based — same pattern as
  // Lumina POS Pro's hardware-fingerprint licensing)
  // ---------------------------------------------------------------------

  String _expectedLifetimeSuffix(String deviceCode) {
    final hmac = Hmac(sha256, utf8.encode(_hmacSecret));
    final digest = hmac.convert(utf8.encode(deviceCode));
    return digest.toString().substring(0, 16).toUpperCase();
  }

  /// Formats the suffix into ZAD-LIFE-XXXX-XXXX-XXXX-XXXX for display /
  /// for you to hand to the customer.
  String formatLifetimeKey(String suffix) {
    final s = suffix.replaceAll('-', '').toUpperCase();
    return 'ZAD-LIFE-${s.substring(0, 4)}-${s.substring(4, 8)}-'
        '${s.substring(8, 12)}-${s.substring(12, 16)}';
  }

  /// Validates and activates a lifetime key entirely offline. No network
  /// call — this is intentional, it's the whole point of this license type.
  Future<String?> activateLifetime(String enteredKey) async {
    final deviceCode = await getDeviceCode();
    final expectedSuffix = _expectedLifetimeSuffix(deviceCode);
    final expectedKey = formatLifetimeKey(expectedSuffix);

    final normalizedEntered = enteredKey.trim().toUpperCase();

    if (normalizedEntered == expectedKey) {
      await _storage.write(key: _kLifetimeActive, value: 'true');
      return null;
    }
    return 'مفتاح الترخيص غير صحيح لهذا الجهاز. تأكد أنك أرسلت رمز الجهاز الصحيح';
  }

  Future<bool> _isLifetimeActive() async {
    return await _storage.read(key: _kLifetimeActive) == 'true';
  }

  // ---------------------------------------------------------------------
  // Annual subscription (requires internet to activate + periodic re-check)
  // ---------------------------------------------------------------------

  /// Contract with backend (routes/licenses.js):
  /// POST /api/licenses/activate
  ///   body: { license_key, device_fingerprint, plan: "annual" }
  ///   200: { success: true, token, expires_at }
  Future<String?> activateSubscription(String licenseKey) async {
    final fingerprint = await getDeviceFingerprint();
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.licenseActivateEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'license_key': licenseKey.trim(),
          'device_fingerprint': fingerprint,
          'plan': 'annual',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        await _storage.write(key: _kSubToken, value: data['token'] as String);
        await _storage.write(
            key: _kSubExpiresAt, value: (data['expires_at'] ?? '') as String);
        await _storage.write(
            key: _kSubLastVerified, value: DateTime.now().toIso8601String());
        return null;
      }
      return (data['message'] as String?) ??
          'مفتاح الاشتراك غير صالح أو مستعمل من قبل';
    } on SocketException {
      return 'تفعيل الاشتراك السنوي يحتاج اتصال بالإنترنت. تأكد من الشبكة وحاول مرة أخرى';
    } catch (e) {
      return 'خطأ غير متوقع أثناء التفعيل: $e';
    }
  }

  /// Silent background re-check. Called opportunistically (app resume) when
  /// there's connectivity. Never blocks startup by itself — grace period
  /// logic in [getState] is what decides whether to lock the app.
  Future<void> revalidateSubscription() async {
    final token = await _storage.read(key: _kSubToken);
    if (token == null) return;
    final fingerprint = await getDeviceFingerprint();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.licenseVerifyEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'device_fingerprint': fingerprint}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['valid'] == true) {
        await _storage.write(
            key: _kSubLastVerified, value: DateTime.now().toIso8601String());
        if (data['expires_at'] != null) {
          await _storage.write(
              key: _kSubExpiresAt, value: data['expires_at'] as String);
        }
      } else {
        // Server explicitly rejected it (revoked, device mismatch, etc.)
        await _storage.delete(key: _kSubToken);
        await _storage.delete(key: _kSubExpiresAt);
        await _storage.delete(key: _kSubLastVerified);
      }
    } catch (_) {
      // No connectivity — leave everything as-is, grace period handles it.
    }
  }

  Future<bool> _hasSubscriptionToken() async {
    return (await _storage.read(key: _kSubToken)) != null;
  }

  // ---------------------------------------------------------------------
  // Overall state — this is what the UI should branch on
  // ---------------------------------------------------------------------

  Future<LicenseState> getState() async {
    if (await _isLifetimeActive()) {
      return LicenseState.lifetimeActive;
    }

    if (await _hasSubscriptionToken()) {
      final expiresAtStr = await _storage.read(key: _kSubExpiresAt);
      final lastVerifiedStr = await _storage.read(key: _kSubLastVerified);

      if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          return LicenseState.subscriptionExpired;
        }
      }

      if (lastVerifiedStr != null) {
        final lastVerified = DateTime.tryParse(lastVerifiedStr);
        if (lastVerified != null) {
          final daysSinceVerified =
              DateTime.now().difference(lastVerified).inDays;
          if (daysSinceVerified > subscriptionGraceDays) {
            return LicenseState.subscriptionLocked;
          }
          if (daysSinceVerified > subscriptionGraceDays - 3) {
            return LicenseState.subscriptionGrace;
          }
        }
      }
      return LicenseState.subscriptionActive;
    }

    final remaining = await trialDaysRemaining();
    return remaining > 0 ? LicenseState.trial : LicenseState.trialExpired;
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _kLifetimeActive);
    await _storage.delete(key: _kSubToken);
    await _storage.delete(key: _kSubExpiresAt);
    await _storage.delete(key: _kSubLastVerified);
    // _kInstallDate intentionally kept — the trial clock should not reset.
  }
}
