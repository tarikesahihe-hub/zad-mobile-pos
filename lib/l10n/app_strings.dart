import 'package:flutter/material.dart';

class AppStrings {
  static const Map<String, Map<String, String>> _values = {
    'ar': {
      'nav_home': 'الرئيسية',
      'nav_pos': 'نقطة البيع',
      'nav_inventory': 'المخزون',
      'nav_customers': 'العملاء',
      'nav_reports': 'التقارير',
      'nav_settings': 'الإعدادات',
    },
    'fr': {
      'nav_home': 'Accueil',
      'nav_pos': 'Point de vente',
      'nav_inventory': 'Stock',
      'nav_customers': 'Clients',
      'nav_reports': 'Rapports',
      'nav_settings': 'Paramètres',
    },
    'en': {
      'nav_home': 'Home',
      'nav_pos': 'POS',
      'nav_inventory': 'Inventory',
      'nav_customers': 'Customers',
      'nav_reports': 'Reports',
      'nav_settings': 'Settings',
    },
  };

  static String get(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    return _values[lang]?[key] ?? _values['ar']?[key] ?? key;
  }
}
