import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';

enum LicenseState {
  trial,               // within the 7-day free trial, fully offline
  trialExpired,       // trial over, nothing activated yet
  lifetimeActive,      // permanently activated offline (HMAC key)
  secondaryActive,     // secondary device activated offline (HMAC key)
  subscriptionActive,  // annual subscription, verified within grace period
  subscriptionGrace,   // subscription active but hasn't reached server in a while — still usable, warns user
  subscriptionLocked,  // subscription grace period exceeded — must connect to renew
  subscriptionExpired, // subscription end date passed
}

class SecondaryDeviceRecord {
  final String deviceCode;
  final String label;
  final DateTime registeredAt;

  SecondaryDeviceRecord({
    required this.deviceCode,
    required this.label,
    required this.registeredAt,
  });

  factory SecondaryDeviceRecord.fromMap(Map<String, dynamic> map) => SecondaryDeviceRecord(
        deviceCode: map['device_code'] as String,
        label: map['label'] as String? ?? '',
        registeredAt: DateTime.tryParse(map['registered_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'device_code': deviceCode,
        'label': label,
        'registered_at': registeredAt.toIso8601String(),
      };
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

  // Maximum number of secondary devices a lifetime license can ever issue.
  // This is a permanent budget — deleting a device from the local roster
  // (for organizational purposes) does NOT free up a seat. This is
  // intentional and matches how the business wants licenses to work.
  static const int maxSecondaryDevices = 4;

  // ⚠️ IMPORTANT: this secret must be IDENTICAL to the one used in the
  // offline key-generator script (tools/generate_lifetime_key.js) that
  // produces lifetime keys for customers. If you change one, change both,
  // or every previously-sold lifetime key stops validating.
  // السر مقسم لأجزاء ومخلوط بترتيب غير متسلسل، باش صعب يتقرا مباشرة من
  // strings الملف المصرف. يتجمع فقط وقت الاستعمال عبر getter أسفله.
  static const List<String> _hmacSecretParts = [
    '8f3K9pQ2mN7vR4xL',
    'ZAD-DZ-2026-',
    '-LIFETIME-SECRET',
  ];
  static String get _hmacSecret =>
      '${_hmacSecretParts[1]}${_hmacSecretParts[0]}${_hmacSecretParts[2]}';

  // ⚠️ Same rule as above but for secondary/dependent device keys — must
  // match tools/generate_secondary_key.js exactly.
  static const List<String> _secondaryHmacSecretParts = [
    '7hT4nQ1xP9mK',
    'ZAD-DZ-2026-SECONDARY-',
    '-DEVICE-SECRET',
  ];
  static String get _secondaryHmacSecret =>
      '${_secondaryHmacSecretParts[1]}${_secondaryHmacSecretParts[0]}${_secondaryHmacSecretParts[2]}';

  static const _kInstallDate = 'zad_install_date';
  static const _kLifetimeActive = 'zad_lifetime_active';
  static const _kSecondaryActive = 'zad_secondary_active';
  static const _kManagerName = 'zad_manager_name';
  static const _kSecondaryDevicesUsed = 'zad_secondary_devices_used';
  static const _kSecondaryDevicesRoster = 'zad_secondary_devices_roster';
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
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        raw = 'windows-${info.deviceId}';
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
  // Manager name (shown small at the bottom of every receipt)
  // ---------------------------------------------------------------------

  Future<String> getManagerName() async {
    return await _storage.read(key: _kManagerName) ?? '';
  }

  Future<void> setManagerName(String name) async {
    await _storage.write(key: _kManagerName, value: name.trim());
  }

  // ---------------------------------------------------------------------
  // Secondary device roster (main/lifetime device only)
  // ---------------------------------------------------------------------
  //
  // Fully offline bookkeeping. The main device keeps a local list of every
  // secondary device it has ever issued a key for, plus a permanent
  // consumption counter capped at [maxSecondaryDevices]. Removing an entry
  // from the roster is for organization only — it does NOT free up a seat,
  // by explicit design.

  Future<int> secondaryDevicesUsed() async {
    final raw = await _storage.read(key: _kSecondaryDevicesUsed);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  int get secondaryDevicesRemaining => maxSecondaryDevices;

  Future<int> secondaryDevicesRemainingCount() async {
    final used = await secondaryDevicesUsed();
    final remaining = maxSecondaryDevices - used;
    return remaining < 0 ? 0 : remaining;
  }

  Future<List<SecondaryDeviceRecord>> getSecondaryDeviceRoster() async {
    final raw = await _storage.read(key: _kSecondaryDevicesRoster);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SecondaryDeviceRecord.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSecondaryDeviceRoster(List<SecondaryDeviceRecord> roster) async {
    final raw = jsonEncode(roster.map((r) => r.toMap()).toList());
    await _storage.write(key: _kSecondaryDevicesRoster, value: raw);
  }

  /// Registers a secondary device's code against the main license and
  /// permanently consumes one seat out of [maxSecondaryDevices]. Returns
  /// the generated ZAD-SEC key to hand to the customer, or an error string
  /// if no seats remain or the device code is already registered.
  Future<String> registerSecondaryDevice({
    required String deviceCode,
    required String label,
  }) async {
    final normalizedCode = deviceCode.trim().toUpperCase();
    final roster = await getSecondaryDeviceRoster();

    final alreadyRegistered = roster.any((r) => r.deviceCode == normalizedCode);
    if (alreadyRegistered) {
      throw Exception('هذا الجهاز مسجل بالفعل');
    }

    final used = await secondaryDevicesUsed();
    if (used >= maxSecondaryDevices) {
      throw Exception('تم استنفاد كل الرخص الثانوية ($maxSecondaryDevices/$maxSecondaryDevices)');
    }

    roster.add(SecondaryDeviceRecord(
      deviceCode: normalizedCode,
      label: label.trim().isEmpty ? 'جهاز ${used + 1}' : label.trim(),
      registeredAt: DateTime.now(),
    ));
    await _saveSecondaryDeviceRoster(roster);
    await _storage.write(key: _kSecondaryDevicesUsed, value: '${used + 1}');

    final expectedSuffix = _expectedSecondarySuffix(normalizedCode);
    return formatSecondaryKey(expectedSuffix);
  }

  /// Removes a device from the visible roster for organizational purposes
  /// only. Does NOT free up a consumed seat.
  Future<void> removeSecondaryDeviceFromRoster(String deviceCode) async {
    final roster = await getSecondaryDeviceRoster();
    roster.removeWhere((r) => r.deviceCode == deviceCode.trim().toUpperCase());
    await _saveSecondaryDeviceRoster(roster);
  }

  // ---------------------------------------------------------------------
  // Trial persistence marker (survives uninstall)
  // ---------------------------------------------------------------------
  //
  // Android wipes an app's private storage on uninstall, so the trial start
  // date stored in FlutterSecureStorage disappears with it — a user could
  // simply reinstall the app to get a fresh 7-day trial. To raise the bar
  // (not a hard guarantee, but non-trivial for a typical user) we also drop
  // a small hidden marker file in shared/public storage, which is NOT tied
  // to the app's private data and survives a normal uninstall/reinstall.
  //
  // A determined user could still find and delete the marker manually, or
  // wipe the whole device. A real guarantee requires a hosted server that
  // remembers the device fingerprint — intentionally out of scope for now.

  Future<Directory?> _sharedMarkerDir() async {
    try {
      const basePath = '/storage/emulated/0/.zad_data';
      final dir = Directory(basePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _markerFile() async {
    final dir = await _sharedMarkerDir();
    if (dir == null) return null;
    return File('${dir.path}/.trial_marker');
  }

  /// Best-effort request for the broad storage permission needed to read
  /// and write the shared marker file. Safe to call repeatedly — does
  /// nothing if already granted or already permanently denied.
  Future<bool> _ensureStoragePermission() async {
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeTrialMarker(String deviceCode, DateTime installDate) async {
    try {
      final granted = await _ensureStoragePermission();
      if (!granted) return;
      final file = await _markerFile();
      if (file == null) return;
      final payload = jsonEncode({
        'device_code': deviceCode,
        'install_date': installDate.toIso8601String(),
      });
      await file.writeAsString(payload, flush: true);
    } catch (_) {
      // Non-fatal — the app still works with the in-app trial date alone.
    }
  }

  Future<DateTime?> _readTrialMarker(String deviceCode) async {
    try {
      final granted = await _ensureStoragePermission();
      if (!granted) return null;
      final file = await _markerFile();
      if (file == null || !await file.exists()) return null;
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (data['device_code'] != deviceCode) return null;
      final dateStr = data['install_date'] as String?;
      if (dateStr == null) return null;
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Trial
  // ---------------------------------------------------------------------

  Future<DateTime> _ensureInstallDate() async {
    final stored = await _storage.read(key: _kInstallDate);
    if (stored != null) return DateTime.parse(stored);

    // Fresh app-private storage (first-ever install OR a reinstall after
    // uninstall). Check the shared marker first — if it exists for this
    // exact device, this is a reinstall and we must resume the original
    // clock instead of starting a brand-new 7-day trial.
    final deviceCode = await getDeviceCode();
    final markerDate = await _readTrialMarker(deviceCode);

    final installDate = markerDate ?? DateTime.now();
    await _storage.write(key: _kInstallDate, value: installDate.toIso8601String());

    // (Re)write the marker so it stays in sync — harmless if it already
    // existed with the same date, and creates it on first-ever install.
    await _writeTrialMarker(deviceCode, installDate);

    return installDate;
  }

  Future<int> trialDaysRemaining() async {
    final installDate = await _ensureInstallDate();
    final elapsed = DateTime.now().difference(installDate).inDays;
    final remaining = trialDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }// ---------------------------------------------------------------------
  // Lifetime activation (main device — fully offline, HMAC-based)
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
  /// [managerName] is stored and shown small at the bottom of every receipt.
  Future<String?> activateLifetime(String enteredKey, {String? managerName}) async {
    try {
      final deviceCode = await getDeviceCode();
      final expectedSuffix = _expectedLifetimeSuffix(deviceCode);
      final expectedKey = formatLifetimeKey(expectedSuffix);

      final normalizedEntered = enteredKey.trim().toUpperCase();

      if (normalizedEntered == expectedKey) {
        await _storage.write(key: _kLifetimeActive, value: 'true');
        if (managerName != null && managerName.trim().isNotEmpty) {
          await setManagerName(managerName);
        }
        return null;
      }
      return 'مفتاح الترخيص غير صحيح لهذا الجهاز. تأكد من إرسال رمز الجهاز الصحيح.';
    } catch (e) {
      return 'خطأ أثناء التفعيل: $e';
    }
  }

  Future<bool> _isLifetimeActive() async {
    return await _storage.read(key: _kLifetimeActive) == 'true';
  }

  // ---------------------------------------------------------------------
  // Secondary device activation (dependent devices — fully offline)
  // ---------------------------------------------------------------------
  //
  // Same HMAC pattern as the main lifetime key, but with a different secret
  // and prefix (ZAD-SEC-...) so secondary keys are generated with
  // tools/generate_secondary_key.js or via registerSecondaryDevice() on the
  // main device, and are distinct from the main key. NOTE: this only
  // activates the app on the secondary device — it does not yet sync data
  // with the main device (that is a separate, larger feature).

  String _expectedSecondarySuffix(String deviceCode) {
    final hmac = Hmac(sha256, utf8.encode(_secondaryHmacSecret));
    final digest = hmac.convert(utf8.encode(deviceCode));
    return digest.toString().substring(0, 16).toUpperCase();
  }

  String formatSecondaryKey(String suffix) {
    final s = suffix.replaceAll('-', '').toUpperCase();
    return 'ZAD-SEC-${s.substring(0, 4)}-${s.substring(4, 8)}-'
        '${s.substring(8, 12)}-${s.substring(12, 16)}';
  }

  /// [managerName] is stored and shown small at the bottom of every receipt.
  Future<String?> activateSecondary(String enteredKey, {String? managerName}) async {
    try {
      final deviceCode = await getDeviceCode();
      final expectedSuffix = _expectedSecondarySuffix(deviceCode);
      final expectedKey = formatSecondaryKey(expectedSuffix);

      final normalizedEntered = enteredKey.trim().toUpperCase();

      if (normalizedEntered == expectedKey) {
        await _storage.write(key: _kSecondaryActive, value: 'true');
        if (managerName != null && managerName.trim().isNotEmpty) {
          await setManagerName(managerName);
        }
        return null;
      }
      return 'مفتاح الترخيص الثانوي غير صحيح لهذا الجهاز. تأكد من إرسال رمز الجهاز الصحيح.';
    } catch (e) {
      return 'خطأ أثناء التفعيل: $e';
    }
  }

  Future<bool> _isSecondaryActive() async {
    return await _storage.read(key: _kSecondaryActive) == 'true';
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

    if (await _isSecondaryActive()) {
      return LicenseState.secondaryActive;
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
    await _storage.delete(key: _kSecondaryActive);
    await _storage.delete(key: _kSubToken);
    await _storage.delete(key: _kSubExpiresAt);
    await _storage.delete(key: _kSubLastVerified);
    // _kInstallDate, _kManagerName, secondary device roster/counter
    // intentionally kept — clearing this license must not reset the
    // permanent secondary-seat budget.
  }
}
