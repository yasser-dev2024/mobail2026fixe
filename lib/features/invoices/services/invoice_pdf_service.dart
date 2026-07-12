import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/pdf_arabic_utils.dart';
import '../data/invoice_model.dart';

class InvoicePdfService {
  const InvoicePdfService();

  Future<Uint8List> build({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> parts,
    required List<Map<String, dynamic>> photos,
    required Map<String, dynamic> maintenance,
  }) async {
    final fonts = await PdfArabicUtils.loadFonts();
    final settings = _decodeSettings(invoice.centerSettingsSnapshot);
    final logo = PdfArabicUtils.loadImage(settings['logo_path']?.toString());
    final stamp = PdfArabicUtils.loadImage(settings['stamp_path']?.toString());
    final signature =
        PdfArabicUtils.loadImage(settings['signature_path']?.toString());

    final body = pw.TextStyle(font: fonts.regular, fontSize: 9.5);
    final small = pw.TextStyle(
      font: fonts.regular,
      fontSize: 8,
      color: PdfColors.grey700,
    );
    final bold = pw.TextStyle(
      font: fonts.bold,
      fontSize: 9.5,
      fontWeight: pw.FontWeight.bold,
    );
    final h1 = pw.TextStyle(
      font: fonts.bold,
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey900,
    );
    final h2 = pw.TextStyle(
      font: fonts.bold,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey800,
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        margin: const pw.EdgeInsets.all(16 * PdfPageFormat.mm),
        header: (_) => _header(invoice, settings, logo, h1, small, bold),
        footer: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  _first([
                    settings['invoice_footer'],
                    settings['invoice_copyright'],
                    settings['shop_name'],
                  ]),
                  style: small,
                  maxLines: 2,
                ),
              ),
              pw.SizedBox(width: 8),
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
                if (_first([settings['invoice_intro_text']]).isNotEmpty)
                  _note(_first([settings['invoice_intro_text']]), body,
                      PdfColors.blue50),
                pw.SizedBox(height: 8),
                _section(
                  'بيانات العميل والجهاز',
                  h2,
                  [
                    _keyValueTable(
                      [
                        ['اسم العميل', invoice.customerName],
                        ['رقم الجوال', invoice.customerPhone],
                        ['رقم ملف العميل', invoice.customerId],
                        ['الجهاز', invoice.deviceName],
                        ['IMEI', invoice.imei ?? 'غير مسجل'],
                        ['الرقم التسلسلي', invoice.serialNumber ?? 'غير مسجل'],
                        [
                          'تاريخ الاستلام',
                          PdfArabicUtils.dateTime(
                              maintenance['received_at'] as int?)
                        ],
                        [
                          'تاريخ التسليم',
                          PdfArabicUtils.dateTime(
                              maintenance['delivered_at'] as int?)
                        ],
                      ],
                      body,
                      bold,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                _section(
                  'بيانات الصيانة',
                  h2,
                  [
                    _keyValueTable(
                      [
                        [
                          'وصف العطل',
                          PdfArabicUtils.text(
                              maintenance['fault_description'], 'غير محدد')
                        ],
                        [
                          'الأعمال المنفذة',
                          PdfArabicUtils.text(
                            maintenance['notes'],
                            PdfArabicUtils.text(
                              maintenance['internal_notes'],
                              'صيانة الجهاز',
                            ),
                          ),
                        ],
                        [
                          'اسم الفني',
                          PdfArabicUtils.text(
                            maintenance['technician_name'],
                            'غير محدد',
                          )
                        ],
                      ],
                      body,
                      bold,
                    ),
                  ],
                ),
                if (parts.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _section('القطع المستخدمة', h2,
                      [_partsTable(parts, body, bold, _currency(settings))]),
                ],
                pw.SizedBox(height: 8),
                _section(
                  'الملخص المالي',
                  h2,
                  [
                    _keyValueTable(
                      [
                        [
                          'الإجمالي قبل الضريبة',
                          PdfArabicUtils.money(
                              invoice.subtotal, _currency(settings))
                        ],
                        [
                          'الخصم',
                          PdfArabicUtils.money(
                              invoice.discount, _currency(settings))
                        ],
                        [
                          'الضريبة',
                          PdfArabicUtils.money(invoice.tax, _currency(settings))
                        ],
                        [
                          'الإجمالي بعد الضريبة',
                          PdfArabicUtils.money(
                              invoice.total, _currency(settings))
                        ],
                        [
                          'المبلغ المدفوع',
                          PdfArabicUtils.money(
                              invoice.amountPaid, _currency(settings))
                        ],
                        [
                          'المبلغ المتبقي',
                          PdfArabicUtils.money(
                              invoice.amountDue, _currency(settings))
                        ],
                        ['طريقة الدفع', invoice.paymentMethod ?? 'غير محددة'],
                      ],
                      body,
                      bold,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                _section(
                  'الضمان',
                  h2,
                  [
                    _keyValueTable(
                      [
                        ['نوع الضمان', _warrantyType(invoice.warrantyType)],
                        [
                          'مدة الضمان',
                          invoice.warrantyDays > 0
                              ? '${invoice.warrantyDays} يوم'
                              : 'بدون ضمان'
                        ],
                        [
                          'بداية الضمان',
                          PdfArabicUtils.date(invoice.warrantyStart)
                        ],
                        [
                          'نهاية الضمان',
                          PdfArabicUtils.date(invoice.warrantyEnd)
                        ],
                        [
                          'حالة الضمان',
                          _warrantyStatus(invoice.warrantyStatus)
                        ],
                      ],
                      body,
                      bold,
                    ),
                    pw.SizedBox(height: 6),
                    _note(
                      invoice.warrantyTermsSnapshot?.trim().isNotEmpty == true
                          ? invoice.warrantyTermsSnapshot!.trim()
                          : 'لا توجد شروط ضمان إضافية.',
                      body,
                      invoice.warrantyDays > 0
                          ? PdfColors.green50
                          : PdfColors.orange50,
                    ),
                  ],
                ),
                if (photos.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _section(
                    'صور الجهاز عند الاستلام',
                    h2,
                    [_photoGrid(photos, body, small)],
                  ),
                ],
                pw.SizedBox(height: 8),
                _terms(settings, body, h2),
                pw.SizedBox(height: 12),
                _signatureRow(settings, stamp, signature, small, bold),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(
    InvoiceModel invoice,
    Map<String, dynamic> settings,
    pw.MemoryImage? logo,
    pw.TextStyle h1,
    pw.TextStyle small,
    pw.TextStyle bold,
  ) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 58,
              height: 58,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: logo == null
                  ? pw.Text('شعار', style: small)
                  : pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_first([settings['shop_name'], 'ProShop']),
                      style: h1),
                  if (_first([settings['trade_name']]).isNotEmpty)
                    pw.Text(_first([settings['trade_name']]), style: bold),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    [
                      if (_first([settings['shop_phone']]).isNotEmpty)
                        'جوال: ${settings['shop_phone']}',
                      if (_first([settings['shop_whatsapp']]).isNotEmpty)
                        'واتساب: ${settings['shop_whatsapp']}',
                      if (_first([settings['shop_email']]).isNotEmpty)
                        settings['shop_email'],
                      if (_first([settings['shop_address']]).isNotEmpty)
                        settings['shop_address'],
                    ].join(' | '),
                    style: small,
                    maxLines: 2,
                  ),
                  pw.Text(
                    [
                      if (_first([settings['commercial_register']]).isNotEmpty)
                        'سجل: ${settings['commercial_register']}',
                      if (_first([settings['tax_number']]).isNotEmpty)
                        'ضريبي: ${settings['tax_number']}',
                    ].join(' | '),
                    style: small,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('فاتورة صيانة', style: bold),
                pw.Text(invoice.invoiceNumber, style: bold),
                pw.Text(PdfArabicUtils.dateTime(invoice.createdAt),
                    style: small),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: invoice.invoiceNumber,
                  width: 46,
                  height: 46,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _section(
    String title,
    pw.TextStyle titleStyle,
    List<pw.Widget> children,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(title, style: titleStyle),
          pw.SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _keyValueTable(
    List<List<String>> rows,
    pw.TextStyle body,
    pw.TextStyle bold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(118),
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

  pw.Widget _partsTable(
    List<Map<String, dynamic>> parts,
    pw.TextStyle body,
    pw.TextStyle bold,
    String currency,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
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
              _cell(PdfArabicUtils.text(part['product_name'], 'قطعة'), body),
              _cell(PdfArabicUtils.number(part['quantity']).toStringAsFixed(0),
                  body),
              _cell(
                  PdfArabicUtils.money(
                      PdfArabicUtils.number(part['unit_price']), currency),
                  body),
              _cell(
                  PdfArabicUtils.money(
                      PdfArabicUtils.number(part['total_price']), currency),
                  body),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _photoGrid(
    List<Map<String, dynamic>> photos,
    pw.TextStyle body,
    pw.TextStyle small,
  ) {
    final items = <pw.Widget>[];
    for (final photo in photos) {
      final path = photo['original_path']?.toString() ??
          photo['image_path']?.toString() ??
          '';
      final image = PdfArabicUtils.loadImage(path);
      if (image == null) continue;
      items.add(
        pw.Container(
          width: 235,
          margin: const pw.EdgeInsets.all(4),
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: 130,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                PdfArabicUtils.text(photo['photo_type'], 'صورة جهاز'),
                style: body,
              ),
              if (PdfArabicUtils.text(photo['caption']).isNotEmpty)
                pw.Text(PdfArabicUtils.text(photo['caption']), style: small),
              pw.Text(
                PdfArabicUtils.dateTime(
                  PdfArabicUtils.integer(
                      photo['captured_at'] ?? photo['created_at']),
                ),
                style: small,
              ),
            ],
          ),
        ),
      );
    }

    return items.isEmpty
        ? pw.Text('لا توجد صور قابلة للتضمين.', style: small)
        : pw.Wrap(children: items);
  }

  pw.Widget _terms(
    Map<String, dynamic> settings,
    pw.TextStyle body,
    pw.TextStyle h2,
  ) {
    final rows = [
      [
        'الشروط العامة',
        _first([settings['invoice_general_terms']])
      ],
      [
        'سياسة الاستبدال أو الاسترجاع',
        _first([settings['invoice_return_policy']])
      ],
      [
        'ملاحظات قانونية',
        _first([settings['invoice_legal_notes']])
      ],
    ].where((row) => row[1].trim().isNotEmpty).toList();

    if (rows.isEmpty) return pw.SizedBox();

    return _section(
      'الشروط والملاحظات',
      h2,
      rows
          .map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text('${row[0]}: ${row[1]}', style: body),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _signatureRow(
    Map<String, dynamic> settings,
    pw.MemoryImage? stamp,
    pw.MemoryImage? signature,
    pw.TextStyle small,
    pw.TextStyle bold,
  ) {
    final showSignature =
        settings['invoice_show_signature']?.toString() != 'false';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _signatureBox('توقيع العميل', null, small, bold),
        if (stamp != null)
          _signatureBox('ختم المركز', stamp, small, bold)
        else
          _signatureBox('ختم المركز', null, small, bold),
        if (showSignature)
          _signatureBox(
            _first([
              settings['manager_name'],
              'توقيع المسؤول',
            ]),
            signature,
            small,
            bold,
            subtitle: _first([settings['manager_title']]),
          ),
      ],
    );
  }

  pw.Widget _signatureBox(
    String label,
    pw.MemoryImage? image,
    pw.TextStyle small,
    pw.TextStyle bold, {
    String? subtitle,
  }) {
    return pw.Container(
      width: 155,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            height: 52,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500)),
            ),
            child: image == null
                ? pw.SizedBox()
                : pw.Image(image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 4),
          pw.Text(label, style: bold, textAlign: pw.TextAlign.center),
          if ((subtitle ?? '').trim().isNotEmpty)
            pw.Text(subtitle!, style: small, textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  pw.Widget _note(String text, pw.TextStyle style, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: color,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(text, style: style),
    );
  }

  pw.Widget _cell(String text, pw.TextStyle style, {PdfColor? fill}) {
    return pw.Container(
      color: fill,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style),
    );
  }

  Map<String, dynamic> _decodeSettings(String? snapshot) {
    if (snapshot == null || snapshot.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(snapshot);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  String _first(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _currency(Map<String, dynamic> settings) {
    final currency = settings['currency']?.toString().trim() ?? '';
    return currency.isEmpty ? 'ر.س' : currency;
  }

  String _warrantyType(String? type) {
    switch (type) {
      case '7_days':
        return 'ضمان 7 أيام';
      case '30_days':
        return 'ضمان 30 يوم';
      case '90_days':
        return 'ضمان 90 يوم';
      case '6_months':
        return 'ضمان 6 أشهر';
      case '1_year':
        return 'ضمان سنة';
      case '2_years':
        return 'ضمان سنتين';
      case 'custom':
        return 'ضمان مخصص';
      case 'none':
      case null:
        return 'بدون ضمان';
      default:
        return type;
    }
  }

  String _warrantyStatus(String status) {
    switch (status) {
      case 'active':
        return 'ساري';
      case 'expired':
        return 'منتهي';
      case 'pending':
        return 'بانتظار بدء الضمان';
      case 'cancelled':
        return 'ملغى';
      default:
        return 'بدون ضمان';
    }
  }
}
