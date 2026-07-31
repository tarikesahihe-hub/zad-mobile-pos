import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../models/product.dart';
import '../../providers/pos_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/database_service.dart';
import '../pos/barcode_scanner_screen.dart';

/// Screen for editing an existing invoice: change quantities, remove
/// items, or add new products (typed or scanned — including registering a
/// brand-new product on the fly, just like in the main POS screen).
class InvoiceEditScreen extends StatefulWidget {
  final int saleId;

  const InvoiceEditScreen({super.key, required this.saleId});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  Sale? _originalSale;
  Map<int, int> _originalQuantities = {};
  bool _loading = true;
  bool _saving = false;
  bool _productsMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvoice());
  }

  Future<void> _loadInvoice() async {
    final db = DatabaseService();
    final sale = await db.getSaleById(widget.saleId);
    if (sale == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final cartItems = <CartItem>[];
    final originalQuantities = <int, int>{};
    bool missing = false;

    for (final item in sale.items) {
      final product = await db.getProductById(item.productId);
      originalQuantities[item.productId] = item.quantity;
      if (product == null) {
        missing = true;
        continue;
      }
      cartItems.add(CartItem(
        product: product,
        quantity: item.quantity,
        discount: item.discount,
      ));
    }

    if (!mounted) return;
    context.read<PosProvider>().loadSaleForEditing(sale, cartItems);

    setState(() {
      _originalSale = sale;
      _originalQuantities = originalQuantities;
      _productsMissing = missing;
      _loading = false;
    });
  }

  Future<void> _handleScannedCode(String code) async {
    final inventory = context.read<InventoryProvider>();
    final product = await inventory.getProductByBarcode(code);
    if (product != null) {
      context.read<PosProvider>().addToCart(product);
      return;
    }
    if (!mounted) return;
    final newProduct = await _showAddNewProductDialog(code);
    if (newProduct != null) {
      context.read<PosProvider>().addToCart(newProduct);
    }
  }

  Future<Product?> _showAddNewProductDialog(String barcode) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final purchasePriceController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    return showDialog<Product?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('منتج جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الباركود: $barcode', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
              ),
              TextField(
                controller: purchasePriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر الشراء'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر البيع'),
              ),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final now = DateTime.now();
              final product = Product(
                name: nameController.text.trim(),
                barcode: barcode,
                purchasePrice: double.tryParse(purchasePriceController.text) ?? 0,
                salePrice: double.tryParse(priceController.text) ?? 0,
                quantity: int.tryParse(quantityController.text) ?? 1,
                createdAt: now,
                updatedAt: now,
              );
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.addProduct(product);
              if (ok) {
                final saved = await inventory.getProductByBarcode(barcode);
                if (dialogContext.mounted) Navigator.pop(dialogContext, saved);
              } else if (dialogContext.mounted) {
                Navigator.pop(dialogContext, null);
              }
            },
            child: const Text('حفظ وإضافة للفاتورة'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_originalSale == null) return;
    setState(() => _saving = true);
    final ok = await context.read<PosProvider>().updateExistingSale(
          _originalSale!,
          _originalQuantities,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الفاتورة بنجاح')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التعديلات')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('تعديل الفاتورة ${_originalSale?.invoiceNumber ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'إضافة بالمسح',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BarcodeScannerScreen(onScan: _handleScannedCode),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_productsMissing)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'تنبيه: بعض المنتجات فـ هاذي الفاتورة تم حذفها من المخزون ولن تظهر هنا.',
                style: TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: Consumer<PosProvider>(
              builder: (context, pos, child) {
                if (pos.cartItems.isEmpty) {
                  return const Center(child: Text('الفاتورة فارغة'));
                }
                return ListView.builder(
                  itemCount: pos.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = pos.cartItems[index];
                    return ListTile(
                      title: Text(item.product.name),
                      subtitle: Text('${item.unitPrice.toStringAsFixed(2)} د.ج × ${item.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => pos.updateQuantity(item.product.id!, item.quantity - 1),
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => pos.updateQuantity(item.product.id!, item.quantity + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => pos.removeFromCart(item.product.id!),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Consumer<PosProvider>(
            builder: (context, pos, child) => Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي الجديد:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${pos.total.toStringAsFixed(2)} د.ج',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'جارِ الحفظ...' : 'حفظ التعديلات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
