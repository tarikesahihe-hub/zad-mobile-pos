import 'package:flutter/material.dart';
import '../../services/license_service.dart';
import '../login_screen.dart';
import 'license_activation_screen.dart';

/// Shown when an annual subscription hasn't reached the server within the
/// grace period. Not a dead end — the user can retry once they have
/// internet, or fall back to entering a different key.
class LicenseLockedScreen extends StatefulWidget {
  const LicenseLockedScreen({super.key});

  @override
  State<LicenseLockedScreen> createState() => _LicenseLockedScreenState();
}

class _LicenseLockedScreenState extends State<LicenseLockedScreen> {
  bool _checking = false;
  String? _message;

  Future<void> _retry() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    await LicenseService().revalidateSubscription();
    final state = await LicenseService().getState();
    if (!mounted) return;
    setState(() => _checking = false);

    if (state == LicenseState.subscriptionActive ||
        state == LicenseState.subscriptionGrace) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => _message = 'مازال التطبيق غير متصل بالسيرفر. تأكد من الإنترنت وحاول مرة أخرى');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'انتهت مهلة التحقق من الاشتراك',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'اشتراكك السنوي يحتاج اتصالاً بالإنترنت للتحقق كل فترة. اتصل بالإنترنت وأعد المحاولة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: const TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checking ? null : _retry,
                  icon: _checking
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E88E5)))
                      : const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
                    );
                  },
                  child: const Text('استعمال مفتاح آخر', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
