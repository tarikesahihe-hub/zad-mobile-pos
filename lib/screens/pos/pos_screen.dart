import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                      final sale = await pos.checkout();
                      if (mounted && sale != null) {
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
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
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
            ),
          ),
          Expanded(
            flex: 1,
            child: Consumer<PosProvider>(
              builder: (context, pos, child) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: pos.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = pos.cartItems[index];
                          return ListTile(
                            title: Text(item.product.name),
                            subtitle: Text('${item.product.price} x ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => pos.updateQuantity(
                                    item.product.id!,
                                    item.quantity - 1,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
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
                      padding: const EdgeInsets.all(16),
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
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: pos.cartItems.isEmpty ? null : _showCheckoutDialog,
                                  child: const Text('دفع'),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: pos.cartItems.isEmpty ? null : () => pos.clearCart(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
