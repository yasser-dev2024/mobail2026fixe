import '../../../core/database/database_service.dart';
import 'device_identity.dart';
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
    final existing = await findMatchingDevice(
      customerId: device.customerId,
      brand: device.brand,
      model: device.model,
      imei: device.imei,
      serialNumber: device.serialNumber,
      color: device.color,
    );
    if (existing != null) {
      if (existing.customerId != device.customerId) {
        throw Exception(
          'هذا الجوال مسجل لعميل آخر. راجع رقم IMEI أو الرقم التسلسلي.',
        );
      }
      return existing.id;
    }

    final shopId = await _db.getCurrentShopId();
    try {
      final id = await _db.insert('devices', {
        ...device.toMap(),
        'shop_id': shopId,
      });
      return id ?? device.id;
    } catch (error) {
      if (!error.toString().contains('DUPLICATE_DEVICE')) rethrow;
      final raced = await findMatchingDevice(
        customerId: device.customerId,
        brand: device.brand,
        model: device.model,
        imei: device.imei,
        serialNumber: device.serialNumber,
        color: device.color,
      );
      if (raced == null || raced.customerId != device.customerId) rethrow;
      return raced.id;
    }
  }

  Future<void> update(DeviceModel device) async {
    final duplicate = await findMatchingDevice(
      customerId: device.customerId,
      brand: device.brand,
      model: device.model,
      imei: device.imei,
      serialNumber: device.serialNumber,
      color: device.color,
      excludingDeviceId: device.id,
    );
    if (duplicate != null) {
      throw Exception(
        duplicate.customerId == device.customerId
            ? 'هذا الجوال مسجل مسبقاً في ملف العميل.'
            : 'هذا الجوال مسجل لعميل آخر. راجع رقم IMEI أو الرقم التسلسلي.',
      );
    }

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
    final normalized = normalizeDeviceIdentityPart(imei);
    if (normalized.isEmpty) return null;
    final devices = await getAll();
    for (final device in devices) {
      if (normalizeDeviceIdentityPart(device.imei) == normalized) {
        return device;
      }
    }
    return null;
  }

  Future<DeviceModel?> findMatchingDevice({
    required String customerId,
    required String brand,
    required String model,
    String? imei,
    String? serialNumber,
    String? color,
    String? excludingDeviceId,
  }) async {
    final devices = await getAll();
    for (final device in devices) {
      if (device.id == excludingDeviceId) continue;
      if (isSamePhysicalDevice(
        firstCustomerId: customerId,
        firstBrand: brand,
        firstModel: model,
        firstImei: imei,
        firstSerialNumber: serialNumber,
        firstColor: color,
        secondCustomerId: device.customerId,
        secondBrand: device.brand,
        secondModel: device.model,
        secondImei: device.imei,
        secondSerialNumber: device.serialNumber,
        secondColor: device.color,
      )) {
        return device;
      }
    }
    return null;
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
