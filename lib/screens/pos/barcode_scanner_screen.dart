import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String code)? onScan;

  const BarcodeScannerScreen({Key? key, this.onScan}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isCooldown = false;

  void _handleBarcode(String code) async {
    if (isCooldown) return;
    setState(() => isCooldown = true);

    // 1. إطلاق صوت تنبيه واهتزاز خفيف عبر النظام الافتراضي
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();

    // 2. إرسال الكود
    if (widget.onScan != null) {
      widget.onScan!(code);
    } else {
      Navigator.pop(context, code);
      return;
    }

    // 3. تأخير بسيط (700ms) لمنع التكرار
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => isCooldown = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المسح المستمر'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _handleBarcode(rawValue);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isCooldown ? Colors.amber : Colors.greenAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
