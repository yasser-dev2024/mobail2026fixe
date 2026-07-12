import 'package:uuid/uuid.dart';

class PurchaseModel {
  final String id;
  final String invoiceNumber;
  final String? supplierId;
  final String? supplierName;
  final double subtotal;
  final double tax;
  final double shipping;
  final double discount;
  final double total;
  final double amountPaid;
  final String paymentMethod;
  final String? notes;
  final String? createdBy;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final List<dynamic> items;

  const PurchaseModel({
    required this.id,
    required this.invoiceNumber,
    this.supplierId,
    this.supplierName,
    required this.subtotal,
    required this.tax,
    required this.shipping,
    required this.discount,
    required this.total,
    required this.amountPaid,
    required this.paymentMethod,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.items = const [],
  });

  factory PurchaseModel.create({
    required String invoiceNumber,
    String? supplierId,
    String? supplierName,
    double subtotal = 0.0,
    double tax = 0.0,
    double shipping = 0.0,
    double discount = 0.0,
    double total = 0.0,
    double amountPaid = 0.0,
    String paymentMethod = 'cash',
    String? notes,
    String? createdBy,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return PurchaseModel(
      id: const Uuid().v4(),
      invoiceNumber: invoiceNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      subtotal: subtotal,
      tax: tax,
      shipping: shipping,
      discount: discount,
      total: total,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      notes: notes,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      items: const [],
    );
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map['id'] as String,
      invoiceNumber: map['invoice_number'] as String,
      supplierId: map['supplier_id'] as String?,
      supplierName: map['supplier_name'] as String?,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      shipping: (map['shipping'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
      items: const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shipping,
      'discount': discount,
      'total': total,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  PurchaseModel copyWith({
    String? id,
    String? invoiceNumber,
    Object? supplierId = _sentinel,
    Object? supplierName = _sentinel,
    double? subtotal,
    double? tax,
    double? shipping,
    double? discount,
    double? total,
    double? amountPaid,
    String? paymentMethod,
    Object? notes = _sentinel,
    Object? createdBy = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
    List<dynamic>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierId:
          supplierId == _sentinel ? this.supplierId : supplierId as String?,
      supplierName: supplierName == _sentinel
          ? this.supplierName
          : supplierName as String?,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      shipping: shipping ?? this.shipping,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes == _sentinel ? this.notes : notes as String?,
      createdBy: createdBy == _sentinel ? this.createdBy : createdBy as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
      items: items ?? this.items,
    );
  }

  double get remainingBalance => total - amountPaid;
}

const _sentinel = Object();
