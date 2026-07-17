import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/settings_service.dart';

class TrackingService {
  TrackingService();

  final DatabaseService _db = DatabaseService();

  Future<String> buildTrackingUrl(String ticketNumber) async {
    final settings = SettingsService();
    await settings.load();
    final base = settings.trackingBaseUrl.trim();
    if (base.isEmpty || ticketNumber.trim().isEmpty) return '';

    final encodedTicket = Uri.encodeComponent(ticketNumber.trim());
    if (base.contains('{ticket}')) {
      return base.replaceAll('{ticket}', encodedTicket);
    }

    final normalized =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$normalized/$encodedTicket';
  }

  Future<TrackingRecord?> loadByCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return null;

    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*,
       c.name AS customer_name,
       c.phone AS customer_phone,
       u.name AS technician_name
FROM maintenance m
LEFT JOIN customers c ON c.id = m.customer_id AND c.shop_id = m.shop_id
LEFT JOIN users u ON u.id = m.technician_id
WHERE m.shop_id = ?
  AND (m.ticket_number = ? OR m.id = ?)
  AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, cleanCode, cleanCode]);
    if (rows.isEmpty) return null;

    final row = Map<String, dynamic>.from(rows.first);
    final maintenanceId = row['id'] as String;
    final parts = await _loadParts(maintenanceId);
    final photos = await _loadPhotos(shopId, maintenanceId);
    final history = await _loadHistory(shopId, maintenanceId);

    return TrackingRecord(
      id: maintenanceId,
      ticketNumber: _text(row['ticket_number']),
      customerName: _text(row['customer_name']),
      customerPhone: _text(row['customer_phone']),
      brand: _text(row['brand']),
      model: _text(row['model']),
      imei: _text(row['imei']),
      faultDescription: _text(row['fault_description']),
      status: _text(row['status']),
      notes: _text(row['notes']),
      technicianName: _text(row['technician_name']),
      receivedAt: _int(row['received_at']),
      estimatedDelivery: _int(row['estimated_delivery']),
      updatedAt: _int(row['updated_at']),
      parts: parts,
      photos: photos,
      history: history,
    );
  }

  Future<List<String>> _loadParts(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT p.product_name
FROM maintenance_parts p
JOIN maintenance m ON m.id = p.maintenance_id
WHERE m.shop_id = ?
  AND p.maintenance_id = ?
ORDER BY p.created_at DESC
LIMIT 5
''', [shopId, maintenanceId]);
    return rows
        .map((row) => _text(row['product_name']))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<TrackingPhoto>> _loadPhotos(
    String shopId,
    String maintenanceId,
  ) async {
    final photos = await _db.rawQuery('''
SELECT original_path, thumbnail_path, photo_type, caption, stage, captured_at
FROM device_photos
WHERE shop_id = ?
  AND maintenance_id = ?
  AND deleted_at IS NULL
ORDER BY captured_at ASC
LIMIT 8
''', [shopId, maintenanceId]);

    if (photos.isNotEmpty) {
      return photos
          .map((row) {
            final path = _text(row['thumbnail_path']).isNotEmpty
                ? _text(row['thumbnail_path'])
                : _text(row['original_path']);
            return TrackingPhoto(
              path: path,
              label: _text(row['photo_type']),
              caption: _text(row['caption']),
              stage: _text(row['stage']),
              capturedAt: _int(row['captured_at']),
            );
          })
          .where((photo) => photo.path.isNotEmpty)
          .toList(growable: false);
    }

    final legacy = await _db.rawQuery('''
SELECT image_path, image_type, caption, created_at
FROM maintenance_images
WHERE maintenance_id = ?
ORDER BY created_at ASC
LIMIT 8
''', [maintenanceId]);
    return legacy
        .map((row) {
          return TrackingPhoto(
            path: _text(row['image_path']),
            label: _legacyImageTypeLabel(_text(row['image_type'])),
            caption: _text(row['caption']),
            stage: _text(row['image_type']),
            capturedAt: _int(row['created_at']),
          );
        })
        .where((photo) => photo.path.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<TrackingHistoryItem>> _loadHistory(
    String shopId,
    String maintenanceId,
  ) async {
    final rows = await _db.rawQuery('''
SELECT h.old_status, h.new_status, h.reason, h.notes, h.changed_at
FROM maintenance_status_history h
JOIN maintenance m ON m.id = h.maintenance_id
WHERE m.shop_id = ?
  AND h.maintenance_id = ?
ORDER BY h.changed_at ASC
''', [shopId, maintenanceId]);

    return rows.map((row) {
      final status = _text(row['new_status']);
      return TrackingHistoryItem(
        status: status,
        label: AppConstants.maintenanceStatusLabel(status),
        reason: _text(row['reason']),
        notes: _text(row['notes']),
        changedAt: _int(row['changed_at']),
      );
    }).toList(growable: false);
  }

  String _legacyImageTypeLabel(String type) {
    switch (type) {
      case 'before':
        return 'قبل الصيانة';
      case 'during':
        return 'أثناء الصيانة';
      case 'after':
        return 'بعد الصيانة';
      default:
        return 'صورة الجهاز';
    }
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class TrackingRecord {
  final String id;
  final String ticketNumber;
  final String customerName;
  final String customerPhone;
  final String brand;
  final String model;
  final String imei;
  final String faultDescription;
  final String status;
  final String notes;
  final String technicianName;
  final int? receivedAt;
  final int? estimatedDelivery;
  final int? updatedAt;
  final List<String> parts;
  final List<TrackingPhoto> photos;
  final List<TrackingHistoryItem> history;

  const TrackingRecord({
    required this.id,
    required this.ticketNumber,
    required this.customerName,
    required this.customerPhone,
    required this.brand,
    required this.model,
    required this.imei,
    required this.faultDescription,
    required this.status,
    required this.notes,
    required this.technicianName,
    required this.receivedAt,
    required this.estimatedDelivery,
    required this.updatedAt,
    required this.parts,
    required this.photos,
    required this.history,
  });

  String get deviceName =>
      [brand, model].where((value) => value.trim().isNotEmpty).join(' ').trim();

  TrackingStatusInfo get statusInfo => TrackingStatusInfo.fromStatus(status);
}

class TrackingStatusInfo {
  final String title;
  final String description;
  final double progress;
  final bool isFinal;

  const TrackingStatusInfo({
    required this.title,
    required this.description,
    required this.progress,
    this.isFinal = false,
  });

  factory TrackingStatusInfo.fromStatus(String status) {
    switch (status) {
      case AppConstants.statusNew:
      case AppConstants.statusWaitingInspection:
        return const TrackingStatusInfo(
          title: 'تم الاستلام',
          description: 'تم تسجيل الجهاز وسيبدأ الفحص حسب ترتيب العمل.',
          progress: .18,
        );
      case AppConstants.statusInspecting:
      case AppConstants.statusFaultIdentified:
        return const TrackingStatusInfo(
          title: 'تحت الفحص',
          description: 'الفني يفحص الجهاز لتحديد سبب العطل بدقة.',
          progress: .34,
        );
      case AppConstants.statusWaitingCustomerApproval:
        return const TrackingStatusInfo(
          title: 'بانتظار موافقتك',
          description: 'تم تحديد الإجراء المطلوب وننتظر تأكيد العميل.',
          progress: .44,
        );
      case AppConstants.statusCustomerApproved:
        return const TrackingStatusInfo(
          title: 'تمت الموافقة',
          description: 'تم اعتماد الإصلاح وسيتم إدخاله إلى الصيانة.',
          progress: .50,
        );
      case AppConstants.statusCustomerRejected:
        return const TrackingStatusInfo(
          title: 'لم يتم اعتماد الإصلاح',
          description: 'يمكن مراجعة المركز لاستلام الجهاز أو تحديث القرار.',
          progress: .50,
        );
      case AppConstants.statusWaitingPart:
        return const TrackingStatusInfo(
          title: 'في انتظار قطعة',
          description: 'الجهاز يحتاج قطعة غيار لإكمال الصيانة.',
          progress: .56,
        );
      case AppConstants.statusRepairing:
        return const TrackingStatusInfo(
          title: 'تحت الصيانة',
          description: 'الجهاز الآن لدى الفني ويتم العمل على الإصلاح.',
          progress: .68,
        );
      case AppConstants.statusUnderTesting:
        return const TrackingStatusInfo(
          title: 'تحت الاختبار',
          description: 'تم تنفيذ الصيانة ويجري اختبار الجهاز قبل التسليم.',
          progress: .78,
        );
      case AppConstants.statusRepaired:
      case AppConstants.statusReady:
        return const TrackingStatusInfo(
          title: 'جاهز للاستلام',
          description: 'الجهاز جاهز ويمكنك مراجعة المركز للاستلام.',
          progress: .88,
        );
      case AppConstants.statusDelivered:
        return const TrackingStatusInfo(
          title: 'تم التسليم',
          description: 'تم تسليم الجهاز وإغلاق طلب الصيانة.',
          progress: 1,
          isFinal: true,
        );
      case AppConstants.statusUnrepairable:
        return const TrackingStatusInfo(
          title: 'جزء تالف / تعذر الإصلاح',
          description: 'تم فحص الجهاز وتعذر إتمام الإصلاح حسب نتيجة الفني.',
          progress: .76,
        );
      case AppConstants.statusCancelled:
        return const TrackingStatusInfo(
          title: 'تم إلغاء الطلب',
          description: 'تم إغلاق طلب الصيانة بناء على الإلغاء.',
          progress: .10,
          isFinal: true,
        );
      case AppConstants.statusWarrantyReturn:
        return const TrackingStatusInfo(
          title: 'طلب ضمان',
          description: 'تم استلام الجهاز للفحص ضمن الضمان.',
          progress: .36,
        );
      case AppConstants.statusAbandoned:
        return const TrackingStatusInfo(
          title: 'لم يتم الاستلام',
          description: 'الجهاز جاهز منذ مدة ولم يتم استلامه من المركز.',
          progress: .90,
        );
      default:
        return TrackingStatusInfo(
          title: AppConstants.maintenanceStatusLabel(status),
          description: 'تم تحديث حالة طلب الصيانة.',
          progress: .40,
        );
    }
  }
}

class TrackingPhoto {
  final String path;
  final String label;
  final String caption;
  final String stage;
  final int? capturedAt;

  const TrackingPhoto({
    required this.path,
    required this.label,
    required this.caption,
    required this.stage,
    required this.capturedAt,
  });
}

class TrackingHistoryItem {
  final String status;
  final String label;
  final String reason;
  final String notes;
  final int? changedAt;

  const TrackingHistoryItem({
    required this.status,
    required this.label,
    required this.reason,
    required this.notes,
    required this.changedAt,
  });
}
