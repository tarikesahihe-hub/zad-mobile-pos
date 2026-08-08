import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';

class SupplierProvider extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String? _error;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final DatabaseService _db = DatabaseService();

  Future<void> loadSuppliers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _suppliers = await _db.getAllSuppliers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSupplier(Supplier supplier) async {
    try {
      await _db.insertSupplier(supplier);
      await loadSuppliers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    try {
      await _db.updateSupplier(supplier);
      await loadSuppliers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSupplier(int id) async {
    try {
      await _db.deleteSupplier(id);
      await loadSuppliers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
