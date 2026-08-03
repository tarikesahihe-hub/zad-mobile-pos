import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../providers/pos_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../invoices/invoice_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'sale_receipt_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({Key? key}) : super(key: key);

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final AudioPlayer _completionPlayer = AudioPlayer();

  @override
  void dispose() {
    _completionPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSaleCompleteSound() async {
    try {
      await _completionPlayer.stop();
      await _completionPlayer.play(AssetSource('sounds/sale_complete.mp3'));
    } catch (_) {
      // Silent failure — the sale itself already succeeded, don't block on audio.
    }
  }

  Future<void> _confirmClearCart(PosProvider pos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إفراغ السلة'),
        content: Text(
          'السلة تحتوي على ${pos.cartItems.length} منتج بقيمة إجمالية '
          '${pos.total.toStringAsFixed(2)} د.ج.\nهل تريد إفراغها؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إفراغ السلة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      pos.clearCart();
    }
  }
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadProducts();
    });
  }

  void _addToCart(Product product) {
    context.read<PosProvider>().addToCart(product);
  }

  // ---------------------------------------------------------------------
  // Continuous barcode scanning
  // ---------------------------------------------------------------------

  void _openContinuousScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          onScan: (code) => _handleScannedCode(code),
        ),
      ),
    ).then((_) {
      // Refresh product list in case new products were added while scanning.
      if (mounted) context.read<InventoryProvider>().loadProducts();
    });
  }

  Future<void> _handleScannedCode(String code) async {
    final inventory = context.read<InventoryProvider>();
    final product = await inventory.getProductByBarcode(code);

    if (product != null) {
      _addToCart(product);
      return;
    }

    // Unknown barcode: offer to register it as a new product on the fly.
    if (!mounted) return;
    final newProduct = await _showAddNewProductDialog(code);
    if (newProduct != null) {
      _addToCart(newProduct);
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
            child: const Text('حفظ وإضافة للسلة'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Checkout (cash / card / credit)
  // ---------------------------------------------------------------------

  void _showEditCartSheet(PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Consumer<PosProvider>(
          builder: (context, cartPos, _) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('تعديل السلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: cartPos.cartItems.isEmpty
                      ? const Center(child: Text('السلة فارغة'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: cartPos.cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartPos.cartItems[index];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Text('${item.unitPrice.toStringAsFixed(2)} د.ج × ${item.quantity}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () {
                                      if (item.quantity > 1) {
                                        cartPos.updateQuantity(item.product.id!, item.quantity - 1);
                                      } else {
                                        cartPos.removeFromCart(item.product.id!);
                                      }
                                    },
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => cartPos.updateQuantity(item.product.id!, item.quantity + 1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => cartPos.removeFromCart(item.product.id!),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('تم'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: cartPos.cartItems.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context); // إغلاق نافذة التعديل
                                  _showCheckoutDialog();
                                },
                          icon: const Icon(Icons.payments),
                          label: const Text('دفع'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047), // أخضر
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCheckoutDialog() {
    final pos = context.read<PosProvider>();
    String localPaymentMethod = pos.paymentMethod == 'CASH' || pos.paymentMethod.isEmpty
        ? 'cash'
        : pos.paymentMethod.toLowerCase();
    Customer? selectedCustomer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إتمام عملية البيع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الإجمالي: ${pos.total.toStringAsFixed(2)} د.ج'),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cash', label: Text('نقداً')),
                    ButtonSegment(value: 'card', label: Text('بطاقة')),
                    ButtonSegment(value: 'credit', label: Text('بالدين')),
                  ],
                  selected: {localPaymentMethod},
                  onSelectionChanged: (selected) {
                    setDialogState(() => localPaymentMethod = selected.first);
                    pos.setPaymentMethod(localPaymentMethod);
                  },
                ),
                if (localPaymentMethod == 'credit') ...[
                  const SizedBox(height: 12),
                  Consumer<CustomerProvider>(
                    builder: (context, customerProvider, _) {
                      if (customerProvider.customers.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          customerProvider.loadCustomers();
                        });
                      }
                      return DropdownButtonFormField<Customer>(
                        decoration: const InputDecoration(labelText: 'اختر الزبون'),
                        value: selectedCustomer,
                        items: customerProvider.customers
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    '${c.name}${c.balance > 0 ? " (دين: ${c.balance.toStringAsFixed(0)} د.ج)" : ""}',
                                  ),
                                ))
                            .toList(),
                        onChanged: (customer) {
                          setDialogState(() => selectedCustomer = customer);
                          if (customer != null) {
                            pos.setCustomer(customer.id, customer.name);
                          }
                        },
                      );
                    },
                  ),
                  if (selectedCustomer == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'يجب اختيار زبون لتسجيل البيع بالدين',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
                TextField(
                  decoration: const InputDecoration(labelText: 'الخصم'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    pos.setDiscount(double.tryParse(value) ?? 0);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: localPaymentMethod == 'credit' ? 'المبلغ المدفوع الآن (اختياري)' : 'المبلغ المدفوع',
                    hintText: pos.total.toStringAsFixed(2),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    pos.setAmountPaid(double.tryParse(value) ?? 0);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 8),
                if (localPaymentMethod == 'credit')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المتبقي كدين:'),
                      Text(
                        '${pos.remainingDue.toStringAsFixed(2)} د.ج',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الباقي للزبون:'),
                      Text(
                        '${pos.changeDue.toStringAsFixed(2)} د.ج',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: (localPaymentMethod == 'credit' && selectedCustomer == null)
                  ? null
                  : () async {
                      final sale = await pos.checkout();if (mounted && sale != null) {
  _playSaleCompleteSound();
  if (localPaymentMethod == 'credit' && selectedCustomer != null) {
    await context.read<CustomerProvider>().loadCustomers();
  }
  Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SaleReceiptScreen(sale: sale),
                          ),
                        );
                      }
                    },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة البيع (POS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'الفواتير',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoiceListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'مسح مستمر',
            onPressed: _openContinuousScanner,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final productPanel = _buildProductPanel();
          final cartPanel = _buildCartPanel();

          if (isNarrow) {
            // هاتف: المنتجات فوق (قابلة للتمرير)، السلة تحت بعرض كامل
            return Column(
              children: [
                Expanded(flex: 3, child: productPanel),
                const Divider(height: 1),
                SizedBox(
                  height: 340,
                  width: double.infinity,
                  child: cartPanel,
                ),
              ],
            );
          }

          // تابلت/شاشة عريضة: جنب لجنب كما كان
          return Row(
            children: [
              Expanded(flex: 2, child: productPanel),
              Expanded(flex: 1, child: cartPanel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'بحث عن منتج...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                context.read<InventoryProvider>().loadProducts();
              } else {
                context.read<InventoryProvider>().searchProducts(value);
              }
            },
          ),
        ),
        Expanded(
          child: Consumer<InventoryProvider>(
            builder: (context, inventory, child) {
              if (inventory.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (inventory.products.isEmpty) {
                return const Center(child: Text('لا توجد منتجات'));
              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                ),
                itemCount: inventory.products.length,
                itemBuilder: (context, index) {
                  final product = inventory.products[index];
                  return Card(
                    child: InkWell(
                      onTap: () => _addToCart(product),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${product.price} د.ج'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel() {
    return Consumer<PosProvider>(
      builder: (context, pos, child) {
        return Column(
          children: [
            Expanded(
              child: pos.cartItems.isEmpty
                  ? const Center(child: Text('السلة فارغة', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: pos.cartItems.length,
                      itemBuilder: (context, index) {
                        final item = pos.cartItems[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.product.name, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${item.product.price} × ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                onPressed: () => pos.updateQuantity(
                                  item.product.id!,
                                  item.quantity - 1,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () => pos.updateQuantity(
                                  item.product.id!,
                                  item.quantity + 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[200],
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الفرعي:'),
                      Text('${pos.subtotal.toStringAsFixed(2)} د.ج'),
                    ],
                  ),
                  if (pos.discount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الخصم:'),
                        Text(
                          '-${pos.discount.toStringAsFixed(2)} د.ج',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${pos.total.toStringAsFixed(2)} د.ج',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFC107), // أصفر
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.black87),
                          iconSize: 22,
                          tooltip: 'تعديل السلة',
                          onPressed: pos.cartItems.isEmpty ? null : () => _showEditCartSheet(pos),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pos.cartItems.isEmpty
                              ? Colors.grey.shade400
                              : const Color(0xFF43A047), // أخضر
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: pos.cartItems.isEmpty ? null : _showCheckoutDialog,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.payments, color: Colors.white, size: 20),
                                Text('دفع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade300,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.black87),
                          iconSize: 22,
                          onPressed: pos.cartItems.isEmpty ? null : () => _confirmClearCart(pos),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
