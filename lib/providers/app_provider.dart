import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');
  String _businessName = '';
  String _businessType = '';

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get businessName => _businessName;
  String get businessType => _businessType;

  AppProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    final lang = prefs.getString('language') ?? 'ar';
    final bName = prefs.getString('business_name') ?? '';
    final bType = prefs.getString('business_type') ?? '';

    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _locale = Locale(lang);
    _businessName = bName;
    _businessType = bType;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    notifyListeners();
  }

  Future<void> setBusinessInfo({required String name, required String type}) async {
    _businessName = name;
    _businessType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_name', name);
    await prefs.setString('business_type', type);
    notifyListeners();
  }
}
