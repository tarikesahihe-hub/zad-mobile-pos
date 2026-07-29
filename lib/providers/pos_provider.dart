import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import 'dart:math';

class CartItem {
  final Product product;
  int quantity;
  double discount;

  CartItem({required this.product, this.quantity = 1, this.discount = 0});

  double get total => (product.salePrice * quantity) - discount;
  double get unitPrice => product.salePrice;
}

class PosProvider extends ChangeNotifier {
  final List<CartItem> _cartItems = [];
  double _discount = 0;
  double _tax = 0;
  String _paymentMethod = 'cash';
  int? _customerId;
  String? _customerName;

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  double get subtotal => _cartItems.fold(0, (sum, item) => sum + item.total);
  double get discount => _discount;
  double get tax => _tax;
  double get total => subtotal - _discount + _tax;
  String get paymentMethod => _paymentMethod;
  int? get customerId => _customerId;
  String? get customerName => _customerName;

  void addToCart(Product product, {int quantity = 1}) {
    final existing = _cartItems.indexWhere((item) => item.product.id == product.id);
    if (existing >= 0) {
      _cartItems[existing].quantity += quantity;
    } else {
      _cartItems.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void setDiscount(double discount) {
    _discount = discount;
    notifyListeners();
  }

  void setTax(double tax) {
    _tax = tax;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCustomer(int? id, String? name) {
    _customerId = id;
    _customerName = name;
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _discount = 0;
    _tax = 0;
    _paymentMethod = 'cash';
    _customerId = null;
    _customerName = null;
    notifyListeners();
  }

  Future<Sale?> checkout() async {
    if (_cartItems.isEmpty) return null;

    final db = DatabaseService();
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';

    final sale = Sale(
      invoiceNumber: invoiceNumber,
      date: DateTime.now(),
      subtotal: subtotal,
      discount: _discount,
      tax: _tax,
      total: total,
      paymentMethod: _paymentMethod,
      customerId: _customerId,
      customerName: _customerName,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    final saleId = await db.insertSale(sale);

    for (final cartItem in _cartItems) {
      final item = SaleItem(
        saleId: saleId,
        productId: cartItem.product.id!,
        productName: cartItem.product.name,
        unitPrice: cartItem.unitPrice,
        quantity: cartItem.quantity,
        discount: cartItem.discount,
        total: cartItem.total,
      );
      await db.insertSaleItem(item);

      // Update stock
      final updatedProduct = cartItem.product.copyWith(
        quantity: cartItem.product.quantity - cartItem.quantity,
        updatedAt: DateTime.now(),
      );
      await db.updateProduct(updatedProduct);
    }

    // Update customer balance if credit
    if (_paymentMethod == 'credit' && _customerId != null) {
      final customer = await db.getCustomerById(_customerId!);
      if (customer != null) {
        final updated = customer.copyWith(
          balance: customer.balance + total,
          loyaltyPoints: customer.loyaltyPoints + (total ~/ 10),
        );
        await db.updateCustomer(updated);
      }
    }

    clearCart();
    return await db.getSaleById(saleId);
  }
}
