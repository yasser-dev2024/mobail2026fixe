import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/document_share_service.dart';
import '../../../core/services/pdf_arabic_utils.dart';
import '../../../core/services/settings_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../device_photos/data/device_photo_repository.dart';
import '../services/invoice_pdf_service.dart';
import 'invoice_model.dart';

class InvoiceRepository {
  InvoiceRepository();

  final DatabaseService _db = DatabaseService();
  final InvoicePdfService _pdfService = const InvoicePdfService();

  Future<InvoiceModel> createOrRegenerateForMaintenance(
    String maintenanceId,
  ) async {
    final existing = await getByMaintenance(maintenanceId);
    if (existing != null && existing.status != AppConstants.invoiceCancelled) {
      return _regeneratePdf(existing);
    }

    final settings = SettingsService();
    await settings.load();
    final data = await _loadMaintenanceData(maintenanceId);
    if (data == null) {
      throw Exception('طلب الصيانة غير موجود لإنشاء الفاتورة.');
    }

    final customerPhone = PdfArabicUtils.text(data['customer_phone']);
    if (customerPhone.isEmpty) {
      throw Exception('لا يمكن إنشاء الفاتورة دون رقم جوال العميل.');
    }

    final number = await _nextInvoiceNumber(settings);
    final subtotal = PdfArabicUtils.number(data['total_cost']);
    final tax = subtotal * (settings.taxRate / 100);
    final total = subtotal + tax;
    final amountPaid = PdfArabicUtils.number(data['advance_paid']);
    final warrantyTerms = _firstNotEmpty([
      _extractWarrantyTerms(PdfArabicUtils.text(data['notes'])),
      settings.warrantyTerms,
      settings.invoiceGeneralTerms,
    ]);
    final centerSnapshot = _settingsSnapshot(settings);
    final warrantyType = data['warranty_type']?.toString();
    final warrantyEnd = PdfArabicUtils.integer(data['warranty_end']);
    final warrantyExpiryApproved =
        (PdfArabicUtils.integer(data['warranty_expiry_approved']) ?? 0) == 1;

    final invoice = InvoiceModel.create(
      shopId: settings.shopId,
      invoiceNumber: number,
      customerId: data['customer_id'] as String,
      deviceId: data['device_id'] as String?,
      maintenanceId: maintenanceId,
      customerName: PdfArabicUtils.text(data['customer_name'], 'العميل'),
      customerPhone: customerPhone,
      deviceName:
          '${PdfArabicUtils.text(data['brand'], 'جهاز')} ${PdfArabicUtils.text(data['model'])}'
              .trim(),
      imei: data['imei'] as String?,
      serialNumber: data['serial_number'] as String?,
      subtotal: subtotal,
      tax: tax,
      total: total,
      amountPaid: amountPaid,
      paymentMethod: AppConstants.paymentCash,
      warrantyType: warrantyType,
      warrantyDays: PdfArabicUtils.integer(data['warranty_days']) ?? 0,
      warrantyStart: PdfArabicUtils.integer(data['warranty_start']),
      warrantyEnd: warrantyEnd,
      warrantyTermsSnapshot: warrantyTerms,
      centerSettingsSnapshot: jsonEncode(centerSnapshot),
      createdBy: AuthRepository().getCurrentUser()?.username ?? 'النظام',
      notes: data['fault_description'] as String?,
    );

    final approved = invoice.copyWith(
      status: AppConstants.invoiceApproved,
      approvedAt: DateTime.now().millisecondsSinceEpoch,
      warrantyStatus: warrantyExpiryApproved
          ? 'expired_approved'
          : InvoiceModel.calculateWarrantyStatus(
              warrantyType: warrantyType,
              warrantyEnd: warrantyEnd,
            ),
    );

    await _db.insert('invoices', approved.toMap());
    await _log(
      action: 'إنشاء فاتورة صيانة',
      tableName: 'invoices',
      recordId: approved.id,
      newValue: approved.invoiceNumber,
    );

    return _regeneratePdf(approved);
  }

  Future<InvoiceModel> _regeneratePdf(InvoiceModel invoice) async {
    final data = await _loadMaintenanceData(invoice.maintenanceId);
    if (data == null) {
      throw Exception('طلب الصيانة المرتبط بالفاتورة غير موجود.');
    }
    final parts = await _loadParts(invoice.maintenanceId);
    final photos = await _loadPhotos(invoice);
    final bytes = await _pdfService.build(
      invoice: invoice,
      parts: parts,
      photos: photos,
      maintenance: data,
    );

    final dir = await _db.getShopDirectory('Invoices');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fileName = PdfArabicUtils.safeFileName(
      'Invoice_${invoice.invoiceNumber}_${invoice.customerName}_${invoice.deviceName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      fallback: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
    final normalizedFileName =
        fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
    final filePath = PdfArabicUtils.uniquePath(dir.path, normalizedFileName);
    await File(filePath).writeAsBytes(bytes, flush: true);

    final updated = invoice.copyWith(
      pdfPath: filePath,
      fileName: p.basename(filePath),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.update('invoices', updated.toMap(), updated.id);
    await _log(
      action: 'إنشاء ملف PDF للفاتورة',
      tableName: 'invoices',
      recordId: updated.id,
      newValue: filePath,
    );
    return updated;
  }

  Future<List<InvoiceModel>> getAll({
    String? search,
    String? status,
    String? sentStatus,
    String? warrantyStatus,
    DateTime? from,
    DateTime? to,
  }) async {
    await refreshWarrantyStatuses();
    final shopId = await _db.getCurrentShopId();
    final conditions = <String>['shop_id = ?'];
    final args = <dynamic>[shopId];

    if ((search ?? '').trim().isNotEmpty) {
      final s = '%${search!.trim()}%';
      conditions.add('''
(invoice_number LIKE ? OR customer_name LIKE ? OR customer_phone LIKE ?
 OR device_name LIKE ? OR imei LIKE ? OR serial_number LIKE ?)
''');
      args.addAll([s, s, s, s, s, s]);
    }
    if ((status ?? '').trim().isNotEmpty) {
      conditions.add('status = ?');
      args.add(status);
    }
    if ((sentStatus ?? '').trim().isNotEmpty) {
      conditions.add('sent_status = ?');
      args.add(sentStatus);
    }
    if ((warrantyStatus ?? '').trim().isNotEmpty) {
      conditions.add('warranty_status = ?');
      args.add(warrantyStatus);
    }
    if (from != null) {
      conditions.add('created_at >= ?');
      args.add(
          DateTime(from.year, from.month, from.day).millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('created_at <= ?');
      args.add(DateTime(to.year, to.month, to.day, 23, 59, 59)
          .millisecondsSinceEpoch);
    }

    final rows = await _db.query(
      'invoices',
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(InvoiceModel.fromMap).toList();
  }

  Future<InvoiceModel?> getById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'invoices',
      where: 'shop_id = ? AND id = ?',
      whereArgs: [shopId, id],
      limit: 1,
    );
    return rows.isEmpty ? null : InvoiceModel.fromMap(rows.first);
  }

  Future<InvoiceModel?> getByMaintenance(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'invoices',
      where: 'shop_id = ? AND maintenance_id = ? AND status != ?',
      whereArgs: [shopId, maintenanceId, AppConstants.invoiceCancelled],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : InvoiceModel.fromMap(rows.first);
  }

  Future<List<InvoiceModel>> getByCustomer(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'invoices',
      where: 'shop_id = ? AND customer_id = ?',
      whereArgs: [shopId, customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(InvoiceModel.fromMap).toList();
  }

  Future<List<InvoiceModel>> getByDevice(String deviceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'invoices',
      where: 'shop_id = ? AND device_id = ?',
      whereArgs: [shopId, deviceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(InvoiceModel.fromMap).toList();
  }

  Future<void> cancelInvoice(String id, String reason) async {
    final invoice = await getById(id);
    if (invoice == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = invoice.copyWith(
      status: AppConstants.invoiceCancelled,
      cancelledAt: now,
      cancelReason: reason.trim(),
      updatedAt: now,
    );
    await _db.update('invoices', updated.toMap(), updated.id);
    await _log(
      action: 'إلغاء فاتورة',
      tableName: 'invoices',
      recordId: updated.id,
      oldValue: invoice.status,
      newValue: reason,
    );
  }

  Future<bool> sendWhatsApp(String invoiceId) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) throw Exception('الفاتورة غير موجودة.');
    final pdfPath = invoice.pdfPath;
    if (pdfPath == null ||
        pdfPath.trim().isEmpty ||
        !File(pdfPath).existsSync()) {
      throw Exception('ملف PDF غير موجود. أعد إنشاء الفاتورة أولاً.');
    }
    final phone = invoice.customerPhone.trim();
    if (!_isValidPhone(phone)) {
      throw Exception('رقم الجوال غير صالح للإرسال.');
    }

    final settings = SettingsService();
    await settings.load();
    final message = [
      _renderMessage(settings.invoiceMessageTemplate, invoice),
      '',
      'ملف الفاتورة PDF محفوظ باسم: ${invoice.fileName ?? '${invoice.invoiceNumber}.pdf'}',
      'سيتم إرفاق ملف PDF في هذه المحادثة.',
    ].join('\n');
    final ok = await DocumentShareService.sharePdfToWhatsApp(
      filePath: pdfPath,
      phone: phone,
      message: message,
    );
    await markSent(
      invoiceId,
      method: 'whatsapp',
      status: ok ? 'sent' : 'failed',
      errorMessage: ok ? null : 'تعذر فتح واتساب أو مشاركة ملف PDF.',
    );
    return ok;
  }

  Future<void> markSent(
    String invoiceId, {
    required String method,
    required String status,
    String? errorMessage,
  }) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = invoice.copyWith(
      status: status == 'sent' ? AppConstants.invoiceSent : invoice.status,
      sentStatus: status,
      sentAt: status == 'sent' ? now : invoice.sentAt,
      sentMethod: method,
      updatedAt: now,
    );
    await _db.update('invoices', updated.toMap(), updated.id);
    await _db.insert('document_send_logs', {
      'id': const Uuid().v4(),
      'document_id': invoiceId,
      'document_type': 'invoice',
      'customer_id': invoice.customerId,
      'phone': invoice.customerPhone,
      'method': method,
      'file_path': invoice.pdfPath,
      'status': status,
      'error_message': errorMessage,
      'sent_by': AuthRepository().getCurrentUser()?.username ?? 'النظام',
      'sent_at': now,
    });
  }

  Future<void> refreshWarrantyStatuses() async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
SELECT i.id, i.warranty_type, i.warranty_end, i.warranty_status,
       w.expiry_approved AS warranty_expiry_approved
FROM invoices i
LEFT JOIN warranties w ON w.maintenance_id = i.maintenance_id AND w.shop_id = i.shop_id
WHERE i.shop_id = ? AND i.status != ?
''',
      [shopId, AppConstants.invoiceCancelled],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      final approved =
          (PdfArabicUtils.integer(row['warranty_expiry_approved']) ?? 0) == 1;
      final status = approved
          ? 'expired_approved'
          : InvoiceModel.calculateWarrantyStatus(
              warrantyType: row['warranty_type'] as String?,
              warrantyEnd: PdfArabicUtils.integer(row['warranty_end']),
            );
      if (status != row['warranty_status']) {
        await _db.rawUpdate(
          'UPDATE invoices SET warranty_status = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
          [status, now, shopId, row['id']],
        );
      }
    }
  }

  Future<String> _nextInvoiceNumber(SettingsService settings) async {
    final database = await _db.db;
    final now = DateTime.now();
    final year = settings.invoiceResetYearly ? now.year : 0;
    final prefix = settings.invoicePrefix;
    return database.transaction<String>((txn) async {
      final rows = await txn.query(
        'invoice_sequence',
        where: 'shop_id = ? AND year = ? AND prefix = ?',
        whereArgs: [settings.shopId, year, prefix],
        limit: 1,
      );
      final next =
          rows.isEmpty ? 1 : (rows.first['next_number'] as num).toInt();
      final number = '$prefix-${now.year}-${next.toString().padLeft(6, '0')}';
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      await txn.insert(
        'invoice_sequence',
        {
          'shop_id': settings.shopId,
          'year': year,
          'prefix': prefix,
          'next_number': next + 1,
          'updated_at': updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return number;
    });
  }

  Future<Map<String, dynamic>?> _loadMaintenanceData(
      String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
SELECT m.*,
       c.name AS customer_name,
       c.phone AS customer_phone,
       c.email AS customer_email,
       c.address AS customer_address,
       c.created_at AS customer_created_at,
       d.serial_number AS serial_number,
       d.storage AS storage,
       u.name AS technician_name,
       w.expiry_approved AS warranty_expiry_approved,
       w.expiry_approved_at AS warranty_expiry_approved_at,
       w.expiry_approved_by AS warranty_expiry_approved_by
FROM maintenance m
LEFT JOIN customers c ON c.id = m.customer_id AND c.shop_id = m.shop_id
LEFT JOIN devices d ON d.id = m.device_id AND d.shop_id = m.shop_id
LEFT JOIN users u ON u.id = m.technician_id
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE m.shop_id = ?
  AND m.id = ?
  AND m.deleted_at IS NULL
LIMIT 1
''',
      [shopId, maintenanceId],
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> _loadParts(String maintenanceId) {
    return _db.rawQuery(
      '''
SELECT product_name, quantity, unit_price, total_price
FROM maintenance_parts
WHERE maintenance_id = ?
ORDER BY created_at ASC
''',
      [maintenanceId],
    );
  }

  Future<List<Map<String, dynamic>>> _loadPhotos(InvoiceModel invoice) async {
    final settings = SettingsService();
    await settings.load();
    if (!settings.invoiceIncludeIntakePhotos) return const [];
    final photos =
        await DevicePhotoRepository().getForMaintenance(invoice.maintenanceId);
    if (photos.isNotEmpty) {
      return photos
          .where((photo) => photo.stage == AppConstants.photoStageIntake)
          .map((photo) => photo.toMap())
          .toList();
    }

    return _db.query(
      'maintenance_images',
      where: 'maintenance_id = ? AND image_type = ?',
      whereArgs: [invoice.maintenanceId, 'before'],
      orderBy: 'created_at ASC',
    );
  }

  Map<String, dynamic> _settingsSnapshot(SettingsService settings) {
    return {
      'shop_id': settings.shopId,
      'shop_name': settings.shopName,
      'trade_name': settings.tradeName,
      'commercial_register': settings.commercialRegister,
      'tax_number': settings.taxNumber,
      'shop_phone': settings.shopPhone,
      'shop_phone2': settings.shopPhone2,
      'shop_whatsapp': settings.shopWhatsapp,
      'shop_email': settings.shopEmail,
      'shop_address': settings.shopAddress,
      'map_url': settings.mapUrl,
      'currency': settings.currency,
      'tax_rate': settings.taxRate.toString(),
      'logo_path': settings.logoPath,
      'stamp_path': settings.stampPath,
      'signature_path': settings.signaturePath,
      'manager_name': settings.managerName,
      'manager_title': settings.managerTitle,
      'invoice_intro_text': settings.invoiceIntroText,
      'invoice_footer': settings.invoiceFooter,
      'invoice_general_terms': settings.invoiceGeneralTerms,
      'invoice_return_policy': settings.invoiceReturnPolicy,
      'invoice_legal_notes': settings.invoiceLegalNotes,
      'invoice_copyright': settings.invoiceCopyright,
      'invoice_show_signature': settings.invoiceShowSignature.toString(),
    };
  }

  String _renderMessage(String template, InvoiceModel invoice) {
    final fallback = [
      'مرحباً {اسم العميل}،',
      '',
      'تم إصدار فاتورة الصيانة الخاصة بجهازك {نوع الجهاز}.',
      'رقم الفاتورة: {رقم الفاتورة}',
      'مدة الضمان: {مدة الضمان}',
      'تاريخ انتهاء الضمان: {تاريخ انتهاء الضمان}',
      '',
      'نشكركم لثقتكم بـ {اسم المركز}.',
    ].join('\n');
    final settings = SettingsService();
    final base = template.trim().isEmpty ? fallback : template;
    return base
        .replaceAll('{اسم العميل}', invoice.customerName)
        .replaceAll('{نوع الجهاز}', invoice.deviceName)
        .replaceAll('{رقم الفاتورة}', invoice.invoiceNumber)
        .replaceAll(
          '{مدة الضمان}',
          invoice.warrantyDays > 0
              ? '${invoice.warrantyDays} يوم'
              : 'بدون ضمان',
        )
        .replaceAll(
          '{تاريخ انتهاء الضمان}',
          PdfArabicUtils.date(invoice.warrantyEnd),
        )
        .replaceAll('{اسم المركز}', settings.shopName);
  }

  Future<void> _log({
    required String action,
    String? tableName,
    String? recordId,
    String? oldValue,
    String? newValue,
  }) async {
    final user = AuthRepository().getCurrentUser();
    await _db.insert('audit_log', {
      'id': const Uuid().v4(),
      'user_id': user?.id,
      'username': user?.username ?? 'النظام',
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  bool _isValidPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.length >= 9 && clean.length <= 15;
  }

  String _firstNotEmpty(List<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  String _extractWarrantyTerms(String notes) {
    const marker = 'شروط الضمان:';
    final index = notes.indexOf(marker);
    if (index < 0) return '';
    return notes.substring(index + marker.length).trim();
  }
}
