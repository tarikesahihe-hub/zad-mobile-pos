import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');
  String _businessName = '';
  String _businessType = '';
  String _currencyCode = 'DZD';

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get businessName => _businessName;
  String get businessType => _businessType;
  String get currencyCode => _currencyCode;
  String get currencySymbol => currencySymbolFor(_currencyCode);

  static const Map<String, String> currencySymbols = {
    'DZD': 'د.ج',
    'EUR': '€',
    'USD': '\$',
    'SAR': 'ر.س',
    'AED': 'د.إ',
    'MAD': 'د.م',
    'TND': 'د.ت',
    'KWD': 'د.ك',
    'BHD': 'د.ب',
    'QAR': 'ر.ق',
    'OMR': 'ر.ع',
    'JOD': 'د.أ',
    'EGP': 'ج.م',
    'LBP': 'ل.ل',
    'LYD': 'د.ل',
    'SDG': 'ج.س',
    'IQD': 'د.ع',
    'SYP': 'ل.س',
    'YER': 'ر.ي',
    'MRU': 'أ.م',
    'SOS': 'ش.ص',
    'DJF': 'ف.ج',
    'KMF': 'ف.ق',
    'PSN': 'ش.ف',
  };

  static const Map<String, String> currencyNames = {
    'DZD': 'دينار جزائري',
    'EUR': 'يورو',
    'USD': 'دولار أمريكي',
    'SAR': 'ريال سعودي',
    'AED': 'درهم إماراتي',
    'MAD': 'درهم مغربي',
    'TND': 'دينار تونسي',
    'KWD': 'دينار كويتي',
    'BHD': 'دينار بحريني',
    'QAR': 'ريال قطري',
    'OMR': 'ريال عماني',
    'JOD': 'دينار أردني',
    'EGP': 'جنيه مصري',
    'LBP': 'ليرة لبنانية',
    'LYD': 'دينار ليبي',
    'SDG': 'جنيه سوداني',
    'IQD': 'دينار عراقي',
    'SYP': 'ليرة سورية',
    'YER': 'ريال يمني',
    'MRU': 'أوقية موريتانية',
    'SOS': 'شلن صومالي',
    'DJF': 'فرنك جيبوتي',
    'KMF': 'فرنك قمري',
    'PSN': 'شيكل فلسطيني',
  };

  static String currencySymbolFor(String code) {
    return currencySymbols[code] ?? code;
  }

  static String currencyNameFor(String code) {
    return currencyNames[code] ?? code;
  }

  AppProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    final lang = prefs.getString('language') ?? 'ar';
    final bName = prefs.getString('business_name') ?? '';
    final bType = prefs.getString('business_type') ?? '';
    final currency = prefs.getString('currency_code') ?? 'DZD';

    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _locale = Locale(lang);
    _businessName = bName;
    _businessType = bType;
    _currencyCode = currency;
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

  Future<void> setCurrency(String code) async {
    _currencyCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', code);
    notifyListeners();
  }
}
