class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double balance;
  final int loyaltyPoints;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.balance = 0.0,
    this.loyaltyPoints = 0,
    required this.createdAt,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? balance,
    int? loyaltyPoints,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'],
    name: map['name'] ?? '',
    phone: map['phone'],
    email: map['email'],
    address: map['address'],
    balance: map['balance']?.toDouble() ?? 0.0,
    loyaltyPoints: map['loyalty_points'] ?? 0,
    createdAt: DateTime.parse(map['created_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'balance': balance,
    'loyalty_points': loyaltyPoints,
    'created_at': createdAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
