import 'package:uuid/uuid.dart';

class SaleModel {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String? customerName;
  final String? maintenanceId;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double amountPaid;
  final double changeAmount;
  final String paymentMethod;
  final bool isCredit;
  final String? notes;
  final String? createdBy;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final List<dynamic> items;

  const SaleModel({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.maintenanceId,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.amountPaid,
    required this.changeAmount,
    required this.paymentMethod,
    required this.isCredit,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.items = const [],
  });

  factory SaleModel.create({
    required String invoiceNumber,
    String? customerId,
    String? customerName,
    String? maintenanceId,
    double subtotal = 0.0,
    double discount = 0.0,
    double tax = 0.0,
    double total = 0.0,
    double amountPaid = 0.0,
    double changeAmount = 0.0,
    String paymentMethod = 'cash',
    bool isCredit = false,
    String? notes,
    String? createdBy,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return SaleModel(
      id: const Uuid().v4(),
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      maintenanceId: maintenanceId,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      paymentMethod: paymentMethod,
      isCredit: isCredit,
      notes: notes,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      items: const [],
    );
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id'] as String,
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      maintenanceId: map['maintenance_id'] as String?,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (map['change_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      isCredit: (map['is_credit'] as int? ?? 0) == 1,
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
      'customer_id': customerId,
      'customer_name': customerName,
      'maintenance_id': maintenanceId,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'is_credit': isCredit ? 1 : 0,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  SaleModel copyWith({
    String? id,
    String? invoiceNumber,
    Object? customerId = _sentinel,
    Object? customerName = _sentinel,
    Object? maintenanceId = _sentinel,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    double? amountPaid,
    double? changeAmount,
    String? paymentMethod,
    bool? isCredit,
    Object? notes = _sentinel,
    Object? createdBy = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
    List<dynamic>? items,
  }) {
    return SaleModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId:
          customerId == _sentinel ? this.customerId : customerId as String?,
      customerName: customerName == _sentinel
          ? this.customerName
          : customerName as String?,
      maintenanceId: maintenanceId == _sentinel
          ? this.maintenanceId
          : maintenanceId as String?,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isCredit: isCredit ?? this.isCredit,
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
