import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/product.dart';
import 'product_form_screen.dart';
import '../pos/barcode_scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadProducts();
    });
  }

  Future<void> _quickScan(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    final provider = context.read<InventoryProvider>();
    final product = await provider.getProductByBarcode(code);

    if (!mounted) return;

    if (product != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
      );
    } else {
      final add = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('منتج غير موجود'),
          content: Text('لا يوجد منتج بالباركود: $code\nهل تريد إضافته؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
          ],
        ),
      );
      if (add == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductFormScreen(initialBarcode: code)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون والمنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _quickScan(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  context.read<InventoryProvider>().searchProducts(value);
                } else {
                  context.read<InventoryProvider>().loadProducts();
                }
              },
            ),
          ),

          // Low Stock Warning
          Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              if (provider.lowStockProducts.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${provider.lowStockProducts.length} منتجات على وشك النفاد',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Products List
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.products.isEmpty) {
                  return const Center(child: Text('لا توجد منتجات'));
                }
                return ListView.builder(
                  itemCount: provider.products.length,
                  itemBuilder: (context, index) {
                    final product = provider.products[index];
                    return _ProductListTile(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;

  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= product.minStock && product.minStock > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isLowStock ? Colors.red.withOpacity(0.1) : const Color(0xFF1E88E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isLowStock ? Icons.warning : Icons.inventory_2,
            color: isLowStock ? Colors.red : const Color(0xFF1E88E5),
          ),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.barcode != null) Text('باركود: ${product.barcode}', style: const TextStyle(fontSize: 12)),
            Text('الكمية: ${product.quantity} | الحد الأدنى: ${product.minStock}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product.salePrice.toStringAsFixed(2)} د.ج',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF43A047),
                fontSize: 16,
              ),
            ),
            Text(
              'شراء: ${product.purchasePrice.toStringAsFixed(2)} د.ج',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
          );
        },
      ),
    );
  }
}
