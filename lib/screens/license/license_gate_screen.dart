import 'package:flutter/material.dart';
import '../../services/license_service.dart';
import '../login_screen.dart';
import 'license_activation_screen.dart';
import 'license_locked_screen.dart';

/// Shown right after the splash screen. Fully offline-capable decision:
///   • trial (<=15 days since install)      -> straight into the app
///   • trialExpired / subscriptionExpired    -> activation screen
///   • lifetimeActive                        -> straight in, forever, no network ever
///   • secondaryActive                       -> straight in, forever, no network ever
///   • subscriptionActive / subscriptionGrace-> straight in, silent background re-check
///   • subscriptionLocked                    -> locked screen asking to reconnect
class LicenseGateScreen extends StatefulWidget {
  const LicenseGateScreen({super.key});

  @override
  State<LicenseGateScreen> createState() => _LicenseGateScreenState();
}

class _LicenseGateScreenState extends State<LicenseGateScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final state = await LicenseService().getState();
    if (!mounted) return;

    switch (state) {
      case LicenseState.trial:
      case LicenseState.lifetimeActive:
      case LicenseState.secondaryActive:
      case LicenseState.genericActive:
      case LicenseState.subscriptionActive:
      case LicenseState.subscriptionGrace:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (state == LicenseState.subscriptionActive ||
            state == LicenseState.subscriptionGrace) {
          // Fire-and-forget: never blocks startup either way.
          LicenseService().revalidateSubscription();
        }
        break;

      case LicenseState.subscriptionLocked:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LicenseLockedScreen()),
        );
        break;

      case LicenseState.trialExpired:
      case LicenseState.subscriptionExpired:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E88E5),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}
