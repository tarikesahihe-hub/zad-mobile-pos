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
  late TabController _tabController;
  final _lifetimeKeyController = TextEditingController();
  final _subKeyController = TextEditingController();

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

  Future<void> _activateLifetime() async {
    if (_lifetimeKeyController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل مفتاح الترخيص أولاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await LicenseService().activateLifetime(_lifetimeKeyController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      if (mounted) {
        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('اختبار فارغ')),
                body: const Center(child: Text('نجح الانتقال بلا كراش')),
              ),
            ),
          );
        } catch (e, st) {
          setState(() => _error = 'خطأ في الانتقال: \$e\n\$st');
        }
      }
    } else {
      setState(() => _error = error);
    }
  }

  Future<void> _activateSubscription() async {
    if (_subKeyController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل مفتاح الاشتراك أولاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await LicenseService().activateSubscription(_subKeyController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lifetimeKeyController.dispose();
    _subKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('تفعيل ZAD Mobile POS'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() => _error = null),
          tabs: const [
            Tab(text: 'مدى الحياة (بدون نت)'),
            Tab(text: 'اشتراك سنوي (بالنت)'),
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
                    ? 'الأيام المتبقية في النسخة التجريبية: $_trialDaysLeft'
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
                _buildSubscriptionTab(),
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
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            const Text('رمز الجهاز', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              _deviceCode ?? '...جاري التحميل',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _deviceCode == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _deviceCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رمز الجهاز')),
                      );
                    },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('نسخ الرمز'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
                
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

  Widget _buildSubscriptionTab() {
    return _buildCard(children: [
      const Icon(Icons.cloud_sync, size: 48, color: Color(0xFF1E88E5)),
      const SizedBox(height: 12),
      const Text(
        'يتطلب اتصالاً بالإنترنت عند التفعيل، وتحقق دوري كل بضعة أيام للحفاظ على الاشتراك فعالاً.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _subKeyController,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'مفتاح الاشتراك',
          hintText: 'ZAD-XXXX-XXXX-XXXX-XXXX',
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
          onPressed: _loading ? null : _activateSubscription,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : const Text('تفعيل الاشتراك'),
        ),
      ),
    ]);
  }
}
