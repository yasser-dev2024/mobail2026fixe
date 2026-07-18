import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../whatsapp/data/whatsapp_repository.dart';
import '../../tracking/services/remote_tracking_service.dart';
import 'maintenance_model.dart';
import 'maintenance_part_model.dart';
import 'maintenance_image_model.dart';

class MaintenanceRepository {
  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // LIST
  // ---------------------------------------------------------------------------

  Future<List<MaintenanceModel>> getAll({
    String? status,
    List<String>? statuses,
    String? technicianId,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final shopId = await _db.getCurrentShopId();
    final conditions = <String>['m.shop_id = ?', 'm.deleted_at IS NULL'];
    final args = <dynamic>[shopId];

    if (status != null && status.isNotEmpty) {
      conditions.add('m.status = ?');
      args.add(status);
    } else if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(',');
      conditions.add('m.status IN ($placeholders)');
      args.addAll(statuses);
    }
    if (technicianId != null && technicianId.isNotEmpty) {
      conditions.add('m.technician_id = ?');
      args.add(technicianId);
    }
    if (from != null) {
      conditions.add('m.received_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('m.received_at <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add(
          '(m.ticket_number LIKE ? OR m.brand LIKE ? OR m.model LIKE ? OR c.name LIKE ? OR m.imei LIKE ?)');
      final s = '%$search%';
      args.addAll([s, s, s, s, s]);
    }

    final where = conditions.join(' AND ');

    final rows = await _db.rawQuery('''
SELECT m.*, c.name AS customer_name, c.phone AS customer_phone, u.name AS technician_name,
       w.expiry_approved AS warranty_expiry_approved,
       w.expiry_approved_at AS warranty_expiry_approved_at,
       w.expiry_approved_by AS warranty_expiry_approved_by
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN users u ON m.technician_id = u.id
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE $where
ORDER BY m.created_at DESC
''', args.isEmpty ? null : args);

    return rows.map(MaintenanceModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // SINGLE
  // ---------------------------------------------------------------------------

  Future<MaintenanceModel?> getById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*, c.name AS customer_name, c.phone AS customer_phone, u.name AS technician_name,
       w.expiry_approved AS warranty_expiry_approved,
       w.expiry_approved_at AS warranty_expiry_approved_at,
       w.expiry_approved_by AS warranty_expiry_approved_by
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN users u ON m.technician_id = u.id
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE m.shop_id = ? AND m.id = ? AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, id]);
    if (rows.isEmpty) return null;
    return MaintenanceModel.fromMap(rows.first);
  }

  Future<List<MaintenanceModel>> getByCustomer(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*, c.name AS customer_name, c.phone AS customer_phone, u.name AS technician_name,
       w.expiry_approved AS warranty_expiry_approved,
       w.expiry_approved_at AS warranty_expiry_approved_at,
       w.expiry_approved_by AS warranty_expiry_approved_by
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN users u ON m.technician_id = u.id
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE m.shop_id = ? AND m.customer_id = ? AND m.deleted_at IS NULL
ORDER BY m.created_at DESC
''', [shopId, customerId]);
    return rows.map(MaintenanceModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // CREATE / UPDATE / DELETE
  // ---------------------------------------------------------------------------

  Future<String> create(MaintenanceModel maintenance) async {
    final shopId = await _db.getCurrentShopId();
    final id = maintenance.id.isNotEmpty ? maintenance.id : const Uuid().v4();
    final normalized = _withWarrantyDates(maintenance.copyWith(id: id));
    await _validateStatusTransition(
      id: id,
      oldStatus: null,
      newStatus: normalized.status,
    );
    final data = normalized.toMap();
    data['id'] = id;
    data['shop_id'] = shopId;
    await _db.insert('maintenance', data);
    await _recordStatusHistory(
      maintenanceId: id,
      oldStatus: null,
      newStatus: normalized.status,
      reason: 'إنشاء طلب الصيانة',
    );
    await _syncWarranty(normalized);
    await _syncFinancials(id);
    await RemoteTrackingService().syncTicket(normalized.ticketNumber);
    await WhatsappRepository()
        .prepareAndMaybeAutoSend(id, AppConstants.waMsgReceived);
    if (normalized.status != AppConstants.statusNew) {
      await _addStatusNotification(id, normalized.status);
      await _prepareWhatsappForStatus(id, normalized.status);
    }
    return id;
  }

  Future<void> update(MaintenanceModel maintenance) async {
    final shopId = await _db.getCurrentShopId();
    final before = await getById(maintenance.id);
    if (before == null) {
      throw Exception('سجل الصيانة غير موجود في هذا المحل');
    }
    final normalized = _withWarrantyDates(
      maintenance.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch),
    );
    await _validateStatusTransition(
      id: normalized.id,
      oldStatus: before.status,
      newStatus: normalized.status,
    );
    await _updateMaintenanceInCurrentShop(
      normalized.id,
      normalized.toMap()..['shop_id'] = shopId,
    );
    if (before.status != normalized.status) {
      await _recordStatusHistory(
        maintenanceId: normalized.id,
        oldStatus: before.status,
        newStatus: normalized.status,
        reason: 'تعديل بيانات الصيانة',
      );
    }
    await _syncWarranty(normalized);
    await _syncFinancials(normalized.id);
    await RemoteTrackingService().syncTicket(normalized.ticketNumber);
    if (normalized.status != AppConstants.statusNew) {
      await _addStatusNotification(normalized.id, normalized.status);
    }
    if (before.status != normalized.status) {
      await _prepareWhatsappForStatus(normalized.id, normalized.status);
    }
  }

  Future<void> updateStatus(
    String id,
    String status, {
    int? deliveredAt,
    String? reason,
    String? notes,
  }) async {
    final shopId = await _db.getCurrentShopId();
    // Capture current status for audit log before updating
    String? oldStatus;
    try {
      final cur = await _db.rawQuery(
        'SELECT status FROM maintenance WHERE shop_id = ? AND id = ? AND deleted_at IS NULL LIMIT 1',
        [shopId, id],
      );
      if (cur.isNotEmpty) oldStatus = cur.first['status'] as String?;
    } catch (_) {}
    if (oldStatus == null) {
      throw Exception('سجل الصيانة غير موجود في هذا المحل');
    }
    await _validateStatusTransition(
      id: id,
      oldStatus: oldStatus,
      newStatus: status,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    if (status == 'delivered') {
      await _db.rawUpdate(
        'UPDATE maintenance SET status = ?, delivered_at = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
        [status, deliveredAt ?? now, now, shopId, id],
      );
    } else {
      await _db.rawUpdate(
        'UPDATE maintenance SET status = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
        [status, now, shopId, id],
      );
    }
    final updated = await getById(id);
    if (updated != null) {
      final withWarranty = _withWarrantyDates(updated);
      if (withWarranty.warrantyStart != updated.warrantyStart ||
          withWarranty.warrantyEnd != updated.warrantyEnd ||
          withWarranty.warrantyDays != updated.warrantyDays ||
          withWarranty.warrantyType != updated.warrantyType) {
        await _updateMaintenanceInCurrentShop(id, withWarranty.toMap());
      }
      await _syncWarranty(withWarranty);
    }
    await _syncFinancials(id);
    await _addStatusNotification(id, status);
    await _recordStatusHistory(
      maintenanceId: id,
      oldStatus: oldStatus,
      newStatus: status,
      reason: reason,
      notes: notes,
    );
    if (updated != null) {
      await RemoteTrackingService().syncTicket(updated.ticketNumber);
    }
    // Write immutable audit entry
    await logAudit(
      maintenanceId: id,
      action: 'تغيير الحالة',
      oldValue: oldStatus,
      newValue: status,
    );
    await _prepareWhatsappForStatus(id, status);
  }

  Future<void> saveRepairResult({
    required String id,
    required bool repaired,
    String? repairDetails,
    String? changedPart,
    String? unrepairableReason,
    String? technicianNotes,
    double? laborCost,
    String? warrantyType,
    int? warrantyDays,
    bool? openedDevice,
    bool? changedAnyPart,
  }) async {
    final before = await getById(id);
    if (before == null) {
      throw Exception('سجل الصيانة غير موجود');
    }
    if (before.status == AppConstants.statusDelivered ||
        before.status == AppConstants.statusCancelled ||
        before.status == AppConstants.statusAbandoned) {
      throw Exception('لا يمكن تعديل نتيجة صيانة جهاز مغلق أو مسلم');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final details = <String>[
      if ((repairDetails ?? '').trim().isNotEmpty)
        'الصيانة التي تمت: ${repairDetails!.trim()}',
      if ((changedPart ?? '').trim().isNotEmpty)
        'القطعة المستبدلة: ${changedPart!.trim()}',
      if ((unrepairableReason ?? '').trim().isNotEmpty)
        'سبب تعذر الإصلاح: ${unrepairableReason!.trim()}',
      if (openedDevice != null) 'تم فتح الجهاز: ${openedDevice ? 'نعم' : 'لا'}',
      if (changedAnyPart != null)
        'تم تغيير قطعة: ${changedAnyPart ? 'نعم' : 'لا'}',
    ];
    final publicNotes = [
      if ((before.notes ?? '').trim().isNotEmpty) before.notes!.trim(),
      ...details,
    ].join('\n');
    final internalNotes = [
      if ((before.internalNotes ?? '').trim().isNotEmpty)
        before.internalNotes!.trim(),
      if ((technicianNotes ?? '').trim().isNotEmpty)
        'ملاحظات الفني: ${technicianNotes!.trim()}',
    ].join('\n');

    final newLaborCost = laborCost ?? before.laborCost;
    final status =
        repaired ? AppConstants.statusReady : AppConstants.statusUnrepairable;
    final warranty = repaired
        ? (warrantyType ?? before.warrantyType ?? AppConstants.warrantyNone)
        : AppConstants.warrantyNone;
    final updated = _withWarrantyDates(
      before.copyWith(
        status: status,
        laborCost: newLaborCost,
        totalCost: newLaborCost + before.partsCost,
        warrantyType: warranty,
        warrantyDays: repaired ? warrantyDays ?? before.warrantyDays : null,
        warrantyStart: null,
        warrantyEnd: null,
        notes: publicNotes.isEmpty ? null : publicNotes,
        internalNotes: internalNotes.isEmpty ? null : internalNotes,
        updatedAt: now,
      ),
    );

    await _updateMaintenanceInCurrentShop(id, updated.toMap());
    await _syncWarranty(updated);
    await _syncFinancials(id);
    await _addStatusNotification(id, status);
    await _recordStatusHistory(
      maintenanceId: id,
      oldStatus: before.status,
      newStatus: status,
      reason: repaired ? 'تمت الصيانة وتجهيز الجهاز للتسليم' : 'تعذر الإصلاح',
      notes: repaired ? repairDetails : unrepairableReason,
    );
    await logAudit(
      maintenanceId: id,
      action: repaired ? 'حفظ نتيجة الصيانة' : 'حفظ تعذر الإصلاح',
      oldValue: before.status,
      newValue: status,
    );
    await _prepareWhatsappForStatus(id, status);
  }

  Future<void> _prepareWhatsappForStatus(
      String maintenanceId, String status) async {
    String? type;
    switch (status) {
      case AppConstants.statusNew:
      case AppConstants.statusWaitingInspection:
        type = AppConstants.waMsgReceived;
        break;
      case AppConstants.statusRepaired:
      case AppConstants.statusReady:
        type = AppConstants.waMsgReady;
        break;
      case AppConstants.statusWaitingPart:
        type = AppConstants.waMsgNeedsPart;
        break;
      case AppConstants.statusUnrepairable:
        type = AppConstants.waMsgUnrepairable;
        break;
      case AppConstants.statusDelivered:
        type = AppConstants.waMsgDelivered;
        break;
      case AppConstants.statusWarrantyReturn:
        type = AppConstants.waMsgWarrantyClaim;
        break;
    }
    if (type == null) return;
    await WhatsappRepository().prepareAndMaybeAutoSend(maintenanceId, type);
  }

  // ---------------------------------------------------------------------------
  // AUDIT LOG
  // ---------------------------------------------------------------------------

  /// Appends an immutable entry to the audit_log for a maintenance record.
  Future<void> logAudit({
    required String maintenanceId,
    required String action,
    String? oldValue,
    String? newValue,
    String? username,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db.insert('audit_log', {
        'id': const Uuid().v4(),
        'user_id': null,
        'username': username ?? 'النظام',
        'action': action,
        'table_name': 'maintenance',
        'record_id': maintenanceId,
        'old_value': oldValue,
        'new_value': newValue,
        'created_at': now,
      });
    } catch (_) {}
  }

  /// Returns the audit trail for a maintenance record, newest first.
  Future<List<Map<String, dynamic>>> getAuditLog(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    return _db.rawQuery(
      '''
      SELECT a.*
      FROM audit_log a
      JOIN maintenance m ON m.id = a.record_id
      WHERE m.shop_id = ?
        AND a.record_id = ?
        AND a.table_name = ?
      ORDER BY a.created_at DESC
      ''',
      [shopId, maintenanceId, 'maintenance'],
    );
  }

  Future<List<Map<String, dynamic>>> getStatusHistory(
      String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    return _db.rawQuery(
      '''
      SELECT h.*
      FROM maintenance_status_history h
      JOIN maintenance m ON m.id = h.maintenance_id
      WHERE m.shop_id = ?
        AND h.maintenance_id = ?
      ORDER BY h.changed_at DESC
      ''',
      [shopId, maintenanceId],
    );
  }

  Future<Map<String, dynamic>?> getChecklist(
    String maintenanceId,
    String checklistType,
  ) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT mc.*
      FROM maintenance_checklists mc
      JOIN maintenance m ON m.id = mc.maintenance_id
      WHERE m.shop_id = ?
        AND mc.maintenance_id = ?
        AND mc.checklist_type = ?
      LIMIT 1
      ''',
      [shopId, maintenanceId, checklistType],
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<void> saveChecklist({
    required String maintenanceId,
    required String checklistType,
    required Map<String, String> items,
    required String overallStatus,
    String? performedBy,
    String? approvedBy,
    String? notes,
  }) async {
    await _ensureCurrentShopMaintenance(maintenanceId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getChecklist(maintenanceId, checklistType);
    final data = {
      'id': existing?['id'] ?? const Uuid().v4(),
      'maintenance_id': maintenanceId,
      'checklist_type': checklistType,
      'items_json': jsonEncode(items),
      'overall_status': overallStatus,
      'performed_by': performedBy,
      'approved_by': approvedBy,
      'notes': notes,
      'checked_at': existing?['checked_at'] ?? now,
      'updated_at': now,
    };

    await _db.insert('maintenance_checklists', data);
    await logAudit(
      maintenanceId: maintenanceId,
      action: checklistType == 'final'
          ? 'حفظ الاختبار النهائي'
          : 'حفظ فحص الاستلام',
      newValue: overallStatus,
    );
  }

  Future<bool> hasApprovedFinalTest(String maintenanceId) async {
    final row = await getChecklist(maintenanceId, 'final');
    return row?['overall_status'] == 'passed';
  }

  Future<Map<String, dynamic>?> getCustomerApproval(
      String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT ma.*
      FROM maintenance_approvals ma
      JOIN maintenance m ON m.id = ma.maintenance_id
      WHERE m.shop_id = ?
        AND ma.maintenance_id = ?
      LIMIT 1
      ''',
      [shopId, maintenanceId],
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<void> saveCustomerApproval({
    required String maintenanceId,
    required String approvalStatus,
    required double offeredAmount,
    required double approvedAmount,
    required String approvalMethod,
    String? employeeName,
    String? customerMessage,
    String? terms,
  }) async {
    await _ensureCurrentShopMaintenance(maintenanceId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getCustomerApproval(maintenanceId);
    final isApproved = approvalStatus == 'approved';
    final data = {
      'id': existing?['id'] ?? const Uuid().v4(),
      'maintenance_id': maintenanceId,
      'approval_status': approvalStatus,
      'offered_amount': offeredAmount,
      'approved_amount': approvedAmount,
      'approval_method': approvalMethod,
      'employee_name': employeeName,
      'customer_message': customerMessage,
      'terms': terms,
      'approved_at': isApproved ? (existing?['approved_at'] ?? now) : null,
      'created_at': existing?['created_at'] ?? now,
      'updated_at': now,
    };

    await _db.insert('maintenance_approvals', data);
    await logAudit(
      maintenanceId: maintenanceId,
      action: 'حفظ موافقة العميل',
      newValue: approvalStatus,
    );
  }

  /// Looks up a maintenance record (with customer + technician) by ticket number
  /// or UUID. Returns null when not found.
  Future<Map<String, dynamic>?> getByTicketNumber(String code) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*, c.name AS customer_name, c.phone AS customer_phone,
       u.name AS technician_name
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN users    u ON m.technician_id = u.id
WHERE m.shop_id = ?
  AND (m.ticket_number = ? OR m.id = ?)
  AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, code, code]);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<void> delete(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT customer_id FROM maintenance WHERE shop_id = ? AND id = ? LIMIT 1',
      [shopId, id],
    );
    final customerId =
        rows.isEmpty ? null : rows.first['customer_id'] as String?;
    await _db.rawUpdate(
      'UPDATE maintenance SET deleted_at = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
      [
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
        shopId,
        id,
      ],
    );
    await _softDeleteFinancialTransaction(id);
    if (customerId != null) {
      await _recalculateCustomerStats(customerId);
    }
  }

  Future<void> _validateStatusTransition({
    required String id,
    required String? oldStatus,
    required String newStatus,
  }) async {
    if (!AppConstants.maintenanceStatuses.contains(newStatus)) {
      throw Exception('حالة الصيانة غير معروفة');
    }

    if (newStatus == AppConstants.statusReady &&
        oldStatus != AppConstants.statusReady &&
        !await hasApprovedFinalTest(id)) {
      throw Exception(
        'لا يمكن تحويل الطلب إلى جاهز للتسليم قبل حفظ اختبار نهائي ناجح',
      );
    }

    if (oldStatus == null || oldStatus == newStatus) return;

    final currentUser = AuthRepository().getCurrentUser();
    final role = currentUser?.role;
    final canOverride = currentUser == null ||
        role == AppConstants.roleOwner ||
        role == AppConstants.roleManager ||
        role == AppConstants.roleBranchManager;
    if (canOverride) return;

    final allowed =
        AppConstants.allowedMaintenanceTransitions[oldStatus] ?? const [];
    if (!allowed.contains(newStatus)) {
      throw Exception(
        'لا يمكن نقل الحالة من ${AppConstants.maintenanceStatusLabel(oldStatus)} إلى ${AppConstants.maintenanceStatusLabel(newStatus)} بدون صلاحية مدير',
      );
    }
  }

  Future<void> _recordStatusHistory({
    required String maintenanceId,
    required String? oldStatus,
    required String newStatus,
    String? reason,
    String? notes,
  }) async {
    final currentUser = AuthRepository().getCurrentUser();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('maintenance_status_history', {
      'id': const Uuid().v4(),
      'maintenance_id': maintenanceId,
      'old_status': oldStatus,
      'new_status': newStatus,
      'user_id': currentUser?.id,
      'username': currentUser?.username ?? 'النظام',
      'reason': reason,
      'notes': notes,
      'changed_at': now,
    });
  }

  MaintenanceModel _withWarrantyDates(MaintenanceModel maintenance) {
    final type = maintenance.warrantyType;
    final days = _warrantyDays(type, maintenance.warrantyDays);
    if (type == null || type == AppConstants.warrantyNone || days <= 0) {
      return maintenance.copyWith(
        warrantyType: AppConstants.warrantyNone,
        warrantyDays: null,
        warrantyStart: null,
        warrantyEnd: null,
      );
    }

    final start = maintenance.warrantyStart ?? maintenance.deliveredAt;
    if (start == null) {
      return maintenance.copyWith(
        warrantyType: type,
        warrantyDays: days,
        warrantyStart: null,
        warrantyEnd: null,
      );
    }
    final end = DateTime.fromMillisecondsSinceEpoch(start)
        .add(Duration(days: days))
        .millisecondsSinceEpoch;

    return maintenance.copyWith(
      warrantyType: type,
      warrantyDays: days,
      warrantyStart: start,
      warrantyEnd: end,
    );
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
        if (!AppConstants.isValidWarrantyDays(customDays)) {
          throw Exception('حدد مدة الضمان من يوم واحد إلى سنتين.');
        }
        return customDays!;
      default:
        return 0;
    }
  }

  Future<void> _syncWarranty(MaintenanceModel maintenance) async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final type = maintenance.warrantyType;
    final days = maintenance.warrantyDays ?? 0;

    if (type == null ||
        type == AppConstants.warrantyNone ||
        days <= 0 ||
        maintenance.warrantyStart == null ||
        maintenance.warrantyEnd == null) {
      await _db.rawUpdate(
        'UPDATE warranties SET is_void = 1, updated_at = ? WHERE shop_id = ? AND maintenance_id = ?',
        [now, shopId, maintenance.id],
      );
      return;
    }

    final existing = await _db.rawQuery(
      '''
      SELECT id, created_at, end_date, alert_disabled, alert_disabled_reason,
             alert_disabled_at, alert_disabled_by, expiry_approved,
             expiry_approved_at, expiry_approved_by
      FROM warranties
      WHERE shop_id = ? AND maintenance_id = ?
      LIMIT 1
      ''',
      [shopId, maintenance.id],
    );
    final id =
        existing.isEmpty ? const Uuid().v4() : existing.first['id'] as String;
    final createdAt =
        existing.isEmpty ? now : existing.first['created_at'] as int? ?? now;
    final existingEnd =
        existing.isEmpty ? null : existing.first['end_date'] as int?;
    final preserveAlertDisabled = existing.isNotEmpty &&
        (existing.first['alert_disabled'] as int? ?? 0) == 1 &&
        existingEnd == maintenance.warrantyEnd;
    final preserveExpiryApproved = existing.isNotEmpty &&
        (existing.first['expiry_approved'] as int? ?? 0) == 1 &&
        existingEnd == maintenance.warrantyEnd;
    final deviceInfo = [
      maintenance.brand,
      maintenance.model,
      if (maintenance.imei != null && maintenance.imei!.isNotEmpty)
        'IMEI: ${maintenance.imei}',
    ].join(' ');

    final data = {
      'id': id,
      'shop_id': shopId,
      'maintenance_id': maintenance.id,
      'customer_id': maintenance.customerId,
      'device_info': deviceInfo,
      'warranty_type': type,
      'warranty_days': days,
      'start_date': maintenance.warrantyStart,
      'end_date': maintenance.warrantyEnd,
      'notes': maintenance.notes,
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
      'expiry_approved_at':
          preserveExpiryApproved ? existing.first['expiry_approved_at'] : null,
      'expiry_approved_by':
          preserveExpiryApproved ? existing.first['expiry_approved_by'] : null,
      'created_at': createdAt,
      'updated_at': now,
    };

    if (existing.isEmpty) {
      await _db.insert('warranties', data);
      final user = AuthRepository().getCurrentUser();
      await _db.insert('warranty_actions', {
        'id': const Uuid().v4(),
        'shop_id': shopId,
        'warranty_id': id,
        'maintenance_id': maintenance.id,
        'action': 'created',
        'old_value': null,
        'new_value': '${maintenance.warrantyDays ?? 0} يوم',
        'user_id': user?.id,
        'username': user?.username ?? user?.name ?? 'النظام',
        'notes': null,
        'created_at': now,
      });
    } else {
      await _db.update('warranties', data, id);
    }
  }

  // ---------------------------------------------------------------------------
  // PARTS
  // ---------------------------------------------------------------------------

  Future<List<MaintenancePartModel>> getParts(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT p.*
      FROM maintenance_parts p
      JOIN maintenance m ON m.id = p.maintenance_id
      WHERE m.shop_id = ?
        AND p.maintenance_id = ?
      ORDER BY p.created_at ASC
      ''',
      [shopId, maintenanceId],
    );
    return rows.map(MaintenancePartModel.fromMap).toList();
  }

  Future<void> addPart(MaintenancePartModel part) async {
    await _ensureCurrentShopMaintenance(part.maintenanceId);
    // When linked to a product, capture purchase_price as cost for profit tracking.
    MaintenancePartModel partToSave = part;
    if (part.productId != null && part.purchaseCost <= 0) {
      try {
        final rows = await _db.rawQuery(
          'SELECT purchase_price FROM products WHERE id = ? LIMIT 1',
          [part.productId],
        );
        if (rows.isNotEmpty) {
          final cost =
              (rows.first['purchase_price'] as num?)?.toDouble() ?? 0.0;
          if (cost > 0) partToSave = part.copyWith(purchaseCost: cost);
        }
      } catch (_) {}
    }

    await _db.insert('maintenance_parts', partToSave.toMap());

    // Decrease product quantity if linked to a product
    if (partToSave.productId != null) {
      final productRows = await _db.rawQuery(
        'SELECT quantity, is_service FROM products WHERE id = ? LIMIT 1',
        [partToSave.productId],
      );
      if (productRows.isNotEmpty) {
        final available = (productRows.first['quantity'] as num?)?.toInt() ?? 0;
        final isService = (productRows.first['is_service'] as int? ?? 0) == 1;
        final requested = partToSave.quantity.toInt();
        if (!isService && requested > available) {
          await _db.rawDelete(
            'DELETE FROM maintenance_parts WHERE id = ?',
            [partToSave.id],
          );
          throw Exception(
            'الكمية المتوفرة من ${partToSave.productName} لا تكفي. المتوفر: $available',
          );
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.rawUpdate(
        'UPDATE products SET quantity = quantity - ?, updated_at = ? WHERE id = ?',
        [partToSave.quantity.toInt(), now, partToSave.productId],
      );
    }

    // Recalculate parts_cost and total_cost on the maintenance record
    await _recalculateCosts(partToSave.maintenanceId);
  }

  Future<void> removePart(String partId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT p.*
      FROM maintenance_parts p
      JOIN maintenance m ON m.id = p.maintenance_id
      WHERE m.shop_id = ?
        AND p.id = ?
      LIMIT 1
      ''',
      [shopId, partId],
    );
    if (rows.isEmpty) return;
    final part = MaintenancePartModel.fromMap(rows.first);

    await _db.rawDelete(
      'DELETE FROM maintenance_parts WHERE id = ?',
      [partId],
    );

    // Restore product quantity
    if (part.productId != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.rawUpdate(
        'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
        [part.quantity.toInt(), now, part.productId],
      );
    }

    await _recalculateCosts(part.maintenanceId);
  }

  Future<void> _recalculateCosts(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final sumRows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(p.total_price), 0) AS parts_total
      FROM maintenance_parts p
      JOIN maintenance m ON m.id = p.maintenance_id
      WHERE m.shop_id = ?
        AND p.maintenance_id = ?
      ''',
      [shopId, maintenanceId],
    );
    final partsTotal =
        (sumRows.first['parts_total'] as num?)?.toDouble() ?? 0.0;

    final mRows = await _db.query(
      'maintenance',
      where: 'shop_id = ? AND id = ?',
      whereArgs: [shopId, maintenanceId],
      columns: ['labor_cost'],
      limit: 1,
    );
    final laborCost =
        mRows.isNotEmpty ? (mRows.first['labor_cost'] as num).toDouble() : 0.0;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE maintenance SET parts_cost = ?, total_cost = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
      [partsTotal, laborCost + partsTotal, now, shopId, maintenanceId],
    );
    await _syncFinancials(maintenanceId);
  }

  // ---------------------------------------------------------------------------
  // FINANCIAL SYNC
  // ---------------------------------------------------------------------------

  Future<void> syncAllFinancials() async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT id FROM maintenance WHERE shop_id = ? ORDER BY created_at ASC',
      [shopId],
    );
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id != null) {
        await _syncFinancials(id);
      }
    }

    await _db.rawUpdate(
      '''
      UPDATE transactions
      SET deleted_at = ?
      WHERE reference_type = 'maintenance'
        AND deleted_at IS NULL
        AND reference_id IN (SELECT id FROM maintenance WHERE shop_id = ?)
        AND reference_id NOT IN (SELECT id FROM maintenance WHERE shop_id = ? AND deleted_at IS NULL)
      ''',
      [DateTime.now().millisecondsSinceEpoch, shopId, shopId],
    );

    final customers = await _db.rawQuery(
      'SELECT id FROM customers WHERE shop_id = ? AND deleted_at IS NULL',
      [shopId],
    );
    for (final row in customers) {
      final id = row['id'] as String?;
      if (id != null) {
        await _recalculateCustomerStats(id);
      }
    }
  }

  Future<void> _syncFinancials(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT * FROM maintenance WHERE shop_id = ? AND id = ? LIMIT 1',
      [shopId, maintenanceId],
    );
    if (rows.isEmpty) {
      await _softDeleteFinancialTransaction(maintenanceId);
      return;
    }

    final maintenance = MaintenanceModel.fromMap(rows.first);
    if (maintenance.deletedAt != null ||
        maintenance.status == AppConstants.statusCancelled ||
        maintenance.totalCost <= 0) {
      await _softDeleteFinancialTransaction(maintenanceId);
      await _recalculateCustomerStats(maintenance.customerId);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.rawQuery(
      '''
      SELECT id, created_at
      FROM transactions
      WHERE reference_type = 'maintenance'
        AND reference_id = ?
      LIMIT 1
      ''',
      [maintenanceId],
    );

    final txId =
        existing.isEmpty ? const Uuid().v4() : existing.first['id'] as String;
    final createdAt =
        existing.isEmpty ? now : existing.first['created_at'] as int? ?? now;
    final data = {
      'id': txId,
      'type': AppConstants.txIncome,
      'category': 'maintenance',
      'description':
          'صيانة - ${maintenance.ticketNumber} - ${maintenance.brand} ${maintenance.model}',
      'amount': maintenance.totalCost,
      'reference_id': maintenance.id,
      'reference_type': 'maintenance',
      'payment_method': AppConstants.paymentCash,
      'transaction_date': maintenance.createdAt,
      'notes': maintenance.faultDescription,
      'created_by': maintenance.createdBy,
      'created_at': createdAt,
      'deleted_at': null,
    };

    await _db.insert('transactions', data);
    await _recalculateCustomerStats(maintenance.customerId);
  }

  Future<void> _softDeleteFinancialTransaction(String maintenanceId) async {
    await _db.rawUpdate(
      '''
      UPDATE transactions
      SET deleted_at = ?
      WHERE reference_type = 'maintenance'
        AND reference_id = ?
        AND deleted_at IS NULL
      ''',
      [DateTime.now().millisecondsSinceEpoch, maintenanceId],
    );
  }

  Future<void> _recalculateCustomerStats(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final sales = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0) AS total,
        COUNT(*) AS visits,
        MAX(created_at) AS last_visit
      FROM sales
      WHERE customer_id = ? AND deleted_at IS NULL
      ''',
      [customerId],
    );
    final maintenance = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total_cost), 0) AS total,
        COUNT(*) AS visits,
        MAX(created_at) AS last_visit
      FROM maintenance
      WHERE shop_id = ?
        AND customer_id = ?
        AND deleted_at IS NULL
        AND status != ?
      ''',
      [shopId, customerId, AppConstants.statusCancelled],
    );

    final salesRow = sales.first;
    final maintenanceRow = maintenance.first;
    final totalSpent = ((salesRow['total'] as num?)?.toDouble() ?? 0.0) +
        ((maintenanceRow['total'] as num?)?.toDouble() ?? 0.0);
    final visitCount = ((salesRow['visits'] as num?)?.toInt() ?? 0) +
        ((maintenanceRow['visits'] as num?)?.toInt() ?? 0);
    final lastVisit = [
      salesRow['last_visit'] as int?,
      maintenanceRow['last_visit'] as int?,
    ].whereType<int>().fold<int?>(null, (latest, value) {
      if (latest == null || value > latest) return value;
      return latest;
    });

    await _db.rawUpdate(
      '''
      UPDATE customers
      SET total_spent = ?,
          visit_count = ?,
          last_visit = ?,
          updated_at = ?
      WHERE shop_id = ? AND id = ?
      ''',
      [
        totalSpent,
        visitCount,
        lastVisit,
        DateTime.now().millisecondsSinceEpoch,
        shopId,
        customerId,
      ],
    );
  }

  Future<void> _addStatusNotification(
      String maintenanceId, String status) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT m.ticket_number, m.brand, m.model, c.name AS customer_name
      FROM maintenance m
      LEFT JOIN customers c ON c.id = m.customer_id AND c.shop_id = m.shop_id
      WHERE m.shop_id = ?
        AND m.id = ?
        AND m.deleted_at IS NULL
      LIMIT 1
      ''',
      [shopId, maintenanceId],
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final ticket = row['ticket_number'] as String? ?? '';
    final device = '${row['brand'] ?? ''} ${row['model'] ?? ''}'.trim();
    final customer = row['customer_name'] as String? ?? 'العميل';
    final label = _statusLabel(status);
    final type = 'maintenance_status_$status';
    final existing = await _db.rawQuery(
      '''
      SELECT id FROM notifications
      WHERE shop_id = ?
        AND reference_id = ?
        AND reference_type = 'maintenance'
        AND type = ?
        AND is_read = 0
      LIMIT 1
      ''',
      [shopId, maintenanceId, type],
    );
    if (existing.isNotEmpty) return;

    final priority = status == AppConstants.statusReady ||
            status == AppConstants.statusRepaired ||
            status == AppConstants.statusWaitingPart
        ? AppConstants.priorityCritical
        : AppConstants.priorityHigh;

    await _db.insert('notifications', {
      'id': const Uuid().v4(),
      'shop_id': shopId,
      'title': 'تنبيه حالة الصيانة: $label',
      'message':
          '$device للعميل $customer أصبح: $label. اضغط لفتح الصيانة أو أرسل واتساب للعميل. رقم الصيانة: $ticket',
      'type': type,
      'priority': priority,
      'reference_id': maintenanceId,
      'reference_type': 'maintenance',
      'is_read': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _ensureCurrentShopMaintenance(String maintenanceId) async {
    final exists = await getById(maintenanceId);
    if (exists == null) {
      throw Exception('سجل الصيانة غير موجود في هذا المحل');
    }
  }

  Future<void> _updateMaintenanceInCurrentShop(
    String maintenanceId,
    Map<String, dynamic> data,
  ) async {
    final shopId = await _db.getCurrentShopId();
    final database = await _db.db;
    final count = await database.update(
      'maintenance',
      {...data, 'shop_id': shopId},
      where: 'shop_id = ? AND id = ?',
      whereArgs: [shopId, maintenanceId],
    );
    if (count == 0) {
      throw Exception('سجل الصيانة غير موجود في هذا المحل');
    }
  }

  String _statusLabel(String status) {
    return AppConstants.maintenanceStatusLabel(status);
  }

  // ---------------------------------------------------------------------------
  // IMAGES
  // ---------------------------------------------------------------------------

  Future<List<MaintenanceImageModel>> getImages(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT i.*
      FROM maintenance_images i
      JOIN maintenance m ON m.id = i.maintenance_id
      WHERE m.shop_id = ?
        AND i.maintenance_id = ?
      ORDER BY i.created_at ASC
      ''',
      [shopId, maintenanceId],
    );
    return rows.map(MaintenanceImageModel.fromMap).toList();
  }

  Future<void> addImage(MaintenanceImageModel image) async {
    await _ensureCurrentShopMaintenance(image.maintenanceId);
    await _db.insert('maintenance_images', image.toMap());
  }

  Future<void> removeImage(String imageId) async {
    final shopId = await _db.getCurrentShopId();
    await _db.rawDelete(
      '''
      DELETE FROM maintenance_images
      WHERE id = ?
        AND maintenance_id IN (
          SELECT id FROM maintenance WHERE shop_id = ?
        )
      ''',
      [imageId, shopId],
    );
  }

  // ---------------------------------------------------------------------------
  // TICKET NUMBER
  // ---------------------------------------------------------------------------

  Future<String> generateTicketNumber() async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'MNT-$datePart-';

    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM maintenance WHERE shop_id = ? AND ticket_number LIKE ?",
      [shopId, '$prefix%'],
    );
    final count = (rows.first['cnt'] as int? ?? 0) + 1;
    return '$prefix${count.toString().padLeft(4, '0')}';
  }

  // ---------------------------------------------------------------------------
  // ABANDONED DEVICES
  // ---------------------------------------------------------------------------

  Future<List<MaintenanceModel>> getAbandonedDevices(int days) async {
    final shopId = await _db.getCurrentShopId();
    final cutoffMs =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = await _db.rawQuery('''
SELECT m.*, c.name AS customer_name, u.name AS technician_name
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN users u ON m.technician_id = u.id
WHERE m.status = 'ready'
  AND m.shop_id = ?
  AND m.deleted_at IS NULL
  AND m.updated_at <= ?
ORDER BY m.updated_at ASC
''', [shopId, cutoffMs]);
    return rows.map(MaintenanceModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD STATS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getDashboardStats() async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final startOfMonth =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final activeStatuses = AppConstants.maintenanceStatuses
        .where((status) =>
            !AppConstants.isMaintenanceTerminalStatus(status) &&
            status != AppConstants.statusReady)
        .toList();
    final placeholders = List.filled(activeStatuses.length, '?').join(',');
    final underRepairRow = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM maintenance WHERE shop_id = ? AND deleted_at IS NULL AND status IN ($placeholders)',
      [shopId, ...activeStatuses],
    );
    final readyRow = await _db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM maintenance WHERE shop_id = ? AND deleted_at IS NULL AND status = 'ready'",
      [shopId],
    );
    final todayDeliveredRow = await _db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM maintenance WHERE shop_id = ? AND deleted_at IS NULL AND status = 'delivered' AND delivered_at >= ?",
      [shopId, startOfDay],
    );
    final totalMonthRow = await _db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM maintenance WHERE shop_id = ? AND deleted_at IS NULL AND created_at >= ?",
      [shopId, startOfMonth],
    );

    return {
      'underRepair': (underRepairRow.first['cnt'] as int? ?? 0),
      'readyForDelivery': (readyRow.first['cnt'] as int? ?? 0),
      'todayDelivered': (todayDeliveredRow.first['cnt'] as int? ?? 0),
      'totalThisMonth': (totalMonthRow.first['cnt'] as int? ?? 0),
    };
  }
}
