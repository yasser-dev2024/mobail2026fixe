import 'package:uuid/uuid.dart';

class MaintenancePartModel {
  final String id;
  final String maintenanceId;
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double purchaseCost; // what the shop paid per unit (0 = unknown)
  final double totalPrice; // what the customer pays (unitPrice × qty)
  final int createdAt;

  const MaintenancePartModel({
    required this.id,
    required this.maintenanceId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.purchaseCost = 0.0,
    required this.totalPrice,
    required this.createdAt,
  });

  factory MaintenancePartModel.create({
    required String maintenanceId,
    String? productId,
    required String productName,
    required double quantity,
    required double unitPrice,
    double purchaseCost = 0.0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MaintenancePartModel(
      id: const Uuid().v4(),
      maintenanceId: maintenanceId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      purchaseCost: purchaseCost,
      totalPrice: quantity * unitPrice,
      createdAt: now,
    );
  }

  factory MaintenancePartModel.fromMap(Map<String, dynamic> map) {
    return MaintenancePartModel(
      id: map['id'] as String,
      maintenanceId: map['maintenance_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      purchaseCost: (map['purchase_cost'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num).toDouble(),
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'maintenance_id': maintenanceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'purchase_cost': purchaseCost,
      'total_price': totalPrice,
      'created_at': createdAt,
    };
  }

  // ── Profit helpers ─────────────────────────────────────────────────────────

  bool get hasCostData => purchaseCost > 0;

  double get profitPerUnit => unitPrice - purchaseCost;

  double get totalCost => purchaseCost * quantity;

  double get totalProfit => profitPerUnit * quantity;

  double get profitMarginPct =>
      purchaseCost > 0 ? (profitPerUnit / purchaseCost) * 100 : 0;

  // ── Mutation ───────────────────────────────────────────────────────────────

  MaintenancePartModel copyWith({
    String? id,
    String? maintenanceId,
    Object? productId = _sentinel,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? purchaseCost,
    double? totalPrice,
    int? createdAt,
  }) {
    return MaintenancePartModel(
      id: id ?? this.id,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      productId: productId == _sentinel ? this.productId : productId as String?,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenancePartModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MaintenancePartModel(id: $id, productName: $productName, qty: $quantity, unitPrice: $unitPrice, purchaseCost: $purchaseCost)';
}

const Object _sentinel = Object();
