import '../../../core/database/database_service.dart';
import 'device_model.dart';

class DevicesRepository {
  final DatabaseService _db = DatabaseService();

  static final DevicesRepository _instance = DevicesRepository._internal();
  factory DevicesRepository() => _instance;
  DevicesRepository._internal();

  Future<List<DeviceModel>> getByCustomer(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'devices',
      where: 'shop_id = ? AND customer_id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(DeviceModel.fromMap).toList();
  }

  Future<DeviceModel?> getById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'devices',
      where: 'shop_id = ? AND id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DeviceModel.fromMap(rows.first);
  }

  Future<String> create(DeviceModel device) async {
    final shopId = await _db.getCurrentShopId();
    final id = await _db.insert('devices', {
      ...device.toMap(),
      'shop_id': shopId,
    });
    return id ?? device.id;
  }

  Future<void> update(DeviceModel device) async {
    final shopId = await _db.getCurrentShopId();
    final updated = device.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.rawUpdate(
      'UPDATE devices SET customer_id = ?, brand = ?, model = ?, imei = ?, '
      'serial_number = ?, color = ?, storage = ?, image_path = ?, notes = ?, '
      'updated_at = ?, deleted_at = ? WHERE shop_id = ? AND id = ?',
      [
        updated.customerId,
        updated.brand,
        updated.model,
        updated.imei,
        updated.serialNumber,
        updated.color,
        updated.storage,
        updated.imagePath,
        updated.notes,
        updated.updatedAt,
        updated.deletedAt,
        shopId,
        updated.id,
      ],
    );
  }

  Future<void> delete(String id) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawUpdate(
      'UPDATE devices SET deleted_at = ? WHERE shop_id = ? AND id = ?',
      [DateTime.now().millisecondsSinceEpoch, shopId, id],
    );
  }

  Future<DeviceModel?> searchByImei(String imei) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'devices',
      where: 'shop_id = ? AND imei = ? AND deleted_at IS NULL',
      whereArgs: [shopId, imei],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DeviceModel.fromMap(rows.first);
  }

  Future<List<DeviceModel>> getAll({String? search}) async {
    final shopId = await _db.getCurrentShopId();
    final conditions = <String>['shop_id = ?', 'deleted_at IS NULL'];
    final args = <dynamic>[shopId];

    if (search != null && search.isNotEmpty) {
      conditions.add(
        '(brand LIKE ? OR model LIKE ? OR imei LIKE ? OR serial_number LIKE ?)',
      );
      final pattern = '%$search%';
      args.addAll([pattern, pattern, pattern, pattern]);
    }

    final rows = await _db.query(
      'devices',
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(DeviceModel.fromMap).toList();
  }
}
