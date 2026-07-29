class User {
  final int? id;
  final String username;
  final String fullName;
  final String role;
  final String? pin;
  final bool isActive;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.pin,
    this.isActive = true,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'],
    username: map['username'],
    fullName: map['full_name'],
    role: map['role'],
    pin: map['pin'],
    isActive: map['is_active'] == 1,
    createdAt: DateTime.parse(map['created_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'full_name': fullName,
    'role': role,
    'pin': pin,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };
}
