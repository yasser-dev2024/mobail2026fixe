import '../../../core/database/database_service.dart';
import 'customer_model.dart';

class CustomersRepository {
  final DatabaseService _db = DatabaseService();

  static final CustomersRepository _instance = CustomersRepository._internal();
  factory CustomersRepository() => _instance;
  CustomersRepository._internal();

  Future<List<CustomerModel>> getAll({
    String? search,
    String? customerType,
  }) async {
    final shopId = await _db.getCurrentShopId();
    final conditions = <String>['shop_id = ?', 'deleted_at IS NULL'];
    final args = <dynamic>[shopId];

    if (search != null && search.isNotEmpty) {
      conditions.add('(name LIKE ? OR phone LIKE ? OR phone2 LIKE ?)');
      final pattern = '%$search%';
      args.addAll([pattern, pattern, pattern]);
    }

    if (customerType != null && customerType.isNotEmpty) {
      conditions.add('customer_type = ?');
      args.add(customerType);
    }

    final rows = await _db.query(
      'customers',
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<CustomerModel?> getById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'customers',
      where: 'shop_id = ? AND id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CustomerModel.fromMap(rows.first);
  }

  Future<String> create(CustomerModel customer) async {
    final shopId = await _db.getCurrentShopId();
    final id = await _db.insert('customers', {
      ...customer.toMap(),
      'shop_id': shopId,
    });
    return id ?? customer.id;
  }

  Future<void> update(CustomerModel customer) async {
    final shopId = await _db.getCurrentShopId();
    final updated = customer.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.rawUpdate(
      'UPDATE customers SET name = ?, phone = ?, phone2 = ?, email = ?, '
      'address = ?, notes = ?, customer_type = ?, total_spent = ?, '
      'visit_count = ?, last_visit = ?, updated_at = ?, deleted_at = ? '
      'WHERE shop_id = ? AND id = ?',
      [
        updated.name,
        updated.phone,
        updated.phone2,
        updated.email,
        updated.address,
        updated.notes,
        updated.customerType,
        updated.totalSpent,
        updated.visitCount,
        updated.lastVisit,
        updated.updatedAt,
        updated.deletedAt,
        shopId,
        updated.id,
      ],
    );
  }

  Future<void> delete(String id) async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.rawUpdate(
      'UPDATE devices '
      'SET deleted_at = ?, updated_at = ? '
      'WHERE shop_id = ? AND customer_id = ? AND deleted_at IS NULL',
      [now, now, shopId, id],
    );
    await _db.rawUpdate(
      'UPDATE customers '
      'SET deleted_at = ?, updated_at = ? '
      'WHERE shop_id = ? AND id = ? AND deleted_at IS NULL',
      [now, now, shopId, id],
    );
  }

  Future<void> updateStats(String customerId, double amount) async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE customers '
      'SET total_spent = total_spent + ?, '
      '    visit_count = visit_count + 1, '
      '    last_visit  = ?, '
      '    updated_at  = ? '
      'WHERE shop_id = ? AND id = ?',
      [amount, now, now, shopId, customerId],
    );
  }

  Future<List<CustomerModel>> getTopCustomers(int limit) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'customers',
      where: 'shop_id = ? AND deleted_at IS NULL',
      whereArgs: [shopId],
      orderBy: 'total_spent DESC',
      limit: limit,
    );
    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<Map<String, dynamic>> getStats() async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final totalResult = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM customers WHERE shop_id = ? AND deleted_at IS NULL',
      [shopId],
    );
    final vipResult = await _db.rawQuery(
      "SELECT COUNT(*) as cnt FROM customers WHERE shop_id = ? AND deleted_at IS NULL AND customer_type = 'vip'",
      [shopId],
    );
    final newResult = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM customers WHERE shop_id = ? AND deleted_at IS NULL AND created_at >= ?',
      [shopId, startOfMonth],
    );

    return {
      'total': (totalResult.first['cnt'] as int?) ?? 0,
      'vip': (vipResult.first['cnt'] as int?) ?? 0,
      'newThisMonth': (newResult.first['cnt'] as int?) ?? 0,
    };
  }
}
