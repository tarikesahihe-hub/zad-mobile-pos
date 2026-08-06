import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _usernameController.text.trim(),
      _pinController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else if (mounted) {
      setState(() => _error = 'اسم مستخدم أو رمز دخول غير صحيح');
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
      appBar: AppBar(title: const Text('تسجيل الدخول - نسخة مبسطة')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'رمز الدخول'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}
