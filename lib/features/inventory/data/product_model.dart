import 'package:uuid/uuid.dart';

class ProductModel {
  final String id;
  final String? categoryKey;
  final String name;
  final String? barcode;
  final String? description;
  final String? imagePath;
  final int quantity;
  final int lowStockThreshold;
  final double purchasePrice;
  final double salePrice;
  final String? supplierId;
  final int warrantyDays;
  final bool isService;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  // Optional join field
  final String? supplierName;

  const ProductModel({
    required this.id,
    this.categoryKey,
    required this.name,
    this.barcode,
    this.description,
    this.imagePath,
    required this.quantity,
    required this.lowStockThreshold,
    required this.purchasePrice,
    required this.salePrice,
    this.supplierId,
    required this.warrantyDays,
    required this.isService,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.supplierName,
  });

  factory ProductModel.create({
    String? categoryKey,
    required String name,
    String? barcode,
    String? description,
    String? imagePath,
    int quantity = 0,
    int lowStockThreshold = 5,
    double purchasePrice = 0.0,
    double salePrice = 0.0,
    String? supplierId,
    int warrantyDays = 0,
    bool isService = false,
    bool isActive = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ProductModel(
      id: const Uuid().v4(),
      categoryKey: categoryKey,
      name: name,
      barcode: barcode,
      description: description,
      imagePath: imagePath,
      quantity: quantity,
      lowStockThreshold: lowStockThreshold,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      supplierId: supplierId,
      warrantyDays: warrantyDays,
      isService: isService,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      categoryKey: map['category_key'] as String?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      quantity: map['quantity'] as int? ?? 0,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0.0,
      supplierId: map['supplier_id'] as String?,
      warrantyDays: map['warranty_days'] as int? ?? 0,
      isService: (map['is_service'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
      supplierName: map['supplier_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_key': categoryKey,
      'name': name,
      'barcode': barcode,
      'description': description,
      'image_path': imagePath,
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'supplier_id': supplierId,
      'warranty_days': warrantyDays,
      'is_service': isService ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  ProductModel copyWith({
    String? id,
    Object? categoryKey = _sentinel,
    String? name,
    Object? barcode = _sentinel,
    Object? description = _sentinel,
    Object? imagePath = _sentinel,
    int? quantity,
    int? lowStockThreshold,
    double? purchasePrice,
    double? salePrice,
    Object? supplierId = _sentinel,
    int? warrantyDays,
    bool? isService,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
    Object? supplierName = _sentinel,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryKey:
          categoryKey == _sentinel ? this.categoryKey : categoryKey as String?,
      name: name ?? this.name,
      barcode: barcode == _sentinel ? this.barcode : barcode as String?,
      description:
          description == _sentinel ? this.description : description as String?,
      imagePath: imagePath == _sentinel ? this.imagePath : imagePath as String?,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      supplierId:
          supplierId == _sentinel ? this.supplierId : supplierId as String?,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      isService: isService ?? this.isService,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
      supplierName: supplierName == _sentinel
          ? this.supplierName
          : supplierName as String?,
    );
  }

  bool get isLowStock => quantity > 0 && quantity <= lowStockThreshold;

  bool get isOutOfStock => quantity <= 0 && !isService;

  double get profit => salePrice - purchasePrice;

  double get profitMargin =>
      purchasePrice > 0 ? (profit / purchasePrice) * 100 : 0;

  String get categoryLabel {
    switch (categoryKey) {
      case 'phones':
        return 'هواتف';
      case 'screens':
        return 'شاشات';
      case 'batteries':
        return 'بطاريات';
      case 'chargers':
        return 'شواحن';
      case 'earphones':
        return 'سماعات';
      case 'cases':
        return 'حافظات';
      case 'spare_parts':
        return 'قطع غيار';
      case 'services':
        return 'خدمات';
      case 'other':
        return 'أخرى';
      default:
        return categoryKey ?? 'أخرى';
    }
  }
}

// Sentinel object for nullable copyWith parameters
const _sentinel = Object();
