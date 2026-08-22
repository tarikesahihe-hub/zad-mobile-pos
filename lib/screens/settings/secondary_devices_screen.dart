import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/license_service.dart';
import '../../l10n/app_strings.dart';

class SecondaryDevicesScreen extends StatefulWidget {
  const SecondaryDevicesScreen({super.key});

  @override
  State<SecondaryDevicesScreen> createState() => _SecondaryDevicesScreenState();
}

class _SecondaryDevicesScreenState extends State<SecondaryDevicesScreen> {
  List<SecondaryDeviceRecord> _roster = [];
  int _used = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final roster = await LicenseService().getSecondaryDeviceRoster();
    final used = await LicenseService().secondaryDevicesUsed();
    if (!mounted) return;
    setState(() {
      _roster = roster;
      _used = used;
      _loading = false;
    });
  }

  Future<void> _showAddDeviceDialog() async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();
    String? errorText;
    String? generatedKey;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.get(context, 'set_secondary_add_device')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (generatedKey == null) ...[
                  TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: AppStrings.get(context, 'set_secondary_device_code_label'),
                      hintText: 'XXXX-XXXX-XXXX',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: AppStrings.get(context, 'set_secondary_device_label_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ] else ...[
                  Text(
                    AppStrings.get(context, 'set_secondary_generated_key'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      generatedKey!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: generatedKey!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.get(context, 'set_secondary_key_copied'))),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(AppStrings.get(context, 'set_secondary_copy_key')),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get(context, generatedKey == null ? 'common_cancel' : 'common_done')),
            ),
            if (generatedKey == null)
              ElevatedButton(
                onPressed: () async {
                  final code = codeController.text.trim();
                  if (code.isEmpty) {
                    setDialogState(() => errorText = AppStrings.get(context, 'set_secondary_device_code_label'));
                    return;
                  }
                  try {
                    final key = await LicenseService().registerSecondaryDevice(
                      deviceCode: code,
                      label: labelController.text,
                    );
                    setDialogState(() => generatedKey = key);
                    await _load();
                  } catch (e) {
                    setDialogState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: Text(AppStrings.get(context, 'common_confirm')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(SecondaryDeviceRecord device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get(context, 'set_secondary_title')),
        content: Text(AppStrings.get(context, 'set_secondary_remove_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.get(context, 'common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.get(context, 'common_confirm'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LicenseService().removeSecondaryDeviceFromRoster(device.deviceCode);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final seatsFull = _used >= LicenseService.maxSecondaryDevices;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get(context, 'set_secondary_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: seatsFull ? Colors.red.shade50 : const Color(0xFF1E88E5).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: seatsFull ? Colors.red.shade300 : const Color(0xFF1E88E5).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppStrings
                            .get(context, 'set_secondary_seats_used')
                            .replaceAll('{used}', '$_used')
                            .replaceAll('{max}', '${LicenseService.maxSecondaryDevices}'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: seatsFull ? Colors.red.shade700 : const Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.get(context, 'set_secondary_permanent_note'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _roster.isEmpty
                      ? Center(child: Text(AppStrings.get(context, 'set_secondary_no_devices')))
                      : ListView.builder(
                          itemCount: _roster.length,
                          itemBuilder: (context, index) {
                            final device = _roster[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0x1A1E88E5),
                                  child: Icon(Icons.smartphone, color: Color(0xFF1E88E5)),
                                ),
                                title: Text(device.label),
                                subtitle: Text(device.deviceCode),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () => _confirmRemove(device),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: seatsFull
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddDeviceDialog,
              icon: const Icon(Icons.add),
              label: Text(AppStrings.get(context, 'set_secondary_add_device')),
            ),
    );
  }
}
