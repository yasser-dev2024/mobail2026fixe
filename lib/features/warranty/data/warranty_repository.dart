import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../auth/data/auth_repository.dart';
import 'warranty_action_model.dart';
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
SELECT w.*, c.name AS customer_name, c.phone AS customer_phone, m.ticket_number
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
SELECT w.*, c.name AS customer_name, c.phone AS customer_phone, m.ticket_number
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
SELECT w.*, c.name AS customer_name, c.phone AS customer_phone, m.ticket_number
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

  Future<WarrantyAlertDetails?> getAlertDetails(String warrantyId) async {
    await syncFromMaintenance();
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT w.*,
       c.name AS customer_name,
       c.phone AS customer_phone,
       m.ticket_number,
       m.status AS maintenance_status,
       m.brand AS maintenance_brand,
       m.model AS maintenance_model,
       i.invoice_number
FROM warranties w
LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
LEFT JOIN maintenance m ON w.maintenance_id = m.id AND m.shop_id = w.shop_id
LEFT JOIN invoices i ON i.maintenance_id = m.id
  AND i.shop_id = w.shop_id
  AND i.status != ?
WHERE w.shop_id = ? AND w.id = ?
ORDER BY i.created_at DESC
LIMIT 1
''', [AppConstants.invoiceCancelled, shopId, warrantyId]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final warranty = WarrantyModel.fromMap(row);
    final actions = await getActions(warrantyId);
    final deviceName = [
      row['maintenance_brand'] as String? ?? '',
      row['maintenance_model'] as String? ?? '',
    ].join(' ').trim();

    return WarrantyAlertDetails(
      warranty: warranty,
      customerName: row['customer_name'] as String? ?? 'العميل',
      customerPhone: row['customer_phone'] as String? ?? '',
      deviceName: deviceName.isEmpty ? warranty.deviceInfo : deviceName,
      invoiceNumber: row['invoice_number'] as String?,
      maintenanceStatus: row['maintenance_status'] as String? ?? '',
      actions: actions,
    );
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
    await recordAction(
      warrantyId: id,
      maintenanceId: warranty.maintenanceId,
      action: 'created',
      newValue: '${warranty.warrantyDays} يوم',
    );
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
      'notes = ?, is_void = ?, alert_disabled = ?, alert_disabled_reason = ?, '
      'alert_disabled_at = ?, alert_disabled_by = ?, expiry_approved = ?, '
      'expiry_approved_at = ?, expiry_approved_by = ?, updated_at = ? '
      'WHERE shop_id = ? AND id = ?',
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
        data['alert_disabled'],
        data['alert_disabled_reason'],
        data['alert_disabled_at'],
        data['alert_disabled_by'],
        data['expiry_approved'],
        data['expiry_approved_at'],
        data['expiry_approved_by'],
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

  Future<List<WarrantyActionModel>> getActions(String warrantyId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'warranty_actions',
      where: 'shop_id = ? AND warranty_id = ?',
      whereArgs: [shopId, warrantyId],
      orderBy: 'created_at DESC',
    );
    return rows.map(WarrantyActionModel.fromMap).toList();
  }

  Future<void> recordAction({
    required String warrantyId,
    String? maintenanceId,
    required String action,
    String? oldValue,
    String? newValue,
    String? notes,
  }) async {
    final shopId = await _db.getCurrentShopId();
    final user = AuthRepository().getCurrentUser();
    await _db.insert(
      'warranty_actions',
      WarrantyActionModel.create(
        warrantyId: warrantyId,
        maintenanceId: maintenanceId,
        action: action,
        oldValue: oldValue,
        newValue: newValue,
        userId: user?.id,
        username: user?.username ?? user?.name ?? 'النظام',
        notes: notes,
      ).toMap()
        ..['shop_id'] = shopId,
    );
  }

  Future<void> disableAlert(String warrantyId, {String? reason}) async {
    final warranty = await getById(warrantyId);
    if (warranty == null) throw Exception('الضمان غير موجود.');
    final user = AuthRepository().getCurrentUser();
    final username = user?.username ?? user?.name ?? 'النظام';
    final now = DateTime.now().millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    await _db.rawUpdate(
      '''
UPDATE warranties
SET alert_disabled = 1,
    alert_disabled_reason = ?,
    alert_disabled_at = ?,
    alert_disabled_by = ?,
    updated_at = ?
WHERE shop_id = ? AND id = ?
''',
      [reason, now, username, now, shopId, warrantyId],
    );
    await _deleteWarrantyNotifications(warrantyId);
    await recordAction(
      warrantyId: warrantyId,
      maintenanceId: warranty.maintenanceId,
      action: 'alert_disabled',
      notes: reason,
    );
  }

  Future<WarrantyModel> renewWarranty({
    required String warrantyId,
    required int duration,
    required String unit,
    required int startDate,
    String? notes,
  }) async {
    final warranty = await getById(warrantyId);
    if (warranty == null) throw Exception('الضمان غير موجود.');
    if (duration <= 0) throw Exception('مدة الضمان يجب أن تكون أكبر من صفر.');

    final days = unit == 'months'
        ? AppConstants.clampWarrantyDays(duration * 30)
        : AppConstants.clampWarrantyDays(duration);
    final start = DateTime.fromMillisecondsSinceEpoch(startDate);
    final startDay = DateTime(start.year, start.month, start.day);
    final end = startDay.add(Duration(days: days));
    final now = DateTime.now().millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    await _db.rawUpdate(
      '''
UPDATE warranties
SET warranty_type = ?,
    warranty_days = ?,
    start_date = ?,
    end_date = ?,
    is_void = 0,
    alert_disabled = 0,
    alert_disabled_reason = NULL,
    alert_disabled_at = NULL,
    alert_disabled_by = NULL,
    expiry_approved = 0,
    expiry_approved_at = NULL,
    expiry_approved_by = NULL,
    updated_at = ?
WHERE shop_id = ? AND id = ?
''',
      [
        AppConstants.warrantyCustom,
        days,
        startDay.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        now,
        shopId,
        warrantyId,
      ],
    );

    await _db.rawUpdate(
      '''
UPDATE maintenance
SET warranty_type = ?,
    warranty_days = ?,
    warranty_start = ?,
    warranty_end = ?,
    updated_at = ?
WHERE shop_id = ? AND id = ?
''',
      [
        AppConstants.warrantyCustom,
        days,
        startDay.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        now,
        shopId,
        warranty.maintenanceId,
      ],
    );

    await _deleteWarrantyNotifications(warrantyId);
    await recordAction(
      warrantyId: warrantyId,
      maintenanceId: warranty.maintenanceId,
      action: 'renewed',
      oldValue:
          '${warranty.warrantyDays} يوم | ${DateTime.fromMillisecondsSinceEpoch(warranty.startDate).toIso8601String()} - ${DateTime.fromMillisecondsSinceEpoch(warranty.endDate).toIso8601String()}',
      newValue:
          '$days يوم | ${startDay.toIso8601String()} - ${end.toIso8601String()}',
      notes: notes,
    );

    final updated = await getById(warrantyId);
    if (updated == null) throw Exception('تعذر تحديث الضمان.');
    return updated;
  }

  Future<void> approveExpiry(String warrantyId, {String? notes}) async {
    final warranty = await getById(warrantyId);
    if (warranty == null) throw Exception('الضمان غير موجود.');
    final user = AuthRepository().getCurrentUser();
    final username = user?.username ?? user?.name ?? 'النظام';
    final now = DateTime.now().millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    await _db.rawUpdate(
      '''
UPDATE warranties
SET is_void = 1,
    expiry_approved = 1,
    expiry_approved_at = ?,
    expiry_approved_by = ?,
    alert_disabled = 1,
    alert_disabled_reason = COALESCE(alert_disabled_reason, ?),
    alert_disabled_at = COALESCE(alert_disabled_at, ?),
    alert_disabled_by = COALESCE(alert_disabled_by, ?),
    updated_at = ?
WHERE shop_id = ? AND id = ?
''',
      [
        now,
        username,
        'اعتماد انتهاء الضمان',
        now,
        username,
        now,
        shopId,
        warrantyId,
      ],
    );
    await _db.rawUpdate(
      '''
UPDATE invoices
SET warranty_status = ?, updated_at = ?
WHERE shop_id = ? AND maintenance_id = ? AND status != ?
''',
      [
        'expired_approved',
        now,
        shopId,
        warranty.maintenanceId,
        AppConstants.invoiceCancelled,
      ],
    );
    await _deleteWarrantyNotifications(warrantyId);
    await recordAction(
      warrantyId: warrantyId,
      maintenanceId: warranty.maintenanceId,
      action: 'expiry_approved',
      oldValue: warranty.status,
      newValue: 'expired_approved',
      notes: notes,
    );
  }

  Future<void> addCorrectionNote(String warrantyId, String note) async {
    final warranty = await getById(warrantyId);
    if (warranty == null) throw Exception('الضمان غير موجود.');
    final trimmed = note.trim();
    if (trimmed.isEmpty) throw Exception('اكتب الملاحظة التصحيحية أولاً.');
    await recordAction(
      warrantyId: warrantyId,
      maintenanceId: warranty.maintenanceId,
      action: 'correction_note',
      notes: trimmed,
    );
  }

  Future<void> _deleteWarrantyNotifications(String warrantyId) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawDelete(
      '''
DELETE FROM notifications
WHERE shop_id = ?
  AND reference_type = 'warranty'
  AND reference_id = ?
''',
      [shopId, warrantyId],
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
        '''
SELECT id, created_at, end_date, alert_disabled, alert_disabled_reason,
       alert_disabled_at, alert_disabled_by, expiry_approved,
       expiry_approved_at, expiry_approved_by
FROM warranties
WHERE shop_id = ? AND maintenance_id = ?
LIMIT 1
''',
        [shopId, maintenanceId],
      );
      final warrantyId =
          existing.isEmpty ? const Uuid().v4() : existing.first['id'] as String;
      final createdAt = existing.isEmpty
          ? row['created_at'] as int? ?? now
          : existing.first['created_at'] as int? ?? now;
      final existingEnd =
          existing.isEmpty ? null : existing.first['end_date'] as int?;
      final preserveAlertDisabled = existing.isNotEmpty &&
          (existing.first['alert_disabled'] as int? ?? 0) == 1 &&
          existingEnd == end;
      final preserveExpiryApproved = existing.isNotEmpty &&
          (existing.first['expiry_approved'] as int? ?? 0) == 1 &&
          existingEnd == end;

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
        'is_void': preserveExpiryApproved ? 1 : 0,
        'alert_disabled': preserveAlertDisabled ? 1 : 0,
        'alert_disabled_reason': preserveAlertDisabled
            ? existing.first['alert_disabled_reason']
            : null,
        'alert_disabled_at':
            preserveAlertDisabled ? existing.first['alert_disabled_at'] : null,
        'alert_disabled_by':
            preserveAlertDisabled ? existing.first['alert_disabled_by'] : null,
        'expiry_approved': preserveExpiryApproved ? 1 : 0,
        'expiry_approved_at': preserveExpiryApproved
            ? existing.first['expiry_approved_at']
            : null,
        'expiry_approved_by': preserveExpiryApproved
            ? existing.first['expiry_approved_by']
            : null,
        'created_at': createdAt,
        'updated_at': now,
      };

      if (existing.isEmpty) {
        await _db.insert('warranties', data);
        await recordAction(
          warrantyId: warrantyId,
          maintenanceId: maintenanceId,
          action: 'created',
          newValue: '$days يوم',
        );
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
