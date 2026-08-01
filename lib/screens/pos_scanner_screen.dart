import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CartItem {
  final String barcode;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.barcode,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;
}

class ScanLog {
  final String barcode;
  final String productName;
  final DateTime timestamp;

  ScanLog({
    required this.barcode,
    required this.productName,
    required this.timestamp,
  });
}

class PosCartController extends ChangeNotifier {
  List<CartItem> items = [];
  List<ScanLog> undoHistory = [];

  String invoiceNumber = '';
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;

  // الضبط: ثانية واحدة فقط بين كل مسحة وأخرى (1000 مللي ثانية)
  static const int debounceThresholdMs = 1000;

  PosCartController() {
    createNewInvoice();
  }

  double get totalAmount => items.fold(0, (sum, item) => sum + item.total);
  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  void createNewInvoice() {
    items.clear();
    undoHistory.clear();
    _lastScannedBarcode = null;
    _lastScanTime = null;
    invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    notifyListeners();
  }

  Future<bool> processBarcode(String barcode, Map<String, dynamic>? productFromDb) async {
    final now = DateTime.now();

    // تأخير ثانية واحدة قبل قبول نفس الباركود مرة أخرى
    if (_lastScannedBarcode == barcode && _lastScanTime != null) {
      if (now.difference(_lastScanTime!).inMilliseconds < debounceThresholdMs) {
        return false; 
      }
    }

    _lastScannedBarcode = barcode;
    _lastScanTime = now;

    if (productFromDb == null) {
      _triggerErrorFeedback();
      return false;
    }

    _triggerSuccessFeedback();

    final index = items.indexWhere((item) => item.barcode == barcode);
    if (index != -1) {
      items[index].quantity++;
    } else {
      items.add(CartItem(
        barcode: barcode,
        name: productFromDb['name'],
        price: (productFromDb['price'] as num).toDouble(),
      ));
    }

    undoHistory.add(ScanLog(
      barcode: barcode,
      productName: productFromDb['name'],
      timestamp: now,
    ));
    if (undoHistory.length > 10) {
      undoHistory.removeAt(0);
    }

    notifyListeners();
    return true;
  }

  // التراجع عن آخر مسح
  void undoLastScan() {
    if (undoHistory.isEmpty) return;

    final lastOp = undoHistory.removeLast();
    final index = items.indexWhere((item) => item.barcode == lastOp.barcode);

    if (index != -1) {
      if (items[index].quantity > 1) {
        items[index].quantity--;
      } else {
        items.removeAt(index);
      }
      HapticFeedback.vibrate();
      notifyListeners();
    }
  }

  void updateQuantity(String barcode, int delta) {
    final index = items.indexWhere((item) => item.barcode == barcode);
    if (index != -1) {
      items[index].quantity += delta;
      if (items[index].quantity <= 0) {
        items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeItem(String barcode) {
    items.removeWhere((item) => item.barcode == barcode);
    notifyListeners();
  }

  // تفعيل الصوت والاهتزاز عبر خدمات النظام المباشرة
  void _triggerSuccessFeedback() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();
  }

  void _triggerErrorFeedback() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  }
}

class PosScannerScreen extends StatefulWidget {
  const PosScannerScreen({Key? key}) : super(key: key);

  @override
  State<PosScannerScreen> createState() => _PosScannerScreenState();
}

class _PosScannerScreenState extends State<PosScannerScreen> {
  final PosCartController cartController = PosCartController();
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('الفاتورة: ${cartController.invoiceNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.orangeAccent, size: 28),
                tooltip: 'تراجع عن آخر مسحة',
                onPressed: cartController.undoHistory.isNotEmpty
                    ? () => cartController.undoLastScan()
                    : null,
              ),
              TextButton.icon(
                onPressed: () => cartController.createNewInvoice(),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text('سلة جديدة', style: TextStyle(color: Colors.white)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: cameraController,
                      onDetect: (capture) async {
                        for (final barcode in capture.barcodes) {
                          if (barcode.rawValue != null) {
                            _onBarcodeScanned(barcode.rawValue!);
                          }
                        }
                      },
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '● المسح المستمر (انتظار 1 ثانية)',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Container(
                color: Colors.blueGrey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                      onPressed: cartController.undoHistory.isNotEmpty
                          ? () => cartController.undoLastScan()
                          : null,
                      icon: const Icon(Icons.reply, color: Colors.white),
                      label: Text(
                        'تراجع ↩️ (${cartController.undoHistory.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'العناصر: ${cartController.totalCount} | المجموع: ${cartController.totalAmount.toStringAsFixed(2)} دج',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: cartController.items.length,
                  itemBuilder: (context, index) {
                    final item = cartController.items[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.price} دج × ${item.quantity} = ${item.total} دج'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                            onPressed: () => cartController.updateQuantity(item.barcode, -1),
                          ),
                          Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onPressed: () => cartController.updateQuantity(item.barcode, 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => cartController.removeItem(item.barcode),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                    onPressed: cartController.items.isEmpty
                        ? null
                        : () => _showPaymentConfirmationDialog(),
                    child: const Text('تأكيد وحفظ الفاتورة', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _onBarcodeScanned(String barcode) async {
    Map<String, dynamic>? product = _findProductInDb(barcode);

    bool success = await cartController.processBarcode(barcode, product);

    if (!mounted) return;

    if (!success && product == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠ المنتج غير موجود ($barcode)'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showPaymentConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الفاتورة'),
        content: Text(
          'عدد المنتجات: ${cartController.totalCount}\nإجمالي المبلغ: ${cartController.totalAmount.toStringAsFixed(2)} دج',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              cartController.createNewInvoice();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ تم حفظ الفاتورة بنجاح')),
              );
            },
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findProductInDb(String barcode) {
    return {'name': 'منتج $barcode', 'price': 100.0};
  }
}
