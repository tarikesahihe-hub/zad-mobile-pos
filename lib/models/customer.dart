class Customer {
  final String? id;
  final String name;
  final String? phone;
  final double debt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.debt = 0.0,
  });

  // دالة النسخ والتحديث لتفادي خطأ copyWith
  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    double? debt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      debt: debt ?? this.debt,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'] ?? '',
      phone: json['phone'],
      debt: (json['debt'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      'debt': debt,
    };
  }
}
