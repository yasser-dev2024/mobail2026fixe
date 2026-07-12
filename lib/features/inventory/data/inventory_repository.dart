import '../../../core/database/database_service.dart';
import 'product_model.dart';

class InventoryRepository {
  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // LIST
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getAll({
    String? categoryKey,
    String? search,
    bool? lowStock,
    bool? outOfStock,
  }) async {
    final buffer = StringBuffer('''
SELECT p.*, s.name AS supplier_name
FROM products p
LEFT JOIN suppliers s ON p.supplier_id = s.id
WHERE p.deleted_at IS NULL AND p.is_active = 1
''');

    final args = <dynamic>[];

    if (categoryKey != null && categoryKey.isNotEmpty) {
      buffer.write(' AND p.category_key = ?');
      args.add(categoryKey);
    }

    if (search != null && search.isNotEmpty) {
      buffer.write(
          ' AND (p.name LIKE ? OR p.barcode LIKE ? OR p.description LIKE ?)');
      final s = '%$search%';
      args.addAll([s, s, s]);
    }

    if (outOfStock == true) {
      buffer.write(' AND p.quantity <= 0 AND p.is_service = 0');
    } else if (lowStock == true) {
      buffer.write(
          ' AND p.quantity > 0 AND p.quantity <= p.low_stock_threshold AND p.is_service = 0');
    }

    buffer.write(' ORDER BY p.name ASC');

    final rows =
        await _db.rawQuery(buffer.toString(), args.isEmpty ? null : args);
    return rows.map(ProductModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // SINGLE
  // ---------------------------------------------------------------------------

  Future<ProductModel?> getById(String id) async {
    final rows = await _db.rawQuery('''
SELECT p.*, s.name AS supplier_name
FROM products p
LEFT JOIN suppliers s ON p.supplier_id = s.id
WHERE p.id = ? AND p.deleted_at IS NULL
LIMIT 1
''', [id]);
    if (rows.isEmpty) return null;
    return ProductModel.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // CREATE / UPDATE / DELETE
  // ---------------------------------------------------------------------------

  Future<String> create(ProductModel product) async {
    final map = product.toMap();
    final id = await _db.insert('products', map);
    return id ?? product.id;
  }

  Future<void> update(ProductModel product) async {
    final map = product.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _db.update('products', map, product.id);
  }

  Future<void> delete(String id) async {
    await _db.softDelete('products', id);
  }

  // ---------------------------------------------------------------------------
  // QUANTITY MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Decreases [productId] quantity by [qty].
  /// Throws [Exception] if current quantity is less than [qty].
  Future<void> decreaseQuantity(String productId, int qty) async {
    final product = await getById(productId);
    if (product == null) {
      throw Exception('المنتج غير موجود');
    }
    if (product.quantity < qty) {
      throw Exception(
          'الكمية المطلوبة ($qty) أكبر من المخزون المتاح (${product.quantity})');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE products SET quantity = quantity - ?, updated_at = ? WHERE id = ?',
      [qty, now, productId],
    );
  }

  Future<void> increaseQuantity(String productId, int qty) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
      [qty, now, productId],
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERED QUERIES
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> getLowStockProducts() async {
    final rows = await _db.rawQuery('''
SELECT p.*, s.name AS supplier_name
FROM products p
LEFT JOIN suppliers s ON p.supplier_id = s.id
WHERE p.deleted_at IS NULL
  AND p.quantity > 0
  AND p.quantity <= p.low_stock_threshold
  AND p.is_service = 0
ORDER BY p.quantity ASC
''');
    return rows.map(ProductModel.fromMap).toList();
  }

  Future<List<ProductModel>> getOutOfStockProducts() async {
    final rows = await _db.rawQuery('''
SELECT p.*, s.name AS supplier_name
FROM products p
LEFT JOIN suppliers s ON p.supplier_id = s.id
WHERE p.deleted_at IS NULL
  AND p.quantity <= 0
  AND p.is_service = 0
  AND p.is_active = 1
ORDER BY p.name ASC
''');
    return rows.map(ProductModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // STATS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getStats() async {
    final totalRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM products WHERE deleted_at IS NULL AND is_active = 1',
    );
    final lowRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM products WHERE deleted_at IS NULL AND is_active = 1 AND is_service = 0 AND quantity > 0 AND quantity <= low_stock_threshold',
    );
    final outRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM products WHERE deleted_at IS NULL AND is_active = 1 AND is_service = 0 AND quantity <= 0',
    );
    final valueRow = await _db.rawQuery(
      'SELECT COALESCE(SUM(CAST(quantity AS REAL) * sale_price), 0) AS total_value FROM products WHERE deleted_at IS NULL AND is_active = 1 AND is_service = 0',
    );

    return {
      'totalProducts': (totalRow.first['cnt'] as int? ?? 0),
      'lowStock': (lowRow.first['cnt'] as int? ?? 0),
      'outOfStock': (outRow.first['cnt'] as int? ?? 0),
      'totalValue': (valueRow.first['total_value'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String getCategoryLabel(String key) {
    switch (key) {
      case 'phones':
        return 'جوالات';
      case 'screens':
        return 'شاشات';
      case 'batteries':
        return 'بطاريات';
      case 'chargers':
        return 'شواحن';
      case 'earphones':
        return 'سماعات';
      case 'cases':
        return 'كفرات';
      case 'spare_parts':
        return 'قطع غيار';
      case 'services':
        return 'خدمات';
      case 'other':
        return 'أخرى';
      default:
        return key;
    }
  }
}
