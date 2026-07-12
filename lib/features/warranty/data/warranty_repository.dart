import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import 'warranty_model.dart';
import 'warranty_claim_model.dart';

class WarrantyRepository {
  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // LIST
  // ---------------------------------------------------------------------------

  /// Returns all warranty records.
  ///
  /// [status] can be:
  ///   - 'active'   : end_date >= now AND is_void = 0
  ///   - 'expiring' : end_date between now and now+7days AND is_void = 0
  ///   - 'expired'  : end_date < now OR is_void = 1
  Future<List<WarrantyModel>> getAll({
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    await syncFromMaintenance();
    final shopId = await _db.getCurrentShopId();

    final conditions = <String>['w.shop_id = ?'];
    final args = <dynamic>[shopId];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysMs = const Duration(days: 7).inMilliseconds;

    if (status != null && status.isNotEmpty) {
      switch (status) {
        case 'active':
          conditions
              .add('w.end_date >= ? AND w.is_void = 0 AND w.end_date - ? > ?');
          args.addAll([nowMs, nowMs, sevenDaysMs]);
          break;
        case 'expiring':
          conditions
              .add('w.end_date >= ? AND w.end_date - ? <= ? AND w.is_void = 0');
          args.addAll([nowMs, nowMs, sevenDaysMs]);
          break;
        case 'expired':
          conditions.add('(w.end_date < ? OR w.is_void = 1)');
          args.add(nowMs);
          break;
      }
    }

    if (from != null) {
      conditions.add('w.start_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('w.start_date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final whereClause = 'AND ${conditions.join(' AND ')}';

    final rows = await _db.rawQuery('''
SELECT w.*, c.name AS customer_name, m.ticket_number
FROM warranties w
LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
LEFT JOIN maintenance m ON w.maintenance_id = m.id AND m.shop_id = w.shop_id
LEFT JOIN devices d ON m.device_id = d.id AND d.shop_id = w.shop_id
WHERE (w.customer_id IS NULL OR c.deleted_at IS NULL)
  AND (w.maintenance_id IS NULL OR m.deleted_at IS NULL)
  AND (m.device_id IS NULL OR d.deleted_at IS NULL)
  $whereClause
ORDER BY w.end_date ASC
''', args.isEmpty ? null : args);

    return rows.map(WarrantyModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // SINGLE
  // ---------------------------------------------------------------------------

  Future<WarrantyModel?> getById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT w.*, c.name AS customer_name, m.ticket_number
FROM warranties w
LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
LEFT JOIN maintenance m ON w.maintenance_id = m.id AND m.shop_id = w.shop_id
WHERE w.shop_id = ? AND w.id = ?
LIMIT 1
''', [shopId, id]);
    if (rows.isEmpty) return null;
    return WarrantyModel.fromMap(rows.first);
  }

  Future<WarrantyModel?> getByMaintenance(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT w.*, c.name AS customer_name, m.ticket_number
FROM warranties w
LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
LEFT JOIN maintenance m ON w.maintenance_id = m.id AND m.shop_id = w.shop_id
WHERE w.shop_id = ? AND w.maintenance_id = ?
ORDER BY w.created_at DESC
LIMIT 1
''', [shopId, maintenanceId]);
    if (rows.isEmpty) return null;
    return WarrantyModel.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // CREATE / UPDATE
  // ---------------------------------------------------------------------------

  Future<String> create(WarrantyModel warranty) async {
    final shopId = await _db.getCurrentShopId();
    final id = warranty.id.isNotEmpty ? warranty.id : const Uuid().v4();
    final data = warranty.toMap();
    data['id'] = id;
    data['shop_id'] = shopId;
    await _db.insert('warranties', data);
    return id;
  }

  Future<void> update(WarrantyModel warranty) async {
    final shopId = await _db.getCurrentShopId();
    final data = warranty.toMap();
    data['shop_id'] = shopId;
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE warranties SET maintenance_id = ?, customer_id = ?, device_info = ?, '
      'warranty_type = ?, warranty_days = ?, start_date = ?, end_date = ?, '
      'notes = ?, is_void = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
      [
        data['maintenance_id'],
        data['customer_id'],
        data['device_info'],
        data['warranty_type'],
        data['warranty_days'],
        data['start_date'],
        data['end_date'],
        data['notes'],
        data['is_void'],
        data['updated_at'],
        shopId,
        warranty.id,
      ],
    );
  }

  Future<void> voidWarranty(String id) async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE warranties SET is_void = 1, updated_at = ? WHERE shop_id = ? AND id = ?',
      [now, shopId, id],
    );
  }

  // ---------------------------------------------------------------------------
  // CLAIMS
  // ---------------------------------------------------------------------------

  Future<void> addClaim(WarrantyClaimModel claim) async {
    final shopId = await _db.getCurrentShopId();
    await _db.insert('warranty_claims', {
      ...claim.toMap(),
      'shop_id': shopId,
    });
  }

  Future<List<WarrantyClaimModel>> getClaims(String warrantyId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'warranty_claims',
      where: 'shop_id = ? AND warranty_id = ?',
      whereArgs: [shopId, warrantyId],
      orderBy: 'created_at DESC',
    );
    return rows.map(WarrantyClaimModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // STATS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getStats() async {
    await syncFromMaintenance();
    final shopId = await _db.getCurrentShopId();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysMs = const Duration(days: 7).inMilliseconds;

    final activeRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM warranties WHERE shop_id = ? AND is_void = 0 AND end_date >= ? AND (end_date - ?) > ?',
      [shopId, nowMs, nowMs, sevenDaysMs],
    );
    final expiringRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM warranties WHERE shop_id = ? AND is_void = 0 AND end_date >= ? AND (end_date - ?) <= ?',
      [shopId, nowMs, nowMs, sevenDaysMs],
    );
    final expiredRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM warranties WHERE shop_id = ? AND (is_void = 1 OR end_date < ?)',
      [shopId, nowMs],
    );

    return {
      'active': (activeRow.first['cnt'] as int? ?? 0),
      'expiringSoon': (expiringRow.first['cnt'] as int? ?? 0),
      'expired': (expiredRow.first['cnt'] as int? ?? 0),
    };
  }

  Future<void> syncFromMaintenance() async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*
FROM maintenance m
WHERE m.shop_id = ?
  AND m.deleted_at IS NULL
''', [shopId]);

    for (final row in rows) {
      final type = row['warranty_type'] as String?;
      final days = _warrantyDays(type, row['warranty_days'] as int?);
      final maintenanceId = row['id'] as String;
      if (type == null ||
          type == AppConstants.warrantyNone ||
          days <= 0 ||
          (row['warranty_start'] == null && row['delivered_at'] == null) ||
          row['deleted_at'] != null ||
          row['status'] == AppConstants.statusCancelled) {
        await _db.rawUpdate(
          'UPDATE warranties SET is_void = 1, updated_at = ? WHERE shop_id = ? AND maintenance_id = ?',
          [DateTime.now().millisecondsSinceEpoch, shopId, maintenanceId],
        );
        continue;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final start =
          row['warranty_start'] as int? ?? row['delivered_at'] as int?;
      if (start == null) continue;
      final end = row['warranty_end'] as int? ??
          DateTime.fromMillisecondsSinceEpoch(start)
              .add(Duration(days: days))
              .millisecondsSinceEpoch;
      final brand = row['brand'] as String? ?? '';
      final model = row['model'] as String? ?? '';
      final imei = row['imei'] as String?;
      final deviceInfo = [
        brand,
        model,
        if (imei != null && imei.isNotEmpty) 'IMEI: $imei',
      ].join(' ').trim();

      final existing = await _db.rawQuery(
        'SELECT id, created_at FROM warranties WHERE shop_id = ? AND maintenance_id = ? LIMIT 1',
        [shopId, maintenanceId],
      );
      final warrantyId =
          existing.isEmpty ? const Uuid().v4() : existing.first['id'] as String;
      final createdAt = existing.isEmpty
          ? row['created_at'] as int? ?? now
          : existing.first['created_at'] as int? ?? now;

      final data = {
        'id': warrantyId,
        'shop_id': shopId,
        'maintenance_id': maintenanceId,
        'customer_id': row['customer_id'],
        'device_info': deviceInfo.isEmpty ? 'Device' : deviceInfo,
        'warranty_type': type,
        'warranty_days': days,
        'start_date': start,
        'end_date': end,
        'notes': row['notes'],
        'is_void': 0,
        'created_at': createdAt,
        'updated_at': now,
      };

      if (existing.isEmpty) {
        await _db.insert('warranties', data);
      } else {
        await _db.update('warranties', data, warrantyId);
      }
    }
  }

  int _warrantyDays(String? type, int? customDays) {
    switch (type) {
      case AppConstants.warranty7Days:
        return 7;
      case AppConstants.warranty30Days:
        return 30;
      case AppConstants.warranty90Days:
        return 90;
      case AppConstants.warranty6Months:
        return 180;
      case AppConstants.warranty1Year:
        return 365;
      case AppConstants.warranty2Years:
        return AppConstants.warrantyMaxDays;
      case AppConstants.warrantyCustom:
        return AppConstants.clampWarrantyDays(customDays ?? 30);
      default:
        return 0;
    }
  }
}
