class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double balance;
  final DateTime createdAt;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.balance = 0,
    required this.createdAt,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'],
    name: map['name'],
    phone: map['phone'],
    email: map['email'],
    address: map['address'],
    balance: map['balance']?.toDouble() ?? 0.0,
    createdAt: DateTime.parse(map['created_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'balance': balance,
    'created_at': createdAt.toIso8601String(),
  };
}
