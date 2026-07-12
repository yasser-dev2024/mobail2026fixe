import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/document_share_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../customers/data/customer_model.dart';
import '../../customers/data/customers_repository.dart';
import '../../device_photos/data/device_photo_repository.dart';
import '../../devices/data/device_model.dart';
import '../../devices/data/devices_repository.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/data/maintenance_part_model.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../../warranty/data/warranty_claim_model.dart';
import '../../warranty/data/warranty_model.dart';
import '../../warranty/data/warranty_repository.dart';
import '../../warranty/services/warranty_pdf_service.dart';
import '../../whatsapp/data/whatsapp_repository.dart';

class RepairBoardRepository {
  RepairBoardRepository();

  final DatabaseService _db = DatabaseService();
  final MaintenanceRepository _maintenanceRepo = MaintenanceRepository();
  final CustomersRepository _customersRepo = CustomersRepository();
  final DevicesRepository _devicesRepo = DevicesRepository();
  final DevicePhotoRepository _devicePhotoRepo = DevicePhotoRepository();
  final WarrantyRepository _warrantyRepo = WarrantyRepository();
  final WhatsappRepository _whatsappRepo = WhatsappRepository();
  final WarrantyPdfService _warrantyPdfService = WarrantyPdfService();

  static const activeStatuses = <String>[
    AppConstants.statusNew,
    AppConstants.statusRepairing,
    AppConstants.statusWaitingPart,
    AppConstants.statusReady,
    AppConstants.statusWarrantyReturn,
  ];

  Future<RepairBoardData> loadBoard({String? search}) async {
    await _warrantyRepo.syncFromMaintenance();

    final shopId = await _db.getCurrentShopId();
    final query = (search ?? '').trim();
    final placeholders = List.filled(activeStatuses.length, '?').join(',');
    final args = <dynamic>[shopId, ...activeStatuses];
    var searchSql = '';

    if (query.isNotEmpty) {
      final pattern = '%$query%';
      searchSql = '''
        AND (
          m.ticket_number LIKE ?
          OR m.brand LIKE ?
          OR m.model LIKE ?
          OR m.imei LIKE ?
          OR m.fault_description LIKE ?
          OR c.name LIKE ?
          OR c.phone LIKE ?
        )
      ''';
      args.addAll(
          [pattern, pattern, pattern, pattern, pattern, pattern, pattern]);
    }

    final rows = await _db.rawQuery('''
SELECT m.*,
       c.name AS customer_name,
       c.phone AS customer_phone,
       u.name AS technician_name,
       creator.name AS created_by_name
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN devices d ON m.device_id = d.id AND d.shop_id = m.shop_id
LEFT JOIN users u ON m.technician_id = u.id
LEFT JOIN users creator ON m.created_by = creator.id
WHERE m.deleted_at IS NULL
  AND m.shop_id = ?
  AND (m.customer_id IS NULL OR c.deleted_at IS NULL)
  AND (m.device_id IS NULL OR d.deleted_at IS NULL)
  AND m.status IN ($placeholders)
  $searchSql
ORDER BY
  CASE m.status
    WHEN '${AppConstants.statusReady}' THEN 0
    WHEN '${AppConstants.statusNew}' THEN 1
    WHEN '${AppConstants.statusWarrantyReturn}' THEN 2
    WHEN '${AppConstants.statusWaitingPart}' THEN 3
    ELSE 4
  END,
  m.updated_at DESC
''', args);

    final active = <RepairDeviceCard>[];
    for (final row in rows) {
      final maintenance = MaintenanceModel.fromMap(row);
      active.add(
        RepairDeviceCard(
          maintenance: maintenance,
          requiredParts: await _loadPartNames(maintenance.id),
          isWarrantyWork: await _isWarrantyWork(maintenance.id),
          latestWarrantyProblem: await _latestWarrantyProblem(maintenance.id),
          deviceRepairCount: await _countDeviceRepairs(maintenance),
          customerDeviceCount: await _countCustomerDevices(maintenance),
          readyAt: await _statusChangedAt(
            maintenance.id,
            AppConstants.statusReady,
          ),
        ),
      );
    }

    final warranties = await _warrantyRepo.getAll();
    final visibleWarranties = warranties.where((warranty) {
      if (query.isEmpty) return true;
      final haystack = [
        warranty.customerName,
        warranty.deviceInfo,
        warranty.ticketNumber,
        warranty.statusLabel,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query.toLowerCase());
    }).toList();

    return RepairBoardData(
      activeDevices: active,
      warranties: visibleWarranties,
      customerResults: await _searchCustomers(query),
      activeMaintenanceIds: active.map((e) => e.maintenance.id).toSet(),
    );
  }

  Future<List<RepairCustomerResult>> _searchCustomers(String query) async {
    if (query.trim().length < 2) return const [];

    final pattern = '%${query.trim()}%';
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final digitPattern = '%${digits.isEmpty ? query.trim() : digits}%';
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT *
      FROM customers
      WHERE shop_id = ?
        AND deleted_at IS NULL
        AND (
          name LIKE ?
          OR phone LIKE ?
          OR IFNULL(phone2, '') LIKE ?
          OR REPLACE(REPLACE(REPLACE(IFNULL(phone, ''), ' ', ''), '-', ''), '+', '') LIKE ?
          OR REPLACE(REPLACE(REPLACE(IFNULL(phone2, ''), ' ', ''), '-', ''), '+', '') LIKE ?
        )
      ORDER BY name ASC
      LIMIT 8
      ''',
      [shopId, pattern, pattern, pattern, digitPattern, digitPattern],
    );

    final results = <RepairCustomerResult>[];
    for (final row in rows) {
      final customer = CustomerModel.fromMap(row);
      results.add(
        RepairCustomerResult(
          customer: customer,
          deviceCount: await _countDevicesForCustomer(customer.id),
          maintenanceCount: await _countMaintenanceForCustomer(customer.id),
        ),
      );
    }
    return results;
  }

  Future<int> _countDevicesForCustomer(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM devices WHERE shop_id = ? AND customer_id = ? AND deleted_at IS NULL',
      [shopId, customerId],
    );
    return rows.first['count'] as int? ?? 0;
  }

  Future<int> _countMaintenanceForCustomer(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM maintenance WHERE shop_id = ? AND customer_id = ? AND deleted_at IS NULL',
      [shopId, customerId],
    );
    return rows.first['count'] as int? ?? 0;
  }

  Future<String> receiveNewDevice(RepairIntakeData data) async {
    if (data.receiverName.trim().isEmpty) {
      throw Exception('حدد اسم مستلم الجهاز.');
    }
    final phone = data.customerPhone.trim();
    if (_whatsappRepo.normalizePhone(phone) == null) {
      throw Exception('رقم الجوال غير صحيح. اكتب رقماً صالحاً لواتساب.');
    }

    final customer = await _findOrCreateCustomer(data);
    final device = await _findOrCreateDevice(customer.id, data);
    final ticket = await _maintenanceRepo.generateTicketNumber();
    final userId = AuthRepository().getCurrentUser()?.id ?? 'user_admin';
    final notes = _publicIntakeNotes(data);
    final internalNotes = _internalIntakeNotes(data);

    final maintenance = MaintenanceModel.create(
      ticketNumber: ticket,
      customerId: customer.id,
      deviceId: device.id,
      brand: data.brandOrType,
      model: data.model.trim(),
      imei: data.imei.trim().isEmpty ? null : data.imei.trim(),
      color: data.color.trim().isEmpty ? null : data.color.trim(),
      faultDescription: data.problem.trim(),
      warrantyType: AppConstants.warrantyNone,
      createdBy: userId,
      notes: notes,
      internalNotes: internalNotes,
    ).copyWith(status: AppConstants.statusNew);

    final id = await _maintenanceRepo.create(maintenance);
    await _saveDevicePhotos(
      paths: data.imagePaths,
      maintenance: maintenance.copyWith(id: id),
      stage: AppConstants.photoStageIntake,
      photoType: 'صور الاستلام',
      caption: data.deviceCondition.trim().isEmpty
          ? data.problem.trim()
          : data.deviceCondition.trim(),
    );
    return id;
  }

  Future<void> markUnderRepair(String maintenanceId, {String? note}) async {
    await _maintenanceRepo.updateStatus(
      maintenanceId,
      AppConstants.statusRepairing,
      reason: 'تغيير مبسط من البطاقة',
      notes: _emptyToNull(note),
    );
  }

  Future<void> markNeedsPart({
    required String maintenanceId,
    required String partName,
  }) async {
    final cleanPart = partName.trim();
    if (cleanPart.isEmpty) {
      throw Exception('اكتب اسم القطعة المطلوبة.');
    }

    await _maintenanceRepo.addPart(
      MaintenancePartModel.create(
        maintenanceId: maintenanceId,
        productName: cleanPart,
        quantity: 1,
        unitPrice: 0,
      ),
    );
    await _maintenanceRepo.updateStatus(
      maintenanceId,
      AppConstants.statusWaitingPart,
      reason: 'الجهاز يحتاج قطعة غيار',
      notes: cleanPart,
    );
  }

  Future<void> markReady({
    required String maintenanceId,
    required String repairDetails,
    String? changedPart,
    double? cost,
    int? warrantyDays,
    String? notes,
    List<String> afterImagePaths = const [],
  }) async {
    if (repairDetails.trim().isEmpty) {
      throw Exception('اكتب الصيانة التي تمت.');
    }
    final validWarrantyDays = _requireWarrantyDays(warrantyDays);

    await _maintenanceRepo.saveRepairResult(
      id: maintenanceId,
      repaired: true,
      repairDetails: repairDetails.trim(),
      changedPart: _emptyToNull(changedPart),
      technicianNotes: _emptyToNull(notes),
      laborCost: cost ?? 0,
      warrantyType: AppConstants.warrantyCustom,
      warrantyDays: validWarrantyDays,
    );

    final updated = await _maintenanceRepo.getById(maintenanceId);
    if (updated != null) {
      await _saveDevicePhotos(
        paths: afterImagePaths,
        maintenance: updated,
        stage: AppConstants.photoStageAfterRepair,
        photoType: 'صور بعد الصيانة',
        caption: repairDetails.trim(),
      );
    }
  }

  Future<void> confirmDelivery({
    required String maintenanceId,
    required double paidAmount,
    required int warrantyDays,
    String? deliveryCondition,
    String? receiverName,
    String? warrantyTerms,
    String? notes,
  }) async {
    final current = await _maintenanceRepo.getById(maintenanceId);
    if (current == null) throw Exception('سجل الجهاز غير موجود.');
    final validWarrantyDays = _requireWarrantyDays(warrantyDays);

    final deliveryNotes = [
      if ((deliveryCondition ?? '').trim().isNotEmpty)
        'حالة الجهاز عند التسليم: ${deliveryCondition!.trim()}',
      if ((receiverName ?? '').trim().isNotEmpty)
        'اسم المستلم: ${receiverName!.trim()}',
      if ((warrantyTerms ?? '').trim().isNotEmpty)
        'شروط الضمان: ${warrantyTerms!.trim()}',
      if ((notes ?? '').trim().isNotEmpty) 'ملاحظات التسليم: ${notes!.trim()}',
    ].join('\n');

    final updated = current.copyWith(
      advancePaid: paidAmount,
      warrantyType: AppConstants.warrantyCustom,
      warrantyDays: validWarrantyDays,
      internalNotes: _appendNote(current.internalNotes, deliveryNotes),
      notes: _appendNote(
          current.notes,
          (warrantyTerms ?? '').trim().isEmpty
              ? ''
              : 'شروط الضمان: ${warrantyTerms!.trim()}'),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _maintenanceRepo.update(updated);
    await _maintenanceRepo.updateStatus(
      maintenanceId,
      AppConstants.statusDelivered,
      reason: 'تأكيد التسليم وبدء الضمان',
      notes: deliveryNotes.isEmpty ? null : deliveryNotes,
    );
  }

  Future<void> receiveUnderWarranty({
    required WarrantyModel warranty,
    required String problem,
    String? customerDescription,
    String? deviceCondition,
    String? employeeNotes,
    List<String> imagePaths = const [],
  }) async {
    if (warranty.status == 'expired' || warranty.isVoid) {
      throw Exception('انتهى الضمان، يجب استلام الجهاز كطلب صيانة جديد.');
    }
    final cleanProblem = problem.trim();
    if (cleanProblem.isEmpty) {
      throw Exception('اكتب المشكلة الحالية.');
    }

    final description = [
      cleanProblem,
      if ((customerDescription ?? '').trim().isNotEmpty)
        'وصف العميل: ${customerDescription!.trim()}',
      if ((deviceCondition ?? '').trim().isNotEmpty)
        'حالة الجهاز عند العودة: ${deviceCondition!.trim()}',
      if ((employeeNotes ?? '').trim().isNotEmpty)
        'ملاحظات الموظف: ${employeeNotes!.trim()}',
    ].join('\n');

    await _warrantyRepo.addClaim(
      WarrantyClaimModel.create(
        warrantyId: warranty.id,
        maintenanceId: warranty.maintenanceId,
        description: description,
      ),
    );

    await _maintenanceRepo.updateStatus(
      warranty.maintenanceId,
      AppConstants.statusWarrantyReturn,
      reason: 'استلام الجهاز تحت الضمان',
      notes: description,
    );

    final updated = await _maintenanceRepo.getById(warranty.maintenanceId);
    if (updated != null) {
      await _saveDevicePhotos(
        paths: imagePaths,
        maintenance: updated,
        stage: AppConstants.photoStageEvidence,
        photoType: 'استلام ضمان',
        caption: cleanProblem,
      );
    }
  }

  Future<void> _saveDevicePhotos({
    required List<String> paths,
    required MaintenanceModel maintenance,
    required String stage,
    required String photoType,
    String? caption,
  }) async {
    for (final path in paths) {
      await _devicePhotoRepo.saveFromSource(
        sourcePath: path,
        customerId: maintenance.customerId,
        deviceId: maintenance.deviceId,
        maintenanceId: maintenance.id,
        stage: stage,
        photoType: photoType,
        caption: _emptyToNull(caption),
      );
    }
  }

  Future<void> sendReadyWhatsapp(String maintenanceId) async {
    final message = await _whatsappRepo.prepareMaintenanceMessage(
      maintenanceId,
      AppConstants.waMsgReady,
      forceNew: true,
    );
    await _whatsappRepo.sendPreparedMessage(
      message.id,
      message: message.message,
      sentBy: AuthRepository().getCurrentUser()?.username ?? 'النظام',
    );
  }

  Future<void> sendWarrantyClaimWhatsapp(String maintenanceId) async {
    final message = await _whatsappRepo.prepareMaintenanceMessage(
      maintenanceId,
      AppConstants.waMsgWarrantyClaim,
      forceNew: true,
    );
    await _whatsappRepo.sendPreparedMessage(
      message.id,
      message: message.message,
      sentBy: AuthRepository().getCurrentUser()?.username ?? 'النظام',
    );
  }

  Future<void> sendWarrantyWhatsapp(WarrantyModel warranty) async {
    if (warranty.status == 'expired' || warranty.isVoid) {
      throw Exception('لا يمكن إرسال رسالة ضمان بعد انتهاء الضمان.');
    }

    final pdf = await _warrantyPdfService.createForMaintenance(
      warranty.maintenanceId,
    );
    final message = [
      'مرحباً ${pdf.customerName}،',
      '',
      'تم تجهيز ملف ضمان الصيانة PDF الخاص بجهازكم.',
      'رقم الطلب: ${pdf.ticketNumber}',
      '',
      'يرجى الاطلاع على ملف الضمان المرفق في هذه المحادثة.',
      'شكراً لاختياركم خدماتنا.',
    ].join('\n');

    final ok = await DocumentShareService.sharePdfToWhatsApp(
      filePath: pdf.filePath,
      phone: pdf.customerPhone,
      message: message,
    );
    if (!ok) {
      throw Exception('تعذر فتح واتساب أو مشاركة ملف PDF.');
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    await _customersRepo.delete(customerId);
  }

  Future<void> deleteDevice(String deviceId) async {
    await _devicesRepo.delete(deviceId);
  }

  Future<CustomerModel> _findOrCreateCustomer(RepairIntakeData data) async {
    if ((data.customerId ?? '').trim().isNotEmpty) {
      final customer = await _customersRepo.getById(data.customerId!.trim());
      if (customer == null) {
        throw Exception('ملف العميل المحدد غير موجود.');
      }
      final phone2 = data.customerPhone2.trim();
      if (phone2.isNotEmpty && (customer.phone2 ?? '').isEmpty) {
        final updated = customer.copyWith(phone2: phone2);
        await _customersRepo.update(updated);
        return updated;
      }
      return customer;
    }

    final phone = data.customerPhone.trim();
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT *
FROM customers
WHERE shop_id = ?
  AND deleted_at IS NULL
  AND (phone = ? OR phone2 = ?)
LIMIT 1
''', [shopId, phone, phone]);
    if (rows.isNotEmpty) {
      final customer = CustomerModel.fromMap(rows.first);
      final phone2 = data.customerPhone2.trim();
      if (phone2.isNotEmpty && (customer.phone2 ?? '').isEmpty) {
        final updated = customer.copyWith(phone2: phone2);
        await _customersRepo.update(updated);
        return updated;
      }
      return customer;
    }

    final customer = CustomerModel.create(
      name: data.customerName.trim(),
      phone: phone,
      phone2: data.customerPhone2.trim().isEmpty
          ? null
          : data.customerPhone2.trim(),
    );
    await _customersRepo.create(customer);
    return customer;
  }

  Future<DeviceModel> _findOrCreateDevice(
    String customerId,
    RepairIntakeData data,
  ) async {
    if ((data.deviceId ?? '').trim().isNotEmpty) {
      final device = await _devicesRepo.getById(data.deviceId!.trim());
      if (device == null) {
        throw Exception('الجوال المحدد غير موجود في ملف العميل.');
      }
      if (device.customerId != customerId) {
        throw Exception('الجوال المحدد لا يتبع العميل المختار.');
      }
      return device;
    }

    final imei = data.imei.trim();
    if (imei.isNotEmpty) {
      final existing = await _devicesRepo.searchByImei(imei);
      if (existing != null) {
        if (existing.customerId != customerId) {
          throw Exception('رقم IMEI مسجل لعميل آخر.');
        }
        return existing;
      }
    }

    final device = DeviceModel.create(
      customerId: customerId,
      brand: data.brandOrType,
      model: data.model.trim(),
      imei: imei.isEmpty ? null : imei,
      serialNumber: data.serial.trim().isEmpty ? null : data.serial.trim(),
      color: data.color.trim().isEmpty ? null : data.color.trim(),
      notes: data.deviceType.trim().isEmpty
          ? null
          : 'نوع الجهاز: ${data.deviceType.trim()}',
    );
    await _devicesRepo.create(device);
    return device;
  }

  Future<List<String>> _loadPartNames(String maintenanceId) async {
    final rows = await _db.query(
      'maintenance_parts',
      columns: ['product_name'],
      where: 'maintenance_id = ?',
      whereArgs: [maintenanceId],
      orderBy: 'created_at DESC',
      limit: 3,
    );
    return rows
        .map((row) => row['product_name']?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }

  Future<bool> _isWarrantyWork(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT id FROM warranty_claims WHERE shop_id = ? AND maintenance_id = ? LIMIT 1',
      [shopId, maintenanceId],
    );
    return rows.isNotEmpty;
  }

  Future<String?> _latestWarrantyProblem(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT description
FROM warranty_claims
WHERE shop_id = ? AND maintenance_id = ?
ORDER BY created_at DESC
LIMIT 1
''', [shopId, maintenanceId]);
    if (rows.isEmpty) return null;
    return _emptyToNull(rows.first['description']?.toString());
  }

  Future<int> _countDeviceRepairs(MaintenanceModel maintenance) async {
    final deviceId = maintenance.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) return 1;
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM maintenance WHERE shop_id = ? AND device_id = ? AND deleted_at IS NULL',
      [shopId, deviceId],
    );
    return rows.first['count'] as int? ?? 1;
  }

  Future<int> _countCustomerDevices(MaintenanceModel maintenance) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM devices WHERE shop_id = ? AND customer_id = ? AND deleted_at IS NULL',
      [shopId, maintenance.customerId],
    );
    return rows.first['count'] as int? ?? 1;
  }

  Future<int?> _statusChangedAt(String maintenanceId, String status) async {
    final rows = await _db.rawQuery('''
SELECT changed_at
FROM maintenance_status_history
WHERE maintenance_id = ? AND new_status = ?
ORDER BY changed_at DESC
LIMIT 1
''', [maintenanceId, status]);
    if (rows.isEmpty) return null;
    return rows.first['changed_at'] as int?;
  }

  String _publicIntakeNotes(RepairIntakeData data) {
    return [
      if (data.deviceCondition.trim().isNotEmpty)
        'حالة الجهاز عند الاستلام: ${data.deviceCondition.trim()}',
      if (data.damage.trim().isNotEmpty)
        'الكسر أو الخدوش: ${data.damage.trim()}',
      'الجهاز يعمل: ${data.deviceWorks ? 'نعم' : 'لا'}',
      'الجهاز يشحن: ${data.deviceCharges ? 'نعم' : 'لا'}',
      'تعرض للماء: ${data.waterDamage ? 'نعم' : 'لا'}',
      if (data.accessories.trim().isNotEmpty)
        'الملحقات المستلمة: ${data.accessories.trim()}',
      if (data.extraNotes.trim().isNotEmpty) data.extraNotes.trim(),
    ].join('\n');
  }

  String _internalIntakeNotes(RepairIntakeData data) {
    final lockCode = data.lockCode.trim();
    return [
      if (data.receiverName.trim().isNotEmpty)
        'مستلم الجهاز: ${data.receiverName.trim()}',
      if (lockCode.isNotEmpty)
        'رمز القفل محفوظ مشفراً: ${DatabaseService.hashPassword(lockCode)}',
    ].join('\n');
  }

  String? _appendNote(String? oldValue, String newNote) {
    final clean = newNote.trim();
    if (clean.isEmpty) return oldValue;
    final old = (oldValue ?? '').trim();
    if (old.isEmpty) return clean;
    return '$old\n$clean';
  }

  String? _emptyToNull(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  int _requireWarrantyDays(int? days) {
    if (!AppConstants.isValidWarrantyDays(days)) {
      throw Exception('حدد مدة الضمان من يوم واحد إلى سنتين.');
    }
    return days!;
  }
}

class RepairBoardData {
  final List<RepairDeviceCard> activeDevices;
  final List<WarrantyModel> warranties;
  final List<RepairCustomerResult> customerResults;
  final Set<String> activeMaintenanceIds;

  const RepairBoardData({
    required this.activeDevices,
    required this.warranties,
    required this.customerResults,
    required this.activeMaintenanceIds,
  });
}

class RepairCustomerResult {
  final CustomerModel customer;
  final int deviceCount;
  final int maintenanceCount;

  const RepairCustomerResult({
    required this.customer,
    required this.deviceCount,
    required this.maintenanceCount,
  });
}

class RepairDeviceCard {
  final MaintenanceModel maintenance;
  final List<String> requiredParts;
  final bool isWarrantyWork;
  final String? latestWarrantyProblem;
  final int deviceRepairCount;
  final int customerDeviceCount;
  final int? readyAt;

  const RepairDeviceCard({
    required this.maintenance,
    required this.requiredParts,
    required this.isWarrantyWork,
    required this.latestWarrantyProblem,
    required this.deviceRepairCount,
    required this.customerDeviceCount,
    required this.readyAt,
  });
}

class RepairIntakeData {
  final String? customerId;
  final String? deviceId;
  final String customerName;
  final String customerPhone;
  final String customerPhone2;
  final String receiverName;
  final String deviceType;
  final String company;
  final String model;
  final String color;
  final String imei;
  final String serial;
  final String lockCode;
  final String accessories;
  final String problem;
  final String deviceCondition;
  final String damage;
  final bool deviceWorks;
  final bool deviceCharges;
  final bool waterDamage;
  final String extraNotes;
  final List<String> imagePaths;

  const RepairIntakeData({
    this.customerId,
    this.deviceId,
    required this.customerName,
    required this.customerPhone,
    required this.customerPhone2,
    required this.receiverName,
    required this.deviceType,
    required this.company,
    required this.model,
    required this.color,
    required this.imei,
    required this.serial,
    required this.lockCode,
    required this.accessories,
    required this.problem,
    required this.deviceCondition,
    required this.damage,
    required this.deviceWorks,
    required this.deviceCharges,
    required this.waterDamage,
    required this.extraNotes,
    required this.imagePaths,
  });

  String get brandOrType {
    final companyValue = company.trim();
    if (companyValue.isNotEmpty) return companyValue;
    final typeValue = deviceType.trim();
    return typeValue.isEmpty ? 'جوال' : typeValue;
  }

  bool get isValid =>
      customerName.trim().isNotEmpty &&
      customerPhone.trim().isNotEmpty &&
      receiverName.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      problem.trim().isNotEmpty;
}
