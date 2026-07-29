import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ReportProvider extends ChangeNotifier {
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _dashboardStats = {};
  Map<String, dynamic> _detailedReport = {};
  bool _isLoading = false;
  String _selectedPeriod = 'today';

  Map<String, dynamic> get todayStats => _todayStats;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  Map<String, dynamic> get detailedReport => _detailedReport;
  bool get isLoading => _isLoading;
  String get selectedPeriod => _selectedPeriod;

  final DatabaseService _db = DatabaseService();

  Future<void> loadTodayStats() async {
    _isLoading = true;
    notifyListeners();
    _todayStats = await _db.getTodayStats();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDashboardStats() async {
    _isLoading = true;
    notifyListeners();
    _dashboardStats = await _db.getDashboardStats();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDetailedReport(String period) async {
    _selectedPeriod = period;
    _isLoading = true;
    notifyListeners();
    _detailedReport = await _db.getDetailedReport(period);
    _isLoading = false;
    notifyListeners();
  }

  String getPeriodLabel(String period) {
    switch (period) {
      case 'today': return 'اليوم';
      case 'week': return 'هذا الأسبوع';
      case 'month': return 'هذا الشهر';
      case 'year': return 'هذه السنة';
      default: return period;
    }
  }
}
