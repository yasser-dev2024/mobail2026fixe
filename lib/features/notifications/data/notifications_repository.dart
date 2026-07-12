import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/constants/app_constants.dart';
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
  // Smart notification generation
  // ---------------------------------------------------------------------------

  /// Check various conditions and create smart notifications if they do not
  /// already exist.
  ///
  /// Checks performed:
  ///  1. Maintenance tickets with status='ready' for > 3 days (abandoned device).
  ///  2. Warranties expiring within the next 7 days.
  ///  3. Products with quantity > 0 AND quantity <= low_stock_threshold (low stock).
  ///  4. Products with quantity <= 0 AND is_active=1 AND is_service=0 (out of stock).
  Future<void> generateSmartNotifications() async {
    await _checkAbandonedDevices();
    await _checkExpiringWarranties();
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
  Future<void> _addIfNew({
    required String referenceId,
    required String referenceType,
    required String type,
    required String priority,
    required String title,
    required String message,
  }) async {
    if (await _notificationExists(referenceId, type)) return;

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
  }

  /// Check for maintenance tickets with status='ready' for more than 3 days.
  Future<void> _checkAbandonedDevices() async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    final rows = await _db.rawQuery(
      '''SELECT m.id, m.ticket_number, m.brand, m.model, c.name as customer_name
         FROM maintenance m
         LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
         WHERE m.status = 'ready'
           AND m.shop_id = ?
           AND m.updated_at < ?
           AND m.deleted_at IS NULL''',
      [shopId, cutoff],
    );

    for (final row in rows) {
      final id = row['id'] as String;
      final ticketNumber = row['ticket_number'] as String? ?? '';
      final brand = row['brand'] as String? ?? '';
      final model = row['model'] as String? ?? '';
      final customerName = row['customer_name'] as String? ?? 'عميل';

      await _addIfNew(
        referenceId: id,
        referenceType: 'maintenance',
        type: 'abandoned_device',
        priority: AppConstants.priorityHigh,
        title: 'جهاز ينتظر الاستلام',
        message:
            'جهاز $brand $model للعميل $customerName (رقم الصيانة: $ticketNumber) جاهز منذ أكثر من 3 أيام ولم يُستلم بعد.',
      );
    }
  }

  /// Check for warranties expiring within the next 7 days.
  Future<void> _checkExpiringWarranties() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysLater =
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    final rows = await _db.rawQuery(
      '''SELECT w.id, w.device_info, w.end_date, c.name as customer_name
         FROM warranties w
         LEFT JOIN maintenance m ON w.maintenance_id = m.id AND m.shop_id = w.shop_id
         LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
         WHERE w.end_date >= ?
           AND w.end_date <= ?
           AND w.is_void = 0
           AND w.shop_id = ?''',
      [nowMs, sevenDaysLater, shopId],
    );

    for (final row in rows) {
      final id = row['id'] as String;
      final deviceInfo = row['device_info'] as String? ?? 'الجهاز';
      final customerName = row['customer_name'] as String? ?? 'العميل';
      final endDateMs = row['end_date'] as int?;

      String endDateStr = '';
      if (endDateMs != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(endDateMs);
        endDateStr =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final daysLeft = dt.difference(DateTime.now()).inDays;
        endDateStr = '$endDateStr (خلال $daysLeft يوم)';
      }

      await _addIfNew(
        referenceId: id,
        referenceType: 'warranty',
        type: 'warranty_expiring',
        priority: AppConstants.priorityMedium,
        title: 'ضمان على وشك الانتهاء',
        message:
            'ضمان $deviceInfo للعميل $customerName سينتهي بتاريخ $endDateStr.',
      );
    }
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
