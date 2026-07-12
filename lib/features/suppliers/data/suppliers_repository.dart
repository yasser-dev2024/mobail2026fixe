import '../../../core/database/database_service.dart';
import 'supplier_model.dart';

class SuppliersRepository {
  final DatabaseService _db = DatabaseService();

  Future<List<SupplierModel>> getAll({String? search}) async {
    final buffer = StringBuffer(
      'SELECT * FROM suppliers WHERE deleted_at IS NULL AND is_active = 1',
    );

    final args = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      buffer.write(' AND (name LIKE ? OR phone LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }

    buffer.write(' ORDER BY name ASC');

    final rows = await _db.rawQuery(
      buffer.toString(),
      args.isEmpty ? null : args,
    );
    return rows.map(SupplierModel.fromMap).toList();
  }

  Future<SupplierModel?> getById(String id) async {
    final map = await _db.queryOne('suppliers', id);
    if (map == null) return null;
    return SupplierModel.fromMap(map);
  }

  Future<String> create(SupplierModel supplier) async {
    final map = supplier.toMap();
    final id = await _db.insert('suppliers', map);
    return id ?? supplier.id;
  }

  Future<void> update(SupplierModel supplier) async {
    final map = supplier.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _db.update('suppliers', map, supplier.id);
  }

  Future<void> delete(String id) async {
    await _db.softDelete('suppliers', id);
  }

  Future<void> updateBalance(String supplierId, double amount) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE suppliers SET balance = balance + ?, updated_at = ? WHERE id = ?',
      [amount, now, supplierId],
    );
  }
}
