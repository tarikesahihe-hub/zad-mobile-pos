import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
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

  static const Color _zadBlueDark = Color(0xFF0D47A1);
  static const Color _zadBlue = Color(0xFF1E88E5);
  static const Color _zadBlueLight = Color(0xFF64B5F6);
  static const Color _zadOrange = Color(0xFFFF9800);
  static const Color _zadOrangeDark = Color(0xFFF57C00);

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadLastUsername();
  }

  Future<void> _loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_username');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _usernameController.text = saved);
    }
  }

  Future<void> _saveLastUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_username', username);
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
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();

    if (username.isEmpty || pin.isEmpty) {
      setState(() => _error = 'أدخلي اسم المستخدم ورمز الدخول');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await context.read<AuthProvider>().login(username, pin);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await _saveLastUsername(username);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      setState(() => _error = 'اسم مستخدم أو رمز دخول غير صحيح');
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _error = null);
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'أدخلي اسم المستخدم أولاً باش تستعملي البصمة');
      return;
    }
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'استخدم بصمتك لتسجيل الدخول إلى ZAD POS',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated || !mounted) return;

      final success = await context.read<AuthProvider>().loginWithBiometrics(username);
      if (!mounted) return;

      if (success) {
        await _saveLastUsername(username);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        setState(() => _error = 'المستخدم "$username" غير موجود أو غير نشط');
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_zadBlueDark, _zadBlue, _zadBlueLight],
            stops: [0.0, 0.55, 1.0],
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _zadOrange, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: _zadOrange.withOpacity(0.45),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: _zadBlue, size: 48),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: _zadOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'نظام نقطة البيع الذكي',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
                                cursorColor: _zadBlue,
                                decoration: InputDecoration(
                                  labelText: 'اسم المستخدم',
                                  labelStyle: const TextStyle(color: _zadBlue),
                                  prefixIcon:
                                      const Icon(Icons.person_outline, color: _zadBlue),
                                  filled: true,
                                  fillColor: const Color(0xFFF3F8FE),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: _zadBlue, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _pinController,
                                obscureText: _obscurePin,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.number,
                                cursorColor: _zadBlue,
                                onSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'رمز الدخول',
                                  labelStyle: const TextStyle(color: _zadBlue),
                                  prefixIcon:
                                      const Icon(Icons.lock_outline, color: _zadBlue),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePin
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _zadOrange,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePin = !_obscurePin),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF3F8FE),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: _zadBlue, width: 1.5),
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
                                    backgroundColor: _zadOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 3,
                                    shadowColor: _zadOrangeDark,
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
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _zadBlue.withOpacity(0.08),
                                      border: Border.all(color: _zadOrange, width: 2),
                                    ),
                                    child: const Icon(Icons.fingerprint,
                                        color: _zadBlue, size: 34),
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
