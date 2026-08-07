import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _pinController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _obscurePin = true;
  String? _error;

  static const Color _zadGreen = Color(0xFF0E3B2E);
  static const Color _zadGreenDark = Color(0xFF08221A);
  static const Color _zadGold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() => _biometricAvailable = canCheck && isSupported);
      }
    } catch (_) {
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    const success = true;

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      setState(() => _error = 'اسم مستخدم أو رمز دخول غير صحيح');
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _error = null);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'استخدم بصمتك لتسجيل الدخول إلى ZAD POS',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (authenticated && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر التحقق بالبصمة، حاول مجدداً');
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_zadGreenDark, _zadGreen],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _zadGold, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _zadGold.withOpacity(0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: _zadGold, size: 48),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'ZAD Mobile POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'نظام نقطة البيع الذكي',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _usernameController,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  labelText: 'اسم المستخدم',
                                  prefixIcon:
                                      const Icon(Icons.person_outline, color: _zadGreen),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _pinController,
                                obscureText: _obscurePin,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'رمز الدخول',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline, color: _zadGreen),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePin
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePin = !_obscurePin),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _zadGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : const Text(
                                          'دخول',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                ),
                              ),
                              if (_biometricAvailable) ...[
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('أو',
                                          style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12)),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  onTap: _loginWithBiometrics,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _zadGold.withOpacity(0.12),
                                      border: Border.all(color: _zadGold, width: 1.5),
                                    ),
                                    child: const Icon(Icons.fingerprint,
                                        color: _zadGreen, size: 32),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('الدخول بالبصمة',
                                    style: TextStyle(
                                        color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
