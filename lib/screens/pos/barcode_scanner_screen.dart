import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

/// Barcode scanner screen.
///
/// If [onScan] is provided, the scanner works in CONTINUOUS mode: it never
/// closes itself after a successful read. Instead it plays the custom scan
/// tone, vibrates, flashes the scan frame orange, sends the code to
/// [onScan], and keeps scanning.
///
/// Re-scanning the SAME barcode only counts once it has actually left the
/// camera frame and come back into view (edge-triggered), not just after a
/// fixed time delay — so holding the same product in front of the camera
/// will not add it twice.
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
  bool _flashFrame = false;
  String? _errorMessage;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Codes currently visible in the camera frame (this detection cycle).
  Set<String> _codesInFrame = {};
  // Codes that are "armed" to fire again once they leave frame + return.
  final Set<String> _consumedUntilGone = {};

  bool get _isContinuous => widget.onScan != null;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playScanFeedback() async {
    // Real vibration (not just a light tap) so it's felt reliably.
    HapticFeedback.vibrate();
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/scan_beep.m4a'));
    } catch (_) {
      // If the custom tone fails to play for any reason (codec issue on an
      // old device, etc.) fall back to the system click so feedback never
      // silently disappears.
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _flashOk() {
    setState(() {
      _flashFrame = true;
      _errorMessage = null;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _flashFrame = false);
    });
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _errorMessage == message) {
        setState(() => _errorMessage = null);
      }
    });
  }

  void _handleDetect(BarcodeCapture capture) {
    final seenThisFrame = <String>{};

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      seenThisFrame.add(value);

      final wasInFrame = _codesInFrame.contains(value);
      if (wasInFrame) continue; // still being seen, not a new detection

      // New detection this cycle (code just entered frame).
      if (_consumedUntilGone.contains(value)) {
        // Already scanned and hasn't left frame since — ignore.
        continue;
      }

      try {
        if (value.trim().isEmpty) {
          _showError('باركود غير صالح');
          continue;
        }

        _flashOk();
        _playScanFeedback();
        _consumedUntilGone.add(value);

        if (!_isContinuous) {
          Navigator.of(context).pop(value);
          return;
        }
        widget.onScan!(value);
      } catch (e) {
        _showError('تعذر قراءة الباركود، حاول مرة أخرى');
      }
    }

    // Any code no longer detected this cycle is free to fire again next
    // time it appears (i.e. the user pulled it away and brought it back).
    _consumedUntilGone.removeWhere((code) => !seenThisFrame.contains(code));
    _codesInFrame = seenThisFrame;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Always keep an explicit, visible back arrow — including while an
        // error state is showing — so the user is never stuck on this screen.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          // Scan overlay: orange flash on success, red on error.
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _errorMessage != null
                      ? Colors.red
                      : (_flashFrame ? Colors.orange : const Color(0xFF1E88E5)),
                  width: (_flashFrame || _errorMessage != null) ? 6 : 4,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
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
