import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/services/document_share_service.dart';
import '../../../core/services/pdf_arabic_utils.dart';
import '../../../core/services/settings_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../device_photos/data/device_photo_model.dart';
import '../../device_photos/data/device_photo_repository.dart';
import '../services/device_report_pdf_service.dart';
import 'device_report_model.dart';

class DeviceReportRepository {
  DeviceReportRepository();

  final DatabaseService _db = DatabaseService();
  final DeviceReportPdfService _pdfService = const DeviceReportPdfService();

  Future<DeviceReportModel> createForMaintenance(
    String maintenanceId, {
    String reportType = 'comprehensive',
    List<String>? stages,
  }) async {
    final settings = SettingsService();
    await settings.load();
    final data = await _loadMaintenanceData(maintenanceId);
    if (data == null) {
      throw Exception('طلب الصيانة غير موجود لإنشاء التقرير.');
    }

    final allPhotos =
        await DevicePhotoRepository().getForMaintenance(maintenanceId);
    final filteredPhotos = stages == null || stages.isEmpty
        ? allPhotos
        : allPhotos.where((photo) => stages.contains(photo.stage)).toList();
    final number = await _nextReportNumber();
    final title = _titleFor(reportType);
    final snapshot = _settingsSnapshot(settings);
    final report = DeviceReportModel.create(
      shopId: settings.shopId,
      reportNumber: number,
      reportType: reportType,
      customerId: data['customer_id'] as String,
      deviceId: data['device_id'] as String?,
      maintenanceId: maintenanceId,
      title: title,
      includedPhotoIds: filteredPhotos.map((photo) => photo.id).join(','),
      centerSettingsSnapshot: jsonEncode(snapshot),
      termsSnapshot: settings.invoiceLegalNotes,
      createdBy: AuthRepository().getCurrentUser()?.username ?? 'النظام',
      notes: data['fault_description'] as String?,
    );
    await _db.insert('device_reports', report.toMap());
    final saved = await _writePdf(report, data, filteredPhotos);
    await _log(
      action: 'إنشاء تقرير مصور',
      tableName: 'device_reports',
      recordId: saved.id,
      newValue: saved.reportNumber,
    );
    return saved;
  }

  Future<List<DeviceReportModel>> getForMaintenance(
      String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_reports',
      where: 'shop_id = ? AND maintenance_id = ?',
      whereArgs: [shopId, maintenanceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(DeviceReportModel.fromMap).toList();
  }

  Future<List<DeviceReportModel>> getForDevice(String deviceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_reports',
      where: 'shop_id = ? AND device_id = ?',
      whereArgs: [shopId, deviceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(DeviceReportModel.fromMap).toList();
  }

  Future<DeviceReportModel?> getById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_reports',
      where: 'shop_id = ? AND id = ?',
      whereArgs: [shopId, id],
      limit: 1,
    );
    return rows.isEmpty ? null : DeviceReportModel.fromMap(rows.first);
  }

  Future<bool> sendWhatsApp(String reportId) async {
    final report = await getById(reportId);
    if (report == null) throw Exception('التقرير غير موجود.');
    final path = report.pdfPath;
    if (path == null || path.trim().isEmpty || !File(path).existsSync()) {
      throw Exception('ملف PDF للتقرير غير موجود.');
    }
    final data = report.maintenanceId == null
        ? null
        : await _loadMaintenanceData(report.maintenanceId!);
    final phone = PdfArabicUtils.text(data?['customer_phone']);
    if (!_isValidPhone(phone)) {
      throw Exception('رقم الجوال غير صالح للإرسال.');
    }
    final message = [
      'مرحباً ${PdfArabicUtils.text(data?['customer_name'], 'عميلنا')}،',
      '',
      'تم إصدار ${report.title} الخاص بجهازك.',
      'رقم التقرير: ${report.reportNumber}',
      '',
      'ملف التقرير PDF محفوظ باسم: ${report.fileName ?? '${report.reportNumber}.pdf'}',
      'يرجى الاطلاع على ملف PDF المرفق.',
    ].join('\n');
    final ok = await DocumentShareService.sharePdfToWhatsApp(
      filePath: path,
      phone: phone,
      message: message,
    );
    await _markSent(report, ok ? 'sent' : 'failed', 'whatsapp');
    return ok;
  }

  Future<DeviceReportModel> _writePdf(
    DeviceReportModel report,
    Map<String, dynamic> data,
    List<DevicePhotoModel> photos,
  ) async {
    final bytes = await _pdfService.build(
      report: report,
      maintenance: data,
      photos: photos,
    );
    final reportsDir = await _db.getShopDirectory('Reports');
    final dir = Directory(p.join(reportsDir.path, 'DeviceReports'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fileName = PdfArabicUtils.safeFileName(
      'Report_${report.reportNumber}_${PdfArabicUtils.text(data['customer_name'])}_${PdfArabicUtils.text(data['brand'])}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      fallback: 'Report_${report.reportNumber}.pdf',
    );
    final normalizedFileName =
        fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
    final filePath = PdfArabicUtils.uniquePath(dir.path, normalizedFileName);
    await File(filePath).writeAsBytes(bytes, flush: true);
    final updated = report.copyWith(
      pdfPath: filePath,
      fileName: p.basename(filePath),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.update('device_reports', updated.toMap(), updated.id);
    return updated;
  }

  Future<void> _markSent(
    DeviceReportModel report,
    String status,
    String method,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = report.copyWith(
      sentStatus: status,
      sentAt: status == 'sent' ? now : report.sentAt,
      sentMethod: method,
      updatedAt: now,
    );
    await _db.update('device_reports', updated.toMap(), updated.id);
    await _db.insert('document_send_logs', {
      'id': const Uuid().v4(),
      'document_id': report.id,
      'document_type': 'device_report',
      'customer_id': report.customerId,
      'phone': null,
      'method': method,
      'file_path': report.pdfPath,
      'status': status,
      'error_message':
          status == 'sent' ? null : 'تعذر فتح واتساب أو مشاركة ملف PDF.',
      'sent_by': AuthRepository().getCurrentUser()?.username ?? 'النظام',
      'sent_at': now,
    });
  }

  Future<Map<String, dynamic>?> _loadMaintenanceData(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
SELECT m.*,
       c.name AS customer_name,
       c.phone AS customer_phone,
       d.serial_number AS serial_number,
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
      [shopId, id],
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<String> _nextReportNumber() async {
    final shopId = await _db.getCurrentShopId();
    final now = DateTime.now();
    final prefix = 'RPT-${now.year}';
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM device_reports WHERE shop_id = ? AND report_number LIKE ?',
      [shopId, '$prefix-%'],
    );
    final next = (rows.first['cnt'] as num? ?? 0).toInt() + 1;
    return '$prefix-${next.toString().padLeft(6, '0')}';
  }

  String _titleFor(String type) {
    switch (type) {
      case 'intake':
        return 'تقرير استلام الجهاز';
      case 'inspection':
        return 'تقرير فحص الجهاز';
      case 'during_repair':
        return 'تقرير أثناء الصيانة';
      case 'after_repair':
        return 'تقرير بعد الصيانة';
      case 'delivery':
        return 'تقرير تسليم الجهاز';
      default:
        return 'تقرير شامل عن الجهاز';
    }
  }

  Map<String, dynamic> _settingsSnapshot(SettingsService settings) {
    return {
      'shop_id': settings.shopId,
      'shop_name': settings.shopName,
      'trade_name': settings.tradeName,
      'shop_phone': settings.shopPhone,
      'shop_address': settings.shopAddress,
      'commercial_register': settings.commercialRegister,
      'tax_number': settings.taxNumber,
      'logo_path': settings.logoPath,
      'stamp_path': settings.stampPath,
      'signature_path': settings.signaturePath,
      'manager_name': settings.managerName,
      'manager_title': settings.managerTitle,
      'invoice_copyright': settings.invoiceCopyright,
    };
  }

  Future<void> _log({
    required String action,
    String? tableName,
    String? recordId,
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
      'old_value': null,
      'new_value': newValue,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  bool _isValidPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.length >= 9 && clean.length <= 15;
  }
}
