import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/alert_sound_service.dart';
import '../../../core/services/settings_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../warranty/data/warranty_repository.dart';
import '../../whatsapp/data/whatsapp_repository.dart';
import 'notification_model.dart';

class NotificationsRepository {
  static final NotificationsRepository _instance =
      NotificationsRepository._internal();
  factory NotificationsRepository() => _instance;
  NotificationsRepository._internal();

  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Core CRUD
  // ---------------------------------------------------------------------------

  /// Get all notifications, optionally filtered to unread only.
  /// Ordered by created_at DESC.
  Future<List<NotificationModel>> getAll({bool? unreadOnly}) async {
    final shopId = await _db.getCurrentShopId();
    final conditions = <String>['shop_id = ?'];
    final args = <dynamic>[shopId];

    if (unreadOnly == true) {
      conditions.add('is_read = ?');
      args.add(0);
    }

    final rows = await _db.query(
      'notifications',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  /// Count unread notifications.
  Future<int> getUnreadCount() async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM notifications WHERE shop_id = ? AND is_read = 0',
      [shopId],
    );
    return rows.isNotEmpty ? (rows.first['cnt'] as int? ?? 0) : 0;
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String id) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawUpdate(
      'UPDATE notifications SET is_read = 1 WHERE shop_id = ? AND id = ?',
      [shopId, id],
    );
  }

  /// Mark every notification as read.
  Future<void> markAllAsRead() async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawUpdate(
      'UPDATE notifications SET is_read = 1 WHERE shop_id = ? AND is_read = 0',
      [shopId],
    );
  }

  /// Hard-delete a notification by [id].
  Future<void> delete(String id) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawUpdate(
      'DELETE FROM notifications WHERE shop_id = ? AND id = ?',
      [shopId, id],
    );
  }

  /// Insert a new notification.
  Future<void> add(NotificationModel notification) async {
    final shopId = await _db.getCurrentShopId();
    await _db.insert(
      'notifications',
      notification.copyWith(shopId: shopId).toMap(),
    );
  }

  Future<void> addDeviceNotification({
    required String deviceId,
    required String title,
    required String message,
    String priority = AppConstants.priorityHigh,
  }) async {
    await add(NotificationModel(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: 'device_manual',
      priority: priority,
      referenceId: deviceId,
      referenceType: 'device',
      isRead: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Get all notifications for a specific maintenance ticket (by id).
  Future<List<NotificationModel>> getForMaintenance(
      String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'notifications',
      where: 'shop_id = ? AND reference_id = ?',
      whereArgs: [shopId, maintenanceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Recurring alert engine (snooze / stop / re-fire)
  // ---------------------------------------------------------------------------

  /// Unread, non-stopped notifications that are due to re-fire (sound +
  /// popup) right now: their snooze (if any) has passed, and it has been at
  /// least [SettingsService.alertCheckIntervalMinutes] since they last fired
  /// (or they have never fired). Fully generic — applies to every existing
  /// and future notification `type` with no per-type code needed here.
  Future<List<NotificationModel>> getDueForRefire() async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = SettingsService().alertCheckIntervalMinutes * 60000;
    final rows = await _db.rawQuery(
      '''SELECT * FROM notifications
         WHERE shop_id = ?
           AND is_read = 0
           AND alert_stopped = 0
           AND (snoozed_until IS NULL OR snoozed_until <= ?)
           AND (last_fired_at IS NULL OR last_fired_at <= ?)
         ORDER BY created_at ASC''',
      [shopId, now, now - intervalMs],
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  /// Snoozes a single alert until [until] (epoch ms) — it will not re-fire
  /// before that time, but is not marked read/stopped, so it resumes
  /// re-firing on the normal interval afterwards.
  Future<void> snooze(String id, {required int until}) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawUpdate(
      'UPDATE notifications SET snoozed_until = ? WHERE shop_id = ? AND id = ?',
      [until, shopId, id],
    );
  }

  /// Permanently stops a single alert from re-firing. Device-stay alerts
  /// have exactly one row per ticket, so this means "never again for this
  /// ticket." Warranty alerts get a fresh `type` string (and therefore a
  /// fresh row) as the day-bucket changes, so stopping e.g.
  /// `warranty_expiring_tomorrow` does not block a later, distinct
  /// `warranty_expired` row from firing — that already falls out of the
  /// existing dedup-by-(reference_id, type) design with no extra code.
  Future<void> stopAlert(String id) async {
    final shopId = await _db.getCurrentShopId();
    final user = AuthRepository().getCurrentUser();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      '''UPDATE notifications
         SET alert_stopped = 1, alert_stopped_at = ?, alert_stopped_by = ?, is_read = 1
         WHERE shop_id = ? AND id = ?''',
      [now, user?.username ?? user?.name ?? 'النظام', shopId, id],
    );
  }

  /// Records that an alert was just (re-)shown, so the recurrence interval
  /// is measured from this moment.
  Future<void> markFired(String id) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawUpdate(
      'UPDATE notifications SET last_fired_at = ? WHERE shop_id = ? AND id = ?',
      [DateTime.now().millisecondsSinceEpoch, shopId, id],
    );
  }

  /// Loads the customer/device/ticket context needed by the recurring alert
  /// popup for a single notification, regardless of its `reference_type`.
  Future<AlertPopupDetails?> getAlertDetails(String notificationId) async {
    final shopId = await _db.getCurrentShopId();
    final notifRows = await _db.query(
      'notifications',
      where: 'shop_id = ? AND id = ?',
      whereArgs: [shopId, notificationId],
      limit: 1,
    );
    if (notifRows.isEmpty) return null;
    final notif = NotificationModel.fromMap(notifRows.first);

    if (notif.referenceType != 'maintenance' &&
        notif.referenceType != 'warranty') {
      return AlertPopupDetails(notification: notif);
    }

    final maintenanceId = notif.referenceType == 'warranty'
        ? await _maintenanceIdForWarranty(notif.referenceId, shopId)
        : notif.referenceId;
    if (maintenanceId == null) return AlertPopupDetails(notification: notif);

    final rows = await _db.rawQuery(
      '''SELECT m.ticket_number, m.brand, m.model, m.received_at,
                c.name AS customer_name, c.phone AS customer_phone
         FROM maintenance m
         LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
         WHERE m.shop_id = ? AND m.id = ?
         LIMIT 1''',
      [shopId, maintenanceId],
    );
    if (rows.isEmpty) return AlertPopupDetails(notification: notif);
    final row = rows.first;
    return AlertPopupDetails(
      notification: notif,
      customerName: row['customer_name'] as String?,
      customerPhone: row['customer_phone'] as String?,
      deviceName: [row['brand'], row['model']]
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .join(' '),
      ticketNumber: row['ticket_number'] as String?,
      maintenanceId: maintenanceId,
    );
  }

  Future<String?> _maintenanceIdForWarranty(
    String? warrantyId,
    String shopId,
  ) async {
    if (warrantyId == null) return null;
    final rows = await _db.query(
      'warranties',
      columns: ['maintenance_id'],
      where: 'shop_id = ? AND id = ?',
      whereArgs: [shopId, warrantyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['maintenance_id'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Smart notification generation
  // ---------------------------------------------------------------------------

  /// Check various conditions and create smart notifications if they do not
  /// already exist.
  ///
  /// Checks performed:
  ///  1. Maintenance tickets that stayed in the shop for 2+ days.
  ///  2. Warranties expiring tomorrow or the day after tomorrow.
  ///  3. Products with quantity > 0 AND quantity <= low_stock_threshold (low stock).
  ///  4. Products with quantity <= 0 AND is_active=1 AND is_service=0 (out of stock).
  Future<void> generateSmartNotifications() async {
    final deviceStayCount = await _checkDevicesStayingTwoDays();
    if (deviceStayCount > 0) {
      await AlertSoundService().playDeviceStayAlert();
    }

    final warrantyCount = await _checkExpiringWarranties();
    if (warrantyCount > 0) {
      await AlertSoundService().playWarrantyExpiringAlert();
    }

    await WhatsappRepository().prepareDueMessages();
    await _checkLowStock();
    await _checkOutOfStock();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns true when an unread notification for [referenceId] + [type] already exists.
  Future<bool> _notificationExists(String referenceId, String type) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT id FROM notifications WHERE shop_id = ? AND reference_id = ? AND type = ? LIMIT 1',
      [shopId, referenceId, type],
    );
    return rows.isNotEmpty;
  }

  /// Insert a notification only if one does not already exist for the same
  /// [referenceId] / [type] pair.
  Future<bool> _addIfNew({
    required String referenceId,
    required String referenceType,
    required String type,
    required String priority,
    required String title,
    required String message,
  }) async {
    if (await _notificationExists(referenceId, type)) return false;

    await add(NotificationModel(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: type,
      priority: priority,
      referenceId: referenceId,
      referenceType: referenceType,
      isRead: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    return true;
  }

  /// Check for maintenance tickets that stayed in the shop for 2+ days.
  Future<int> _checkDevicesStayingTwoDays() async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    final rows = await _db.rawQuery(
      '''SELECT m.id, m.ticket_number, m.brand, m.model, m.status, m.received_at, c.name as customer_name
         FROM maintenance m
         LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
         WHERE m.shop_id = ?
           AND m.received_at <= ?
           AND m.status NOT IN (?, ?)
           AND m.deleted_at IS NULL
         ORDER BY m.received_at ASC''',
      [
        shopId,
        cutoff,
        AppConstants.statusDelivered,
        AppConstants.statusCancelled,
      ],
    );

    var created = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      final ticketNumber = row['ticket_number'] as String? ?? '';
      final brand = row['brand'] as String? ?? '';
      final model = row['model'] as String? ?? '';
      final status = row['status'] as String? ?? '';
      final receivedAt = row['received_at'] as int?;
      final customerName = row['customer_name'] as String? ?? 'عميل';
      final daysInShop = receivedAt == null
          ? 2
          : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(receivedAt))
              .inDays;

      final added = await _addIfNew(
        referenceId: id,
        referenceType: 'maintenance',
        type: 'device_stay_two_days',
        priority: AppConstants.priorityHigh,
        title: 'جوال بقي في المحل يومين',
        message:
            'الجوال $brand $model للعميل $customerName بقي في المحل منذ $daysInShop يوم. رقم الصيانة: $ticketNumber. الحالة الحالية: ${AppConstants.maintenanceStatusLabel(status)}.',
      );
      if (added) created++;
    }
    return created;
  }

  /// Check warranty deadlines that need a user decision.
  Future<int> _checkExpiringWarranties() async {
    await WarrantyRepository().syncFromMaintenance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final toMs = today.add(const Duration(days: 3)).millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    final rows = await _db.rawQuery(
      '''SELECT w.id, w.device_info, w.end_date, c.name as customer_name
         FROM warranties w
         LEFT JOIN maintenance m ON w.maintenance_id = m.id AND m.shop_id = w.shop_id
         LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
         WHERE w.end_date < ?
           AND w.is_void = 0
           AND COALESCE(w.alert_disabled, 0) = 0
           AND COALESCE(w.expiry_approved, 0) = 0
           AND w.shop_id = ?
         ORDER BY w.end_date ASC''',
      [toMs, shopId],
    );

    var created = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      final deviceInfo = row['device_info'] as String? ?? 'الجهاز';
      final customerName = row['customer_name'] as String? ?? 'العميل';
      final endDateMs = row['end_date'] as int?;

      String endDateStr = '';
      var daysLeft = 0;
      if (endDateMs != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(endDateMs);
        endDateStr =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        daysLeft = _calendarDaysUntil(dt);
        final label = switch (daysLeft) {
          2 => 'بعد يومين',
          1 => 'غداً',
          0 => 'اليوم',
          < 0 => 'منتهي منذ ${daysLeft.abs()} يوم',
          _ => 'قريباً',
        };
        endDateStr = '$endDateStr ($label)';
      }

      final type = switch (daysLeft) {
        2 => 'warranty_expiring_two_days',
        1 => 'warranty_expiring_tomorrow',
        0 => 'warranty_expiring_today',
        < -3 => 'warranty_overdue_action',
        < 0 => 'warranty_expired',
        _ => 'warranty_expiring',
      };
      final title = switch (type) {
        'warranty_expiring_two_days' => 'ضمان سينتهي بعد يومين',
        'warranty_expiring_tomorrow' => 'ضمان سينتهي غداً',
        'warranty_expiring_today' => 'ضمان ينتهي اليوم',
        'warranty_overdue_action' => 'ضمان متأخر في اتخاذ الإجراء',
        'warranty_expired' => 'ضمان منتهٍ',
        _ => 'ضمان ينتهي قريباً',
      };
      final priority = daysLeft < 0
          ? AppConstants.priorityCritical
          : daysLeft == 0
              ? AppConstants.priorityHigh
              : AppConstants.priorityHigh;

      final added = await _addIfNew(
        referenceId: id,
        referenceType: 'warranty',
        type: type,
        priority: priority,
        title: title,
        message:
            'ضمان $deviceInfo للعميل $customerName سينتهي بتاريخ $endDateStr.',
      );
      if (added) {
        await WarrantyRepository().recordAction(
          warrantyId: id,
          action: 'alert_shown',
          newValue: type,
        );
        created++;
      }
    }
    return created;
  }

  int _calendarDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  /// Check for products with quantity > 0 but at or below the low stock threshold.
  Future<void> _checkLowStock() async {
    final rows = await _db.rawQuery(
      '''SELECT id, name, quantity, low_stock_threshold
         FROM products
         WHERE quantity > 0
           AND quantity <= low_stock_threshold
           AND is_service = 0
           AND is_active = 1
           AND deleted_at IS NULL''',
    );

    for (final row in rows) {
      final id = row['id'] as String;
      final name = row['name'] as String? ?? 'منتج';
      final quantity = (row['quantity'] as int?) ?? 0;
      final threshold = (row['low_stock_threshold'] as int?) ?? 0;

      await _addIfNew(
        referenceId: id,
        referenceType: 'product',
        type: 'low_stock',
        priority: AppConstants.priorityMedium,
        title: 'مخزون منخفض',
        message:
            'الكمية المتبقية من "$name" هي $quantity (الحد الأدنى: $threshold).',
      );
    }
  }

  /// Check for products that are completely out of stock.
  Future<void> _checkOutOfStock() async {
    final rows = await _db.rawQuery(
      '''SELECT id, name
         FROM products
         WHERE quantity <= 0
           AND is_service = 0
           AND is_active = 1
           AND deleted_at IS NULL''',
    );

    for (final row in rows) {
      final id = row['id'] as String;
      final name = row['name'] as String? ?? 'منتج';

      await _addIfNew(
        referenceId: id,
        referenceType: 'product',
        type: 'out_of_stock',
        priority: AppConstants.priorityHigh,
        title: 'نفاد المخزون',
        message: 'المنتج "$name" نفد من المخزون.',
      );
    }
  }

  /// Remove read notifications older than [daysOld] days.
  Future<void> clearOldRead(int daysOld) async {
    final shopId = await _db.getCurrentShopId();
    final cutoff =
        DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    await _db.rawUpdate(
      'DELETE FROM notifications WHERE shop_id = ? AND is_read = 1 AND created_at < ?',
      [shopId, cutoff],
    );
  }
}
