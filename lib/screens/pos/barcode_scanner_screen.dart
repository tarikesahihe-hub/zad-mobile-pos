import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String code) onScan;

  const BarcodeScannerScreen({Key? key, required this.onScan}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isCooldown = false;

  void _handleBarcode(String code) async {
    if (isCooldown) return;
    setState(() => isCooldown = true);

    // تشغيل رنة تنبيه عند المسح الناجح
    try {
      // يمكنك استخدام رابط صوت تنبيه قصير أو ملف محلي إذا متوفر
      await audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {
      // إذا لم يتوفر ملف صوتي محلي، يمكن الاعتماد على النظام
    }

    widget.onScan(code);

    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => isCooldown = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المسح المستمر مع الرنة'),
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
