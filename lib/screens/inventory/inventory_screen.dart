import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/product.dart';
import '../../l10n/app_strings.dart';
import '../../services/import_service.dart';
import 'product_form_screen.dart';
import '../pos/barcode_scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  bool _importing = false;

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
      final body = AppStrings
          .get(context, 'inv_product_not_found_body')
          .replaceAll('{code}', code);
      final add = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppStrings.get(context, 'inv_product_not_found_title')),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.get(context, 'common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.get(context, 'common_add')),
            ),
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

  Future<void> _importFromFile() async {
    setState(() => _importing = true);
    try {
      final result = await ImportService().pickAndImport();
      if (!mounted) return;
      setState(() => _importing = false);
      if (result == null) return; // user cancelled the picker

      await context.read<InventoryProvider>().loadProducts();
      if (!mounted) return;

      if (result.importedCount > 0) {
        final msg = AppStrings
            .get(context, 'inv_import_success')
            .replaceAll('{count}', '${result.importedCount}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      if (result.errors.isNotEmpty) {
        _showImportErrorsDialog(result.errors);
      }
      if (result.importedCount == 0 && result.errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get(context, 'inv_import_no_valid_rows'))),
        );
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() => _importing = false);
      debugPrint('IMPORT ERROR: $e');
      debugPrint('STACK: $stackTrace');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تفاصيل خطأ الاستيراد'),
          content: SingleChildScrollView(
            child: SelectableText(
              'ERROR: $e\n\nSTACK:\n$stackTrace',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showImportErrorsDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get(context, 'inv_import_title')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(errors[index], style: const TextStyle(fontSize: 13, color: Colors.red)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get(context, 'common_done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get(context, 'inv_title')),
        actions: [
          _importing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  tooltip: AppStrings.get(context, 'inv_import_button'),
                  onPressed: _importFromFile,
                ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _quickScan(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: AppStrings.get(context, 'inv_search_hint'),
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

          Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              if (provider.lowStockProducts.isEmpty) return const SizedBox.shrink();
              final text = AppStrings
                  .get(context, 'inv_low_stock_warning')
                  .replaceAll('{count}', '${provider.lowStockProducts.length}');
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
                        text,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.products.isEmpty) {
                  return Center(child: Text(AppStrings.get(context, 'inv_no_products')));
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
        label: Text(AppStrings.get(context, 'inv_new_product')),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;

  const _ProductListTile({required this.product});

  Widget _buildThumbnail(bool isLowStock) {
    if (product.imagePath != null && File(product.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(product.imagePath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= product.minStock && product.minStock > 0;
    final currency = context.watch<AppProvider>().currencySymbol;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _buildThumbnail(isLowStock),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.barcode != null)
              Text(
                '${AppStrings.get(context, 'inv_barcode_prefix')} ${product.barcode}',
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              '${AppStrings.get(context, 'inv_quantity_label')} ${product.quantity} | ${AppStrings.get(context, 'inv_min_stock_label')} ${product.minStock}',
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product.salePrice.toStringAsFixed(2)} $currency',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF43A047),
                fontSize: 16,
              ),
            ),
            Text(
              '${AppStrings.get(context, 'inv_purchase_label')} ${product.purchasePrice.toStringAsFixed(2)} $currency',
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
