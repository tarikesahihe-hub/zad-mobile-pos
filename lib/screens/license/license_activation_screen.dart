import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/license_service.dart';
import '../login_screen.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _lifetimeKeyController = TextEditingController();
  final _lifetimeManagerController = TextEditingController();
  final _secondaryKeyController = TextEditingController();
  final _secondaryManagerController = TextEditingController();

  String? _deviceCode;
  bool _loading = false;
  String? _error;
  int? _trialDaysLeft;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDeviceCode();
    _loadTrialInfo();
  }

  Future<void> _loadTrialInfo() async {
    final remaining = await LicenseService().trialDaysRemaining();
    if (mounted) setState(() => _trialDaysLeft = remaining);
  }

  Future<void> _loadDeviceCode() async {
    final code = await LicenseService().getDeviceCode();
    if (mounted) setState(() => _deviceCode = code);
  }

  void _handleActivationResult(String? error) {
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التفعيل بنجاح ✅')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      setState(() => _error = error);
    }
  }

  Future<void> _activateLifetime() async {
    if (_lifetimeKeyController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل مفتاح الترخيص أولاً');
      return;
    }
    if (_lifetimeManagerController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم المسؤول عن الجهاز');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final enteredKey = _lifetimeKeyController.text.trim().toUpperCase();
    final managerName = _lifetimeManagerController.text;
    String? error;

    // إذا المفتاح من النوع العام الجديد (بلا رمز جهاز مسبقاً)، نستعمل
    // مسار التفعيل الجديد. وإلا، نرجع للنظام القديم (رمز جهاز مرتبط).
    if (enteredKey.startsWith('ZAD-AND-') || enteredKey.startsWith('ZAD-WIN-')) {
      error = await LicenseService().activateGenericKey(
        enteredKey,
        managerName: managerName,
      );
    } else {
      error = await LicenseService().activateLifetime(
        enteredKey,
        managerName: managerName,
      );
    }
    _handleActivationResult(error);
  }

  Future<void> _activateSecondary() async {
    if (_secondaryKeyController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل المفتاح الثانوي أولاً');
      return;
    }
    if (_secondaryManagerController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم المسؤول عن الجهاز');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await LicenseService().activateSecondary(
      _secondaryKeyController.text,
      managerName: _secondaryManagerController.text,
    );
    _handleActivationResult(error);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lifetimeKeyController.dispose();
    _lifetimeManagerController.dispose();
    _secondaryKeyController.dispose();
    _secondaryManagerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('تفعيل ZAD Mobile POS'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() => _error = null),
          tabs: const [
            Tab(text: 'الجهاز الرئيسي'),
            Tab(text: 'جهاز ثانوي'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_trialDaysLeft != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: _trialDaysLeft! > 0
                  ? Colors.orange.shade50
                  : Colors.red.shade50,
              child: Text(
                _trialDaysLeft! > 0
                    ? 'الأيام المتبقية في النسخة التجريبية: $_trialDaysLeft أيام'
                    : 'انتهت الفترة التجريبية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _trialDaysLeft! > 0
                      ? Colors.orange.shade900
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLifetimeTab(),
                _buildSecondaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCodeBox() {
    return Column(
      children: [
        Text(
          'للتفعيل تواصل معنا: +213670694322',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLifetimeTab() {
    return _buildCard(children: [
      const Icon(Icons.all_inclusive, size: 48, color: Color(0xFF1E88E5)),
      const SizedBox(height: 12),
      const Text(
        'أرسل "رمز الجهاز" هذا للبائع للحصول على مفتاح مدى الحياة، ثم أدخل المفتاح أدناه. لا حاجة للإنترنت بعد التفعيل نهائياً.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87),
      ),
      const SizedBox(height: 16),
      _buildDeviceCodeBox(),
      const SizedBox(height: 16),
      TextField(
        controller: _lifetimeManagerController,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'اسم المسؤول عن الجهاز',
          hintText: 'يظهر صغيراً أسفل كل فاتورة',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _lifetimeKeyController,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'مفتاح الترخيص',
          hintText: 'ZAD-LIFE-XXXX-XXXX-XXXX-XXXX',
          border: OutlineInputBorder(),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _activateLifetime,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : const Text('تفعيل مدى الحياة'),
        ),
      ),
    ]);
  }

  Widget _buildSecondaryTab() {
    return _buildCard(children: [
      const Icon(Icons.devices_other, size: 48, color: Color(0xFF1E88E5)),
      const SizedBox(height: 12),
      const Text(
        'للأجهزة التابعة لنفس المتجر. أرسل "رمز الجهاز" هذا لصاحب الجهاز الرئيسي للحصول على مفتاح ثانوي خاص بهذا الجهاز.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87),
      ),
      const SizedBox(height: 16),
      _buildDeviceCodeBox(),
      const SizedBox(height: 16),
      TextField(
        controller: _secondaryManagerController,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'اسم المسؤول عن الجهاز',
          hintText: 'يظهر صغيراً أسفل كل فاتورة',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _secondaryKeyController,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'المفتاح الثانوي',
          hintText: 'ZAD-SEC-XXXX-XXXX-XXXX-XXXX',
          border: OutlineInputBorder(),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _activateSecondary,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : const Text('تفعيل كجهاز ثانوي'),
        ),
      ),
    ]);
  }
}
