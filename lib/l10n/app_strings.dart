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
      'dash_new_sale': 'بيع جديد',
      'dash_sales_today': 'مبيعات اليوم',
      'dash_invoice_count': 'فاتورة',
      'dash_profit': 'الأرباح',
      'dash_profit_margin': 'هامش تقديري',
      'dash_products': 'المنتجات',
      'dash_active_item': 'صنف نشط',
      'dash_low_stock': 'نقص المخزون',
      'dash_needs_order': 'يحتاج طلب',
      'dash_smart_alerts': 'تنبيهات ذكية',
      'dash_ai_assistant': 'المساعد الذكي',
    },
    'fr': {
      'nav_home': 'Accueil',
      'nav_pos': 'Point de vente',
      'nav_inventory': 'Stock',
      'nav_customers': 'Clients',
      'nav_reports': 'Rapports',
      'nav_settings': 'Paramètres',
      'dash_new_sale': 'Nouvelle vente',
      'dash_sales_today': 'Ventes du jour',
      'dash_invoice_count': 'facture(s)',
      'dash_profit': 'Bénéfices',
      'dash_profit_margin': 'Marge estimée',
      'dash_products': 'Produits',
      'dash_active_item': 'article actif',
      'dash_low_stock': 'Stock faible',
      'dash_needs_order': 'à commander',
      'dash_smart_alerts': 'Alertes intelligentes',
      'dash_ai_assistant': 'Assistant intelligent',
    },
    'en': {
      'nav_home': 'Home',
      'nav_pos': 'POS',
      'nav_inventory': 'Inventory',
      'nav_customers': 'Customers',
      'nav_reports': 'Reports',
      'nav_settings': 'Settings',
      'dash_new_sale': 'New Sale',
      'dash_sales_today': "Today's Sales",
      'dash_invoice_count': 'invoice(s)',
      'dash_profit': 'Profit',
      'dash_profit_margin': 'Estimated margin',
      'dash_products': 'Products',
      'dash_active_item': 'active item',
      'dash_low_stock': 'Low Stock',
      'dash_needs_order': 'needs order',
      'dash_smart_alerts': 'Smart Alerts',
      'dash_ai_assistant': 'AI Assistant',
    },
  };

  static String get(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    return _values[lang]?[key] ?? _values['ar']?[key] ?? key;
  }
}
