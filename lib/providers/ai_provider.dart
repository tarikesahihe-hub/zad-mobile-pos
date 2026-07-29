import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AiProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _lastResponse;
  List<Map<String, dynamic>> _insights = [];

  bool get isLoading => _isLoading;
  String? get lastResponse => _lastResponse;
  List<Map<String, dynamic>> get insights => _insights;

  final DatabaseService _db = DatabaseService();

  Future<String> askQuestion(String question) async {
    _isLoading = true;
    notifyListeners();

    final q = question.toLowerCase();
    String response = '';

    if (q.contains('أكثر') && q.contains('منتج')) {
      response = await _getTopSellingProduct();
    } else if (q.contains('مبيعات') && q.contains('اليوم')) {
      response = await _getTodaySalesSummary();
    } else if (q.contains('إعادة') && q.contains('طلب')) {
      response = await _getRestockSuggestions();
    } else if (q.contains('ربح') || q.contains('أرباح')) {
      response = await _getProfitAnalysis();
    } else if (q.contains('مخزون') && q.contains('ينفد')) {
      response = await _getStockOutPrediction();
    } else {
      response = 'عذراً، لم أفهم سؤالك. يمكنك سؤالي عن: المبيعات، الأرباح، المنتجات الأكثر مبيعاً، أو المنتجات التي تحتاج إعادة طلب.';
    }

    _lastResponse = response;
    _isLoading = false;
    notifyListeners();
    return response;
  }

  Future<String> _getTopSellingProduct() async {
    final report = await _db.getDetailedReport('month');
    final topProducts = report['topProducts'] as List<Map<String, dynamic>>;
    if (topProducts.isEmpty) {
      return 'لا توجد بيانات مبيعات كافية هذا الشهر بعد.';
    }
    final first = topProducts.first;
    var response = 'أكثر منتج مبيعاً هذا الشهر هو: "${first['product_name']}" بإجمالي ${first['qty']} قطعة مباعة.';
    if (topProducts.length > 1) {
      final second = topProducts[1];
      response += ' يليه "${second['product_name']}" بـ ${second['qty']} قطعة.';
    }
    return response;
  }

  Future<String> _getTodaySalesSummary() async {
    final stats = await _db.getTodayStats();
    final count = stats['salesCount'] ?? 0;
    final total = (stats['salesTotal'] as num?)?.toDouble() ?? 0.0;
    final profit = (stats['profit'] as num?)?.toDouble() ?? 0.0;
    return 'مبيعات اليوم: $count فاتورة بإجمالي ${total.toStringAsFixed(2)} د.ج. الأرباح الفعلية: ${profit.toStringAsFixed(2)} د.ج.';
  }

  Future<String> _getRestockSuggestions() async {
    final lowStock = await _db.getLowStockProducts();
    if (lowStock.isEmpty) return 'لا توجد منتجات تحتاج إعادة طلب حالياً. المخزون بخير!';
    final names = lowStock.map((p) => '"${p.name}" (متبقي ${p.quantity})').join('\n- ');
    return 'المنتجات التي يجب إعادة طلبها:\n- $names\n\nننصح بطلب كميات تكفي لـ 15 يوماً قادمة.';
  }

  Future<String> _getProfitAnalysis() async {
    final today = await _db.getTodayStats();
    final profit = (today['profit'] as num?)?.toDouble() ?? 0.0;
    final salesTotal = (today['salesTotal'] as num?)?.toDouble() ?? 0.0;
    final margin = salesTotal > 0 ? (profit / salesTotal * 100) : 0.0;

    final weekReport = await _db.getDetailedReport('week');
    final weekProfit = (weekReport['profit'] as num?)?.toDouble() ?? 0.0;

    return 'تحليل الأرباح:\n'
        '- أرباح اليوم: ${profit.toStringAsFixed(2)} د.ج\n'
        '- الهامش الفعلي اليوم: ${margin.toStringAsFixed(1)}%\n'
        '- أرباح هذا الأسبوع (تراكمي): ${weekProfit.toStringAsFixed(2)} د.ج';
  }

  Future<String> _getStockOutPrediction() async {
    final forecast = await _db.getStockOutForecast();
    final soon = forecast.where((p) => (p['daysRemaining'] as double) <= 7).take(5).toList();

    if (soon.isEmpty) {
      return 'لا توجد منتجات مهددة بالنفاد خلال الأسبوع القادم بناءً على معدل المبيعات الحالي.';
    }

    final lines = soon.map((p) {
      final days = (p['daysRemaining'] as double).round();
      final dayLabel = days <= 0 ? 'خلال أقل من يوم' : (days == 1 ? 'خلال يوم واحد' : 'خلال $days أيام');
      return '"${p['name']}" سينفد تقريباً $dayLabel (المتبقي: ${p['quantity']})';
    }).join('\n- ');

    return 'التنبؤ بنفاد المخزون (حسب معدل المبيعات لآخر 30 يوماً):\n- $lines\n\nننصح بالطلب الفوري للمنتجات المحددة.';
  }

  Future<void> generateInsights() async {
    _isLoading = true;
    notifyListeners();

    final insights = <Map<String, dynamic>>[];

    final lowStock = await _db.getLowStockProducts();
    if (lowStock.isNotEmpty) {
      insights.add({
        'type': 'warning',
        'title': 'نفاد مخزون',
        'message': '${lowStock.length} منتج على وشك النفاد أو تحت الحد الأدنى',
      });
    }

    final report = await _db.getDetailedReport('month');
    final topProducts = report['topProducts'] as List<Map<String, dynamic>>;
    if (topProducts.isNotEmpty) {
      final top = topProducts.first;
      insights.add({
        'type': 'info',
        'title': 'أفضل منتج',
        'message': '${top['product_name']} - ${top['qty']} قطعة مباعة هذا الشهر',
      });
    }

    final today = await _db.getTodayStats();
    final profit = (today['profit'] as num?)?.toDouble() ?? 0.0;
    insights.add({
      'type': profit >= 0 ? 'success' : 'warning',
      'title': 'الأرباح',
      'message': 'أرباح اليوم: ${profit.toStringAsFixed(2)} د.ج',
    });

    final forecast = await _db.getStockOutForecast();
    final urgent = forecast.where((p) => (p['daysRemaining'] as double) <= 3).toList();
    if (urgent.isNotEmpty) {
      insights.add({
        'type': 'warning',
        'title': 'نفاد وشيك',
        'message': '${urgent.length} منتج قد ينفد خلال 3 أيام حسب معدل المبيعات',
      });
    }

    if (insights.isEmpty) {
      insights.add({
        'type': 'info',
        'title': 'لا توجد رؤى بعد',
        'message': 'أضف منتجات وسجّل مبيعات ليتمكن المساعد من تحليل أدائك',
      });
    }

    _insights = insights;
    _isLoading = false;
    notifyListeners();
  }
}
