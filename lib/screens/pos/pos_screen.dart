import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pos_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/product.dart';
import '../../services/printer_service.dart';
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

  void _showCheckoutDialog() {
    final pos = context.read<PosProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إتمام عملية البيع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الإجمالي: ${pos.total.toStringAsFixed(2)} د.ج'),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CASH', label: Text('نقداً')),
                ButtonSegment(value: 'CARD', label: Text('بطاقة')),
              ],
              selected: {pos.paymentMethod},
              onSelectionChanged: (selected) {
                pos.setPaymentMethod(selected.first);
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'الخصم'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                pos.setDiscount(double.tryParse(value) ?? 0);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final sale = await pos.completeSale();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة البيع (POS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BarcodeScannerScreen(),
                ),
              );
            },
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
