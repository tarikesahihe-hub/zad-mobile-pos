import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// يدير جلسة الصندوق النشطة للمستخدم الحالي: فتح، تسجيل حركات، وغلق
/// مع حساب الفرق بين المتوقع والفعلي تلقائياً.
///
/// جلسة الصندوق اختيارية بالكامل — إذا ماكانتش جلسة مفتوحة، البيع يخدم
/// عادي بلا تسجيل حركات (recordMovement تتجاهل بصمت فهاذ الحالة).
class CashSessionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  Map<String, dynamic>? _openSession;
  List<Map<String, dynamic>> _sessionMovements = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get openSession => _openSession;
  bool get hasOpenSession => _openSession != null;
  List<Map<String, dynamic>> get sessionMovements => _sessionMovements;
  List<Map<String, dynamic>> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get openingAmount =>
      (_openSession?['opening_amount'] as num?)?.toDouble() ?? 0.0;

  int? get sessionId => _openSession?['id'] as int?;

  /// يتحقق واش المستخدم عندو جلسة مفتوحة حالياً، ويحملها إذا كاينة.
  /// خاص يتنادى عند بداية شاشة POS أو بداية جلسة عمل المستخدم.
  Future<void> checkOpenSession(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _db.getOpenCashSession(userId);
      _openSession = session;
      if (session != null) {
        final id = session['id'] as int;
        _sessionMovements = await _db.getSessionMovements(id);
      } else {
        _sessionMovements = [];
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// يفتح جلسة صندوق جديدة برصيد ابتدائي. يفشل إذا كانت هناك جلسة
  /// مفتوحة بالفعل لنفس المستخدم (يجب غلقها أولاً).
  Future<bool> openNewSession({
    required int userId,
    required double openingAmount,
  }) async {
    if (_openSession != null) {
      _error = 'كاين جلسة صندوق مفتوحة بالفعل، خاصك تغلقها أولاً';
      notifyListeners();
      return false;
    }
    try {
      final id = await _db.openCashSession(
        userId: userId,
        openingAmount: openingAmount,
      );
      await checkOpenSession(userId);
      return _openSession != null && _openSession!['id'] == id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// يسجل حركة صندوق (بيع، مصروف، إيداع...) فـ الجلسة المفتوحة الحالية.
  /// إذا ماكانتش جلسة مفتوحة، ما يديرش شي حاجة (اختياري بالتصميم).
  Future<void> recordMovement({
    required String type,
    required double amount,
    int? referenceId,
    String? notes,
  }) async {
    final id = sessionId;
    if (id == null) return; // بلا جلسة مفتوحة، بلا تسجيل — عادي وليس خطأ
    try {
      await _db.addCashMovement(
        sessionId: id,
        type: type,
        amount: amount,
        referenceId: referenceId,
        notes: notes,
      );
      _sessionMovements = await _db.getSessionMovements(id);
      notifyListeners();
    } catch (e) {
      // فشل تسجيل حركة صندوق ما يوقفش عملية البيع نفسها — نسجل الخطأ فقط.
      debugPrint('تعذر تسجيل حركة الصندوق: $e');
    }
  }

  /// يحسب الرصيد المتوقع حالياً (ابتدائي + مجموع الحركات) بلا غلق الجلسة،
  /// مفيد لعرضه للمستخدم قبل ما يقرر يغلق.
  double get expectedAmountSoFar {
    final opening = openingAmount;
    final movementsTotal = _sessionMovements.fold<double>(
      0.0,
      (sum, m) => sum + ((m['amount'] as num?)?.toDouble() ?? 0.0),
    );
    return opening + movementsTotal;
  }

  /// يغلق الجلسة المفتوحة الحالية بالرصيد الفعلي المُدخل، ويرجع ملخص
  /// النتيجة (المتوقع، الفعلي، الفرق) أو null إذا فشلت العملية.
  Future<Map<String, dynamic>?> closeCurrentSession({
    required double closingAmount,
  }) async {
    final id = sessionId;
    if (id == null) {
      _error = 'ماكاين حتى جلسة مفتوحة للغلق';
      notifyListeners();
      return null;
    }
    try {
      final result = await _db.closeCashSession(
        sessionId: id,
        closingAmount: closingAmount,
      );
      _openSession = null;
      _sessionMovements = [];
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// يحمل سجل الجلسات السابقة (تاريخ) لمستخدم معين.
  Future<void> loadHistory(int userId) async {
    try {
      _history = await _db.getCashSessionsHistory(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
