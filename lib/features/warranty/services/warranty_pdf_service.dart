import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/database/database_service.dart';
import '../../../core/services/settings_service.dart';

class WarrantyPdfResult {
  final String filePath;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String ticketNumber;

  const WarrantyPdfResult({
    required this.filePath,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.ticketNumber,
  });
}

class WarrantyPdfService {
  WarrantyPdfService();

  final DatabaseService _db = DatabaseService();

  Future<WarrantyPdfResult> createForMaintenance(
    String maintenanceId, {
    String? warrantyTerms,
    String documentTitle = 'وثيقة ضمان صيانة',
    String filePrefix = 'Warranty',
    bool intakeAcknowledgement = false,
  }) async {
    final data = await _loadData(maintenanceId);
    if (data == null) {
      throw Exception('طلب الصيانة غير موجود لإنشاء ملف الضمان.');
    }

    final settings = SettingsService();
    await settings.load();
    final parts = await _loadParts(maintenanceId);
    final bytes = await _buildPdf(
      data: data,
      parts: parts,
      settings: settings,
      documentTitle: documentTitle,
      intakeAcknowledgement: intakeAcknowledgement,
      warrantyTerms: _firstNotEmpty([
        warrantyTerms,
        data['warranty_notes']?.toString(),
        settings.warrantyTerms,
      ]),
    );

    final reportsDir = await _db.getShopDirectory('Reports');
    if (!reportsDir.existsSync()) reportsDir.createSync(recursive: true);

    final ticket = _safeFileName(_text(data['ticket_number'], 'warranty'));
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final safePrefix = _safeFileName(filePrefix, fallback: 'Warranty');
    final filePath =
        p.join(reportsDir.path, '${safePrefix}_${ticket}_$stamp.pdf');
    await File(filePath).writeAsBytes(bytes, flush: true);

    return WarrantyPdfResult(
      filePath: filePath,
      customerId: _text(data['customer_id']),
      customerName: _text(data['customer_name'], 'العميل'),
      customerPhone: _text(data['customer_phone']),
      ticketNumber: _text(data['ticket_number']),
    );
  }

  Future<void> revealFile(String filePath) async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('explorer.exe', ['/select,$filePath']);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadData(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*,
       c.id AS customer_id,
       c.name AS customer_name,
       c.phone AS customer_phone,
       c.phone2 AS customer_phone2,
       w.start_date AS warranty_start_date,
       w.end_date AS warranty_end_date,
       w.warranty_days AS warranty_days_value,
       w.notes AS warranty_notes,
       w.expiry_approved AS warranty_expiry_approved,
       w.expiry_approved_at AS warranty_expiry_approved_at,
       w.expiry_approved_by AS warranty_expiry_approved_by
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE m.shop_id = ?
  AND m.id = ?
  AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, maintenanceId]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> _loadParts(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    return _db.rawQuery('''
SELECT p.product_name, p.quantity, p.unit_price, p.total_price
FROM maintenance_parts p
JOIN maintenance m ON m.id = p.maintenance_id
WHERE m.shop_id = ?
  AND p.maintenance_id = ?
ORDER BY p.created_at ASC
''', [shopId, maintenanceId]);
  }

  Future<Uint8List> _buildPdf({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> parts,
    required SettingsService settings,
    required String documentTitle,
    required bool intakeAcknowledgement,
    required String warrantyTerms,
  }) async {
    final fonts = await _loadFonts();
    final logo = _loadLogo(settings.logoPath);

    final body = pw.TextStyle(font: fonts.regular, fontSize: 10);
    final small = pw.TextStyle(
      font: fonts.regular,
      fontSize: 8,
      color: PdfColors.grey700,
    );
    final bold = pw.TextStyle(
      font: fonts.bold,
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final title = pw.TextStyle(
      font: fonts.bold,
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.indigo800,
    );
    final sectionTitle = pw.TextStyle(
      font: fonts.bold,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.indigo700,
    );

    final warrantyStart = _int(data['warranty_start_date']) ??
        _int(data['warranty_start']) ??
        _int(data['delivered_at']);
    final warrantyEnd =
        _int(data['warranty_end_date']) ?? _int(data['warranty_end']);
    final warrantyDays =
        _int(data['warranty_days_value']) ?? _int(data['warranty_days']) ?? 0;
    final warrantyExpiryApproved = _int(data['warranty_expiry_approved']) == 1;
    final warrantyExpiryApprovedAt = _int(data['warranty_expiry_approved_at']);
    final device =
        '${_text(data['brand'], 'جهاز')} ${_text(data['model'])}'.trim();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
        ),
        footer: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(settings.invoiceFooter, style: small),
              pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: small),
            ],
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 58,
                        height: 58,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Container(
                        width: 58,
                        height: 58,
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Text('شعار', style: bold),
                      ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(settings.shopName, style: title),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            [
                              if (settings.shopPhone.isNotEmpty)
                                'هاتف: ${settings.shopPhone}',
                              if (settings.shopPhone2.isNotEmpty)
                                'هاتف إضافي: ${settings.shopPhone2}',
                              if (settings.shopAddress.isNotEmpty)
                                settings.shopAddress,
                            ].join('   |   '),
                            style: small,
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo50,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(documentTitle, style: sectionTitle),
                          pw.SizedBox(height: 3),
                          pw.Text(_text(data['ticket_number']), style: bold),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfColors.indigo700, thickness: 1.2),
                pw.SizedBox(height: 8),
                _section(
                  'بيانات العميل والجهاز',
                  sectionTitle,
                  [
                    _table(
                      [
                        [
                          'اسم العميل',
                          _text(data['customer_name'], 'غير محدد')
                        ],
                        [
                          'رقم الجوال',
                          _text(data['customer_phone'], 'غير محدد')
                        ],
                        ['الجهاز', device],
                        [
                          'IMEI / الرقم التسلسلي',
                          _text(data['imei'], 'غير مسجل')
                        ],
                        [
                          'العطل المسجل',
                          _text(data['fault_description'], 'غير محدد')
                        ],
                      ],
                      body,
                      bold,
                    ),
                    if (warrantyExpiryApproved) ...[
                      pw.SizedBox(height: 6),
                      _expiredWarrantyStamp(
                        body,
                        warrantyEnd: warrantyEnd,
                        approvedAt: warrantyExpiryApprovedAt,
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 8),
                _section(
                  intakeAcknowledgement
                      ? 'إقرار الاستلام والضمان'
                      : 'تفاصيل الصيانة والضمان',
                  sectionTitle,
                  [
                    _table(
                      [
                        ['الصيانة التي تمت', _repairDetails(data)],
                        [
                          'مدة الضمان',
                          intakeAcknowledgement
                              ? 'يحدد الضمان النهائي عند تسليم الجهاز'
                              : warrantyDays > 0
                                  ? '$warrantyDays يوم'
                                  : 'لا يوجد ضمان'
                        ],
                        ['بداية الضمان', _date(warrantyStart)],
                        ['نهاية الضمان', _date(warrantyEnd)],
                        [
                          'التكلفة',
                          _money(_num(data['total_cost']), settings.currency)
                        ],
                        [
                          'المبلغ المدفوع',
                          _money(_num(data['advance_paid']), settings.currency)
                        ],
                      ],
                      body,
                      bold,
                    ),
                  ],
                ),
                if (intakeAcknowledgement) ...[
                  pw.SizedBox(height: 8),
                  _section(
                    'تنبيه للعميل',
                    sectionTitle,
                    [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(9),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue200),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                          color: PdfColors.blue50,
                        ),
                        child: pw.Text(
                          'هذا الملف يثبت استلام الجهاز وحالته عند الاستلام. تبدأ مدة الضمان النهائية بعد إتمام الصيانة وتأكيد التسليم، وتخضع للشروط الموضحة أدناه.',
                          style: body,
                        ),
                      ),
                    ],
                  ),
                ],
                if (parts.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _section(
                    'القطع المستخدمة',
                    sectionTitle,
                    [_partsTable(parts, body, bold, settings.currency)],
                  ),
                ],
                pw.SizedBox(height: 8),
                _section(
                  'شروط الضمان',
                  sectionTitle,
                  [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(9),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.orange200),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                        color: PdfColors.orange50,
                      ),
                      child: pw.Text(
                        warrantyTerms.isEmpty
                            ? 'لم يتم تسجيل شروط ضمان إضافية.'
                            : warrantyTerms,
                        style: body,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signature('توقيع العميل', small),
                    _signature('ختم / توقيع المحل', small),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<_Fonts> _loadFonts() async {
    try {
      final regular = File(r'C:\Windows\Fonts\tahoma.ttf');
      final bold = File(r'C:\Windows\Fonts\tahomabd.ttf');
      if (regular.existsSync() && bold.existsSync()) {
        return _Fonts(
          regular: pw.Font.ttf(regular.readAsBytesSync().buffer.asByteData()),
          bold: pw.Font.ttf(bold.readAsBytesSync().buffer.asByteData()),
        );
      }
    } catch (_) {}

    try {
      return _Fonts(
        regular: await PdfGoogleFonts.notoNaskhArabicRegular(),
        bold: await PdfGoogleFonts.notoNaskhArabicBold(),
      );
    } catch (_) {}

    return const _Fonts(regular: null, bold: null);
  }

  static pw.MemoryImage? _loadLogo(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return null;
    try {
      final file = File(clean);
      if (!file.existsSync()) return null;
      return pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _section(
    String title,
    pw.TextStyle titleStyle,
    List<pw.Widget> children,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(title, style: titleStyle),
          pw.SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _expiredWarrantyStamp(
    pw.TextStyle style, {
    required int? warrantyEnd,
    required int? approvedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: PdfColors.red300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'انتهى الضمان',
            style: style.copyWith(
              color: PdfColors.red800,
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
            ),
          ),
          pw.Text(
            'تاريخ انتهاء الضمان: ${_date(warrantyEnd)} | تاريخ اعتماد الانتهاء: ${_date(approvedAt)}',
            style: style.copyWith(color: PdfColors.red800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _table(
    List<List<String>> rows,
    pw.TextStyle body,
    pw.TextStyle bold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(120),
        1: pw.FlexColumnWidth(),
      },
      children: rows
          .map(
            (row) => pw.TableRow(
              children: [
                _cell(row[0], bold, fill: PdfColors.grey100),
                _cell(row[1], body),
              ],
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _partsTable(
    List<Map<String, dynamic>> parts,
    pw.TextStyle body,
    pw.TextStyle bold,
    String currency,
  ) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cell('القطعة', bold),
          _cell('الكمية', bold),
          _cell('السعر', bold),
          _cell('الإجمالي', bold),
        ],
      ),
      ...parts.map(
        (part) => pw.TableRow(
          children: [
            _cell(_text(part['product_name'], 'قطعة'), body),
            _cell(_num(part['quantity']).toStringAsFixed(0), body),
            _cell(_money(_num(part['unit_price']), currency), body),
            _cell(_money(_num(part['total_price']), currency), body),
          ],
        ),
      ),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      children: rows,
    );
  }

  static pw.Widget _cell(
    String value,
    pw.TextStyle style, {
    PdfColor? fill,
  }) {
    return pw.Container(
      color: fill,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(value, style: style),
    );
  }

  static pw.Widget _signature(String label, pw.TextStyle style) {
    return pw.Container(
      width: 170,
      child: pw.Column(
        children: [
          pw.Container(
            height: 42,
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500)),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(label, style: style),
        ],
      ),
    );
  }

  static String _repairDetails(Map<String, dynamic> data) {
    final notes = _text(data['notes']);
    final internal = _text(data['internal_notes']);
    if (notes.isNotEmpty) return notes;
    if (internal.isNotEmpty) return internal;
    return _text(data['fault_description'], 'صيانة الجهاز');
  }

  static String _date(int? value) {
    if (value == null || value <= 0) return 'غير محدد';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _money(double value, String currency) {
    if (value <= 0) return '0 $currency';
    return '${value.toStringAsFixed(2)} $currency';
  }

  static String _safeFileName(String value, {String fallback = 'warranty'}) {
    final clean = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return clean.isEmpty ? fallback : clean;
  }

  static String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final clean = value?.trim() ?? '';
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  static String _text(Object? value, [String fallback = '']) {
    final clean = value?.toString().trim() ?? '';
    return clean.isEmpty ? fallback : clean;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _Fonts {
  final pw.Font? regular;
  final pw.Font? bold;

  const _Fonts({required this.regular, required this.bold});
}
