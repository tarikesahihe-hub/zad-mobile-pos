class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double discount;
  final double total;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0,
    required this.total,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
    id: map['id'],
    saleId: map['sale_id'],
    productId: map['product_id'],
    productName: map['product_name'],
    unitPrice: map['unit_price']?.toDouble() ?? 0.0,
    quantity: map['quantity'] ?? 0,
    discount: map['discount']?.toDouble() ?? 0.0,
    total: map['total']?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sale_id': saleId,
    'product_id': productId,
    'product_name': productName,
    'unit_price': unitPrice,
    'quantity': quantity,
    'discount': discount,
    'total': total,
  };
}

class Sale {
  final int? id;
  final String invoiceNumber;
  final DateTime date;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod;
  final int? customerId;
  final String? customerName;
  final String? notes;
  final String status;
  final List<SaleItem> items;
  final DateTime createdAt;

  Sale({
    this.id,
    required this.invoiceNumber,
    required this.date,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.paymentMethod = 'cash',
    this.customerId,
    this.customerName,
    this.notes,
    this.status = 'completed',
    this.items = const [],
    required this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
    id: map['id'],
    invoiceNumber: map['invoice_number'],
    date: DateTime.parse(map['date']),
    subtotal: map['subtotal']?.toDouble() ?? 0.0,
    discount: map['discount']?.toDouble() ?? 0.0,
    tax: map['tax']?.toDouble() ?? 0.0,
    total: map['total']?.toDouble() ?? 0.0,
    paymentMethod: map['payment_method'] ?? 'cash',
    customerId: map['customer_id'],
    customerName: map['customer_name'],
    notes: map['notes'],
    status: map['status'] ?? 'completed',
    createdAt: DateTime.parse(map['created_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoice_number': invoiceNumber,
    'date': date.toIso8601String(),
    'subtotal': subtotal,
    'discount': discount,
    'tax': tax,
    'total': total,
    'payment_method': paymentMethod,
    'customer_id': customerId,
    'customer_name': customerName,
    'notes': notes,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}
