import 'package:uuid/uuid.dart';

class PurchaseItemModel {
  final String id;
  final String purchaseId;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory PurchaseItemModel.create({
    required String purchaseId,
    String? productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    required double totalPrice,
  }) {
    return PurchaseItemModel(
      id: const Uuid().v4(),
      purchaseId: purchaseId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  PurchaseItemModel copyWith({
    String? id,
    String? purchaseId,
    Object? productId = _sentinel,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return PurchaseItemModel(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId == _sentinel ? this.productId : productId as String?,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

const _sentinel = Object();
