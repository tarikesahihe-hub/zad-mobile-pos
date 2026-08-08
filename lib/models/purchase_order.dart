class PurchaseOrderItem {
  final int? id;
  final int? orderId;
  final int? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;

  PurchaseOrderItem({
    this.id,
    this.orderId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) => PurchaseOrderItem(
        id: map['id'],
        orderId: map['order_id'],
        productId: map['product_id'],
        productName: map['product_name'],
        quantity: map['quantity'] ?? 0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total': total,
      };
}

class PurchaseOrder {
  final int? id;
  final int? supplierId;
  final String? supplierName;
  final DateTime date;
  final double total;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    this.id,
    this.supplierId,
    this.supplierName,
    required this.date,
    required this.total,
    this.status = 'received',
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) => PurchaseOrder(
        id: map['id'],
        supplierId: map['supplier_id'],
        supplierName: map['supplier_name'],
        date: DateTime.parse(map['date']),
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] ?? 'received',
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'date': date.toIso8601String(),
        'total': total,
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
