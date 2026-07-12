import 'package:uuid/uuid.dart';

class SaleItemModel {
  final String id;
  final String saleId;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double totalPrice;

  const SaleItemModel({
    required this.id,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.totalPrice,
  });

  factory SaleItemModel.create({
    required String saleId,
    String? productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    double discount = 0.0,
    required double totalPrice,
  }) {
    return SaleItemModel(
      id: const Uuid().v4(),
      saleId: saleId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount,
      totalPrice: totalPrice,
    );
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'total_price': totalPrice,
    };
  }

  SaleItemModel copyWith({
    String? id,
    String? saleId,
    Object? productId = _sentinel,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? totalPrice,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId == _sentinel ? this.productId : productId as String?,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

const _sentinel = Object();
