import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import 'package:provider/provider.dart';
import '../pos/barcode_scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;

  const ProductFormScreen({super.key, this.product, this.initialBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _supplierController = TextEditingController();
  final _batchController = TextEditingController();
  final _expiryController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _barcodeController.text = widget.product!.barcode ?? '';
      _purchasePriceController.text = widget.product!.purchasePrice.toString();
      _salePriceController.text = widget.product!.salePrice.toString();
      _quantityController.text = widget.product!.quantity.toString();
      _minStockController.text = widget.product!.minStock.toString();
      _categoryController.text = widget.product!.category ?? '';
      _supplierController.text = widget.product!.supplier ?? '';
      _batchController.text = widget.product!.batchNumber ?? '';
      _expiryController.text = widget.product!.expiryDate ?? '';
    } else if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل منتج' : 'إضافة منتج'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Image
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey),
                    image: _imageFile != null
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : (widget.product?.imagePath != null
                            ? DecorationImage(image: FileImage(File(widget.product!.imagePath!)), fit: BoxFit.cover)
                            : null),
                  ),
                  child: _imageFile == null && widget.product?.imagePath == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),

              // Barcode
              TextFormField(
                controller: _barcodeController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'الباركود',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                      );
                      if (result != null && result.isNotEmpty) {
                        setState(() => _barcodeController.text = result);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Prices Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سعر الشراء (د.ج)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سعر البيع (د.ج) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quantity Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأدنى',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category & Supplier
              TextFormField(
                controller: _categoryController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'المورد',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Batch & Expiry
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batchController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'رقم التشغيلة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الصلاحية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة المنتج', style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
      salePrice: double.tryParse(_salePriceController.text) ?? 0,
      quantity: int.tryParse(_quantityController.text) ?? 0,
      category: _categoryController.text.isEmpty ? null : _categoryController.text,
      supplier: _supplierController.text.isEmpty ? null : _supplierController.text,
      minStock: int.tryParse(_minStockController.text) ?? 0,
      batchNumber: _batchController.text.isEmpty ? null : _batchController.text,
      expiryDate: _expiryController.text.isEmpty ? null : _expiryController.text,
      imagePath: _imageFile?.path ?? widget.product?.imagePath,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final provider = context.read<InventoryProvider>();
    bool success;
    if (widget.product != null) {
      success = await provider.updateProduct(product);
    } else {
      success = await provider.addProduct(product);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.product != null ? 'تم التعديل' : 'تم الإضافة')),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.product != null) {
                await context.read<InventoryProvider>().deleteProduct(widget.product!.id!);
                if (mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _categoryController.dispose();
    _supplierController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    super.dispose();
  }
}
