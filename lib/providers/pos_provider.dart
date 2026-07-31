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
  double _amountPaid = 0;
  int? _customerId;
  String? _customerName;

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  double get subtotal => _cartItems.fold(0, (sum, item) => sum + item.total);
  double get discount => _discount;
  double get tax => _tax;
  double get total => subtotal - _discount + _tax;
  String get paymentMethod => _paymentMethod;
  double get amountPaid => _amountPaid;
  double get changeDue => (_amountPaid - total) > 0 ? _amountPaid - total : 0;
  double get remainingDue => (total - _amountPaid) > 0 ? total - _amountPaid : 0;
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

  void setAmountPaid(double amount) {
    _amountPaid = amount;
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
    _amountPaid = 0;
    _customerId = null;
    _customerName = null;
    notifyListeners();
  }

  Future<Sale?> checkout() async {
    if (_cartItems.isEmpty) return null;

    final db = DatabaseService();
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';

    // For cash/card payments with no amount explicitly entered, assume the
    // full total was paid (no partial payment UI shown). For credit sales,
    // amountPaid reflects only what was actually paid up front (may be 0).
    final effectivePaid = _paymentMethod == 'credit'
        ? _amountPaid
        : (_amountPaid > 0 ? _amountPaid : total);
    final effectiveChange = effectivePaid > total ? effectivePaid - total : 0.0;

    final sale = Sale(
      invoiceNumber: invoiceNumber,
      date: DateTime.now(),
      subtotal: subtotal,
      discount: _discount,
      tax: _tax,
      total: total,
      amountPaid: effectivePaid,
      changeDue: effectiveChange,
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

    // Update customer balance if credit — only the unpaid remainder becomes debt.
    if (_paymentMethod == 'credit' && _customerId != null) {
      final customer = await db.getCustomerById(_customerId!);
      if (customer != null) {
        final unpaidAmount = total - effectivePaid;
        final updated = customer.copyWith(
          balance: customer.balance + (unpaidAmount > 0 ? unpaidAmount : 0),
          loyaltyPoints: customer.loyaltyPoints + (total ~/ 10),
        );
        await db.updateCustomer(updated);
      }
    }

    clearCart();
    return await db.getSaleById(saleId);
  }

  /// Loads an existing sale into the cart for editing.
  void loadSaleForEditing(Sale sale, List<CartItem> items) {
    _cartItems
      ..clear()
      ..addAll(items);
    _discount = sale.discount;
    _tax = sale.tax;
    _paymentMethod = sale.paymentMethod;
    _amountPaid = sale.amountPaid;
    _customerId = sale.customerId;
    _customerName = sale.customerName;
    notifyListeners();
  }

  /// Saves edits to an existing sale: updates the sale row, replaces its
  /// sale_items, and reconciles stock against the ORIGINAL quantities so
  /// stock levels stay correct after the edit.
  Future<bool> updateExistingSale(
    Sale originalSale,
    Map<int, int> originalQuantities, // productId -> original quantity sold
  ) async {
    if (originalSale.id == null) return false;
    final db = DatabaseService();

    final effectivePaid = _paymentMethod == 'credit'
        ? _amountPaid
        : (_amountPaid > 0 ? _amountPaid : total);
    final effectiveChange = effectivePaid > total ? effectivePaid - total : 0.0;

    final updatedSale = Sale(
      id: originalSale.id,
      invoiceNumber: originalSale.invoiceNumber,
      date: originalSale.date,
      subtotal: subtotal,
      discount: _discount,
      tax: _tax,
      total: total,
      amountPaid: effectivePaid,
      changeDue: effectiveChange,
      paymentMethod: _paymentMethod,
      customerId: _customerId,
      customerName: _customerName,
      notes: originalSale.notes,
      status: originalSale.status,
      createdAt: originalSale.createdAt,
    );
    await db.updateSale(updatedSale);
    await db.deleteSaleItemsBySale(originalSale.id!);

    // Reconcile stock: restore original quantities, then deduct new ones.
    final touchedProductIds = <int>{...originalQuantities.keys, ..._cartItems.map((c) => c.product.id!)};
    for (final productId in touchedProductIds) {
      final product = await db.getProductById(productId);
      if (product == null) continue;
      final originalQty = originalQuantities[productId] ?? 0;
      final newItem = _cartItems.where((c) => c.product.id == productId);
      final newQty = newItem.isNotEmpty ? newItem.first.quantity : 0;
      final delta = originalQty - newQty; // positive => give stock back
      if (delta != 0) {
        final updated = product.copyWith(
          quantity: product.quantity + delta,
          updatedAt: DateTime.now(),
        );
        await db.updateProduct(updated);
      }
    }

    for (final cartItem in _cartItems) {
      final item = SaleItem(
        saleId: originalSale.id!,
        productId: cartItem.product.id!,
        productName: cartItem.product.name,
        unitPrice: cartItem.unitPrice,
        quantity: cartItem.quantity,
        discount: cartItem.discount,
        total: cartItem.total,
      );
      await db.insertSaleItem(item);
    }

    clearCart();
    return true;
  }
}
