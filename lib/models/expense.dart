class Expense {
  final int? id;
  final String title;
  final double amount;
  final String? category;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    this.category,
    this.notes,
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'],
        title: map['title'],
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        category: map['category'],
        notes: map['notes'],
        date: DateTime.parse(map['date']),
        createdAt: DateTime.parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'notes': notes,
        'date': date.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
