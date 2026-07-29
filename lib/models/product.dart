class Product {
  final int? id;
  final String name;
  final String? barcode;
  final String? qrCode;
  final double purchasePrice;
  final double salePrice;
  final int quantity;
  final String? category;
  final String? supplier;
  final int minStock;
  final String? expiryDate;
  final String? batchNumber;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    this.barcode,
    this.qrCode,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    this.category,
    this.supplier,
    this.minStock = 0,
    this.expiryDate,
    this.batchNumber,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'],
    name: map['name'],
    barcode: map['barcode'],
    qrCode: map['qr_code'],
    purchasePrice: map['purchase_price']?.toDouble() ?? 0.0,
    salePrice: map['sale_price']?.toDouble() ?? 0.0,
    quantity: map['quantity'] ?? 0,
    category: map['category'],
    supplier: map['supplier'],
    minStock: map['min_stock'] ?? 0,
    expiryDate: map['expiry_date'],
    batchNumber: map['batch_number'],
    imagePath: map['image_path'],
    createdAt: DateTime.parse(map['created_at']),
    updatedAt: DateTime.parse(map['updated_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'qr_code': qrCode,
    'purchase_price': purchasePrice,
    'sale_price': salePrice,
    'quantity': quantity,
    'category': category,
    'supplier': supplier,
    'min_stock': minStock,
    'expiry_date': expiryDate,
    'batch_number': batchNumber,
    'image_path': imagePath,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    String? qrCode,
    double? purchasePrice,
    double? salePrice,
    int? quantity,
    String? category,
    String? supplier,
    int? minStock,
    String? expiryDate,
    String? batchNumber,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    barcode: barcode ?? this.barcode,
    qrCode: qrCode ?? this.qrCode,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    salePrice: salePrice ?? this.salePrice,
    quantity: quantity ?? this.quantity,
    category: category ?? this.category,
    supplier: supplier ?? this.supplier,
    minStock: minStock ?? this.minStock,
    expiryDate: expiryDate ?? this.expiryDate,
    batchNumber: batchNumber ?? this.batchNumber,
    imagePath: imagePath ?? this.imagePath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
