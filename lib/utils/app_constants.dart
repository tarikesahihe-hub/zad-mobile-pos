class AppConstants {
  static const String appName = 'ZAD Mobile POS';
  static const String appVersion = '1.0.0';

  static const List<String> paymentMethods = [
    'cash',
    'card',
    'transfer',
    'credit',
  ];

  static const List<String> paymentMethodNames = [
    'نقداً',
    'بطاقة',
    'تحويل',
    'آجل',
  ];

  static const List<String> userRoles = [
    'admin',
    'manager',
    'seller',
    'accountant',
    'stock',
  ];

  static const List<String> userRoleNames = [
    'مدير النظام',
    'مدير المحل',
    'بائع',
    'محاسب',
    'أمين مخزن',
  ];

  static String getPaymentMethodName(String method) {
    final index = paymentMethods.indexOf(method);
    return index >= 0 ? paymentMethodNames[index] : method;
  }

  static String getRoleName(String role) {
    final index = userRoles.indexOf(role);
    return index >= 0 ? userRoleNames[index] : role;
  }
}
