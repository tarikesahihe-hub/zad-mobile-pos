import 'dart:io'; // حل مشكلة FileSystemEntity و statSync
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/backup_service.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/license_service.dart';
import '../../l10n/app_strings.dart';
import '../license/license_gate_screen.dart';
import '../license/license_activation_screen.dart';
import 'secondary_devices_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<FileSystemEntity> _backups = [];
  bool _creatingBackup = false;
  LicenseState? _licenseState;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadLicenseState();
  }

  Future<void> _loadLicenseState() async {
    final state = await LicenseService().getState();
    if (mounted) setState(() => _licenseState = state);
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
          SnackBar(content: Text(AppStrings.get(context, 'set_backup_success'))),
        );
      }
      await _loadBackups();
    } catch (e) {
      if (mounted) {
        final msg = AppStrings.get(context, 'set_backup_fail').replaceAll('{error}', '$e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
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
        title: Text(AppStrings.get(context, 'set_restore_title')),
        content: Text(AppStrings.get(context, 'set_restore_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.get(context, 'common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.get(context, 'set_restore_action')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await BackupService().restoreBackup(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get(context, 'set_restore_success'))),
      );
    }
  }

  Widget _buildSecondaryDevicesSection() {
    if (_licenseState != LicenseState.lifetimeActive) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ListTile(
        leading: const Icon(Icons.devices_other, color: Color(0xFF1E88E5)),
        title: Text(AppStrings.get(context, 'set_secondary_title')),
        subtitle: Text(AppStrings.get(context, 'set_secondary_subtitle')),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SecondaryDevicesScreen()),
          );
        },
      ),
    );
  }

  Future<void> _openSupportLink() async {
    final uri = Uri.parse('https://www.facebook.com/share/1GGpru9TYh/');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    }
  }

  Widget _buildSupportSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'الدعم التقني: +213670694322',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCurrencySection() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_money, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get(context, 'set_currency_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.get(context, 'set_currency_subtitle'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${AppProvider.currencySymbolFor(appProvider.currencyCode)} — ${AppProvider.currencyNameFor(appProvider.currencyCode)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCurrencyPickerDialog(context, appProvider),
                    icon: const Icon(Icons.currency_exchange),
                    label: Text(AppStrings.get(context, 'set_currency_title')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCurrencyPickerDialog(BuildContext context, AppProvider appProvider) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchController.text.trim();
          final entries = AppProvider.currencyNames.entries.where((entry) {
            if (query.isEmpty) return true;
            final code = entry.key.toLowerCase();
            final name = entry.value;
            final symbol = AppProvider.currencySymbolFor(entry.key);
            return code.contains(query.toLowerCase()) ||
                name.contains(query) ||
                symbol.contains(query);
          }).toList();

          return AlertDialog(
            title: Text(AppStrings.get(context, 'set_currency_title')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: AppStrings.get(context, 'set_currency_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 350,
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final code = entries[index].key;
                        final name = entries[index].value;
                        final symbol = AppProvider.currencySymbolFor(code);
                        final selected = code == appProvider.currencyCode;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: selected
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade200,
                            child: Text(
                              symbol,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(code),
                          trailing: selected ? const Icon(Icons.check, color: Color(0xFF1E88E5)) : null,
                          onTap: () async {
                            await appProvider.setCurrency(code);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.get(context, 'set_currency_save_success'))),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.get(context, 'common_cancel')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get(context, 'set_business_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.get(context, 'set_business_subtitle'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (appProvider.businessName.isNotEmpty || appProvider.businessType.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${appProvider.businessName.isEmpty ? '-' : appProvider.businessName}'
                        '${appProvider.businessType.isEmpty ? '' : ' • ${appProvider.businessType}'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditBusinessInfoDialog(context, appProvider),
                    icon: const Icon(Icons.edit),
                    label: Text(AppStrings.get(context, 'set_business_title')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditBusinessInfoDialog(BuildContext context, AppProvider appProvider) {
    final nameController = TextEditingController(text: appProvider.businessName);
    final typeController = TextEditingController(text: appProvider.businessType);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.get(context, 'set_business_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: AppStrings.get(context, 'set_business_name_label'),
                  hintText: AppStrings.get(context, 'set_business_name_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: AppStrings.get(context, 'set_business_type_label'),
                  hintText: AppStrings.get(context, 'set_business_type_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get(context, 'common_cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              await appProvider.setBusinessInfo(
                name: nameController.text.trim(),
                type: typeController.text.trim(),
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.get(context, 'set_business_save_success'))),
              );
            },
            child: Text(AppStrings.get(context, 'common_save')),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        if (user == null) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get(context, 'set_account_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.get(context, 'set_current_username_label').replaceAll('{username}', user.username),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangeCredentialsDialog(context),
                    icon: const Icon(Icons.edit),
                    label: Text(AppStrings.get(context, 'set_account_title')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangeCredentialsDialog(BuildContext context) {
    final currentPinController = TextEditingController();
    final newUsernameController = TextEditingController();
    final newPinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.get(context, 'set_account_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPinController,
                  obscureText: true,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: AppStrings.get(context, 'set_current_pin'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newUsernameController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: AppStrings.get(context, 'set_new_username'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: AppStrings.get(context, 'set_new_pin'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get(context, 'common_cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPinController.text.trim().isEmpty) return;
                final result = await context.read<AuthProvider>().updateCredentials(
                      currentPin: currentPinController.text.trim(),
                      newUsername: newUsernameController.text.trim().isEmpty
                          ? null
                          : newUsernameController.text.trim(),
                      newPin: newPinController.text.trim().isEmpty
                          ? null
                          : newPinController.text.trim(),
                    );
                if (!context.mounted) return;
                if (result == 'success') {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.get(context, 'set_update_success'))),
                  );
                } else {
                  final key = result == 'wrong_pin'
                      ? 'set_wrong_pin'
                      : result == 'username_taken'
                          ? 'set_username_taken'
                          : 'set_update_error';
                  setDialogState(() => errorMessage = AppStrings.get(context, key));
                }
              },
              child: Text(AppStrings.get(context, 'set_save_changes')),
            ),
          ],
        ),
      ),
    );
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
                  children: [
                    const Icon(Icons.language, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get(context, 'set_language_label'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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
              children: [
                const Icon(Icons.backup, color: Color(0xFF1E88E5)),
                const SizedBox(width: 8),
                Text(
                  AppStrings.get(context, 'set_backup_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
                label: Text(
                  _creatingBackup
                      ? AppStrings.get(context, 'set_creating_backup')
                      : AppStrings.get(context, 'set_create_backup'),
                ),
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
        title: Text(AppStrings.get(context, 'set_deactivate_title')),
        content: Text(AppStrings.get(context, 'set_deactivate_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.get(context, 'common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppStrings.get(context, 'set_deactivate_confirm'),
              style: const TextStyle(color: Colors.red),
            ),
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
        title: Text(AppStrings.get(context, 'set_license_title')),
        subtitle: Text(AppStrings.get(context, 'set_license_subtitle')),
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
      appBar: AppBar(title: Text(AppStrings.get(context, 'set_title'))),
      body: ListView(
        children: [
          _buildLicenseSection(),
          _buildSecondaryDevicesSection(),
          _buildAccountSection(),
          _buildBusinessInfoSection(),
          _buildCurrencySection(),
          _buildLanguageSection(),
          _buildBackupHeader(),
          _buildSupportSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppStrings.get(context, 'set_saved_backups'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(AppStrings.get(context, 'set_no_backups'))),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _backups.length,
            itemBuilder: (context, index) {
              final backup = _backups[index];
              final fileName = backup.path.split('/').last;
              final stat = backup.statSync();
              final sizeText = AppStrings
                  .get(context, 'set_size_label')
                  .replaceAll('{size}', (stat.size / 1024).toStringAsFixed(2));

              return ListTile(
                title: Text(fileName),
                subtitle: Text(sizeText),
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
