import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _lowStockProducts = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Product> get lowStockProducts => _lowStockProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final DatabaseService _db = DatabaseService();

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _db.getAllProducts();
      _lowStockProducts = await _db.getLowStockProducts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct(Product product) async {
    try {
      await _db.insertProduct(product);
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      await _db.updateProduct(product);
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await _db.deleteProduct(id);
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> searchProducts(String query) async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _db.searchProducts(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    return await _db.getProductByBarcode(barcode);
  }

  Future<bool> adjustStock(int productId, int newQuantity, String reason) async {
    try {
      final product = await _db.getProductById(productId);
      if (product != null) {
        final updated = product.copyWith(quantity: newQuantity, updatedAt: DateTime.now());
        await _db.updateProduct(updated);
        await loadProducts();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
