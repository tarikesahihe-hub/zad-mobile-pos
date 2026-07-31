import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String code) onScan;

  const BarcodeScannerScreen({Key? key, required this.onScan}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isCooldown = false;

  void _handleBarcode(String code) async {
    if (isCooldown) return;
    setState(() => isCooldown = true);

    // اهتزاز وتأكيد مسح المنتج
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }
    } catch (_) {}

    // إرسال المنتج مباشرة للسلّة دون إغلاق الشاشة
    widget.onScan(code);

    // مهلة نصف ثانية قبل قراءة المنتج التالي لتفادي التكرار المزدوج
    await Future.delayed(const Duration(milliseconds: 600));
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
        title: const Text('المسح المتتالي المستمر'),
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
                if (barcode.rawValue != null) {
                  _handleBarcode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isCooldown ? Colors.amber : Colors.greenAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'مرر المنتجات تباعاً دون توقف...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
