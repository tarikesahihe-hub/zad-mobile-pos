import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_service.dart';

class ActivationScreen extends StatefulWidget {
  final Widget child;
  const ActivationScreen({super.key, required this.child});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isActivated = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkExistingActivation();
  }

  Future<void> _checkExistingActivation() async {
    String? deviceId = await DeviceService.getDeviceId();
    if (deviceId == null) {
      setState(() { _isLoading = false; });
      return;
    }

    try {
      var query = await FirebaseFirestore.instance
          .collection('licenses')
          .where('deviceId', isEqualTo: deviceId)
          .where('isUsed', isEqualTo: true)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _isActivated = true;
          _isLoading = false;
        });
      } else {
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "خطأ في الاتصال بالخادم";
      });
    }
  }

  Future<void> _activateApp() async {
    String key = _codeController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String? deviceId = await DeviceService.getDeviceId();

    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('licenses').doc(key);
      DocumentSnapshot doc = await docRef.get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = "كود التفعيل غير صحيح";
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['isUsed'] == true && data['deviceId'] != deviceId) {
        setState(() {
          _errorMessage = "هذا الكود مستخدم بالفعل على جهاز آخر!";
          _isLoading = false;
        });
        return;
      }

      await docRef.update({
        'isUsed': true,
        'deviceId': deviceId,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isActivated = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "حدث خطأ أثناء التفعيل";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_isActivated) {
      return widget.child;
    }

    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "تفعيل التطبيق",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "يرجى إدخال كود الترخيص الخاص بك لمتابعة الاستخدام",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: "كود التفعيل",
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _activateApp,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text("تفعيل الآن"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
