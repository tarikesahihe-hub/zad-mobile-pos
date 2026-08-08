import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  List<String> _permissions = [];

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  List<String> get permissions => _permissions;
  String? get userRole => _currentUser?.role;

  Future<bool> login(String username, String pin) async {
    final db = DatabaseService();
    final user = await db.getUserByUsername(username);
    if (user != null && user.pin == pin && user.isActive) {
      _currentUser = user;
      _isAuthenticated = true;
      _permissions = await db.getRolePermissions(user.role);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> loginWithBiometrics(String username) async {
    final db = DatabaseService();
    final user = await db.getUserByUsername(username);
    if (user != null && user.isActive) {
      _currentUser = user;
      _isAuthenticated = true;
      _permissions = await db.getRolePermissions(user.role);
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    _permissions = [];
    notifyListeners();
  }

  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    if (_currentUser!.role == 'admin') return true;
    return _permissions.contains(permission);
  }

  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isManager => _currentUser?.role == 'manager' || isAdmin;

  /// Updates the currently logged-in user's username and/or PIN.
  /// [currentPin] must match the existing PIN for security.
  /// Returns a status string: 'success', 'wrong_pin', 'username_taken', or 'error'.
  Future<String> updateCredentials({
    required String currentPin,
    String? newUsername,
    String? newPin,
  }) async {
    if (_currentUser == null) return 'error';
    final db = DatabaseService();

    if (_currentUser!.pin != currentPin) {
      return 'wrong_pin';
    }

    final targetUsername = (newUsername != null && newUsername.trim().isNotEmpty)
        ? newUsername.trim()
        : _currentUser!.username;

    if (targetUsername != _currentUser!.username) {
      final existing = await db.getUserByUsername(targetUsername);
      if (existing != null) {
        return 'username_taken';
      }
    }

    final targetPin = (newPin != null && newPin.trim().isNotEmpty)
        ? newPin.trim()
        : _currentUser!.pin;

    final updatedUser = User(
      id: _currentUser!.id,
      username: targetUsername,
      fullName: _currentUser!.fullName,
      role: _currentUser!.role,
      pin: targetPin,
      isActive: _currentUser!.isActive,
      createdAt: _currentUser!.createdAt,
    );

    try {
      await db.updateUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
      return 'success';
    } catch (e) {
      return 'error';
    }
  }
}
