import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Barcode scanner screen.
///
/// If [onScan] is provided, the scanner works in CONTINUOUS mode: it never
/// closes itself after a successful read. Instead it plays a short beep,
/// flashes the scan frame orange, sends the code to [onScan], and keeps
/// scanning (with a short cooldown to avoid double-reads of the same item).
///
/// If [onScan] is null, it falls back to the old single-shot behavior:
/// the first successful scan pops the screen with the barcode value.
class BarcodeScannerScreen extends StatefulWidget {
  final void Function(String code)? onScan;

  const BarcodeScannerScreen({super.key, this.onScan});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _torchOn = false;
  bool _cooldown = false;
  bool _flashFrame = false;
  String? _lastCode;
  DateTime? _lastScanTime;

  static const _cooldownDuration = Duration(milliseconds: 700);

  bool get _isContinuous => widget.onScan != null;

  void _handleDetect(BarcodeCapture capture) {
    if (_cooldown) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;

      // Extra guard: ignore an identical code scanned again within the
      // cooldown window (handles rapid multi-frame duplicate reads).
      final now = DateTime.now();
      if (_lastCode == value &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!) < _cooldownDuration) {
        continue;
      }

      _lastCode = value;
      _lastScanTime = now;

      // Beep + visual feedback.
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      setState(() => _flashFrame = true);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _flashFrame = false);
      });

      if (!_isContinuous) {
        Navigator.of(context).pop(value);
        return;
      }

      // Continuous mode: notify caller and start cooldown before accepting
      // the next scan, so the same item isn't added twice by mistake.
      widget.onScan!(value);
      setState(() => _cooldown = true);
      Future.delayed(_cooldownDuration, () {
        if (mounted) setState(() => _cooldown = false);
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isContinuous ? 'مسح مستمر للمنتجات' : 'مسح الباركود'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () => setState(() => _torchOn = !_torchOn),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _handleDetect,
          ),
          // Scan overlay with orange flash feedback
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _flashFrame ? Colors.orange : const Color(0xFF1E88E5),
                  width: _flashFrame ? 6 : 4,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _isContinuous
                      ? 'وجّه الكاميرا نحو المنتجات — تُضاف تلقائياً للسلة'
                      : 'وجه الكاميرا نحو الباركود',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (_isContinuous)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check),
                  label: const Text('إنهاء المسح'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
