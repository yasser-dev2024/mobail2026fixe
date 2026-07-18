import 'package:uuid/uuid.dart';
import '../database/database_service.dart';
import '../constants/app_constants.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/notifications/data/notification_model.dart';

/// Service that generates smart notifications by checking maintenance,
/// warranties, and inventory conditions.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final DatabaseService _db = DatabaseService();
  final NotificationsRepository _notificationsRepo = NotificationsRepository();
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Run all smart notification checks in sequence.
  Future<void> checkAndGenerateAll() async {
    await _notificationsRepo.generateSmartNotifications();
  }

  /// Check for maintenance tickets with status='ready' for more than 3 days
  /// (abandoned devices) and create notifications as needed.
  Future<void> checkAbandonedDevices() async {
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

      if (await _notificationExists(id, 'abandoned_device')) continue;

      await _notificationsRepo.add(NotificationModel(
        id: _uuid.v4(),
        title: 'جهاز ينتظر الاستلام',
        message:
            'جهاز $brand $model للعميل $customerName (رقم الصيانة: $ticketNumber) جاهز منذ أكثر من 3 أيام ولم يُستلم بعد.',
        type: 'abandoned_device',
        priority: AppConstants.priorityHigh,
        referenceId: id,
        referenceType: 'maintenance',
        isRead: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  /// Check for warranties expiring within the next 7 days and create
  /// notifications as needed.
  Future<void> checkExpiringWarranties() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysLater =
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    final rows = await _db.rawQuery(
      '''SELECT w.id, w.device_info, w.end_date, c.name as customer_name
         FROM warranties w
         LEFT JOIN customers c ON w.customer_id = c.id AND c.shop_id = w.shop_id
         WHERE w.is_void = 0
           AND w.shop_id = ?
           AND w.end_date > ?
           AND w.end_date <= ?
           AND COALESCE(w.alert_disabled, 0) = 0
           AND COALESCE(w.expiry_approved, 0) = 0''',
      [shopId, nowMs, sevenDaysLater],
    );

    for (final row in rows) {
      final id = row['id'] as String;
      final deviceInfo = row['device_info'] as String? ?? 'الجهاز';
      final customerName = row['customer_name'] as String? ?? 'العميل';
      final endDateMs = row['end_date'] as int?;

      String endDateStr = '';
      if (endDateMs != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(endDateMs);
        final formatted =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final daysLeft = dt.difference(DateTime.now()).inDays;
        endDateStr = '$formatted (خلال $daysLeft يوم)';
      }

      if (await _notificationExists(id, 'warranty_expiring')) continue;

      await _notificationsRepo.add(NotificationModel(
        id: _uuid.v4(),
        title: 'ضمان على وشك الانتهاء',
        message:
            'ضمان $deviceInfo للعميل $customerName سينتهي بتاريخ $endDateStr.',
        type: 'warranty_expiring',
        priority: AppConstants.priorityMedium,
        referenceId: id,
        referenceType: 'warranty',
        isRead: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  /// Check for products with quantity > 0 but at or below their low stock
  /// threshold and create notifications as needed.
  Future<void> checkLowStock() async {
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

      if (await _notificationExists(id, 'low_stock')) continue;

      await _notificationsRepo.add(NotificationModel(
        id: _uuid.v4(),
        title: 'مخزون منخفض',
        message:
            'الكمية المتبقية من "$name" هي $quantity (الحد الأدنى: $threshold).',
        type: 'low_stock',
        priority: AppConstants.priorityMedium,
        referenceId: id,
        referenceType: 'product',
        isRead: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  /// Check for products that are completely out of stock and create
  /// notifications as needed.
  Future<void> checkOutOfStock() async {
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

      if (await _notificationExists(id, 'out_of_stock')) continue;

      await _notificationsRepo.add(NotificationModel(
        id: _uuid.v4(),
        title: 'نفاد المخزون',
        message: 'المنتج "$name" نفد من المخزون.',
        type: 'out_of_stock',
        priority: AppConstants.priorityHigh,
        referenceId: id,
        referenceType: 'product',
        isRead: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns true when a notification for [referenceId] + [type] already exists
  /// in the database, preventing duplicate notifications.
  Future<bool> _notificationExists(String referenceId, String type) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT id FROM notifications WHERE shop_id = ? AND reference_id = ? AND type = ? LIMIT 1',
      [shopId, referenceId, type],
    );
    return rows.isNotEmpty;
  }
}
