import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../core/services/pdf_arabic_utils.dart';
import '../../device_photos/data/device_photo_model.dart';
import '../data/device_report_model.dart';

class DeviceReportPdfService {
  const DeviceReportPdfService();

  Future<Uint8List> build({
    required DeviceReportModel report,
    required Map<String, dynamic> maintenance,
    required List<DevicePhotoModel> photos,
  }) async {
    final fonts = await PdfArabicUtils.loadFonts();
    final settings = _decodeSettings(report.centerSettingsSnapshot);
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
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final h1 = pw.TextStyle(
      font: fonts.bold,
      fontSize: 17,
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
        header: (_) => _header(report, settings, logo, h1, small, bold),
        footer: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  _first([
                    settings['invoice_copyright'],
                    settings['shop_name'],
                  ]),
                  style: small,
                  maxLines: 2,
                ),
              ),
              pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: small),
            ],
          ),
        ),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _section(
                  'بيانات العميل والجهاز',
                  h2,
                  [
                    _table(
                      [
                        [
                          'اسم العميل',
                          PdfArabicUtils.text(
                              maintenance['customer_name'], 'العميل')
                        ],
                        [
                          'رقم الجوال',
                          PdfArabicUtils.text(maintenance['customer_phone'])
                        ],
                        [
                          'رقم ملف العميل',
                          PdfArabicUtils.text(maintenance['customer_id'])
                        ],
                        [
                          'الجهاز',
                          '${PdfArabicUtils.text(maintenance['brand'], 'جهاز')} ${PdfArabicUtils.text(maintenance['model'])}'
                              .trim()
                        ],
                        [
                          'IMEI',
                          PdfArabicUtils.text(maintenance['imei'], 'غير مسجل')
                        ],
                        [
                          'الرقم التسلسلي',
                          PdfArabicUtils.text(
                              maintenance['serial_number'], 'غير مسجل')
                        ],
                        [
                          'تاريخ الاستلام',
                          PdfArabicUtils.dateTime(
                              maintenance['received_at'] as int?)
                        ],
                      ],
                      body,
                      bold,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                _section(
                  'حالة الصيانة',
                  h2,
                  [
                    _table(
                      [
                        [
                          'شكوى العميل',
                          PdfArabicUtils.text(
                              maintenance['fault_description'], 'غير محدد')
                        ],
                        [
                          'ملاحظات الاستلام والصيانة',
                          PdfArabicUtils.text(
                            maintenance['notes'],
                            PdfArabicUtils.text(
                                maintenance['internal_notes'], 'لا توجد'),
                          ),
                        ],
                        [
                          'اسم الفني',
                          PdfArabicUtils.text(
                              maintenance['technician_name'], 'غير محدد')
                        ],
                        [
                          'الضمان',
                          _warrantyText(
                            maintenance['warranty_type'] as String?,
                            PdfArabicUtils.integer(
                                maintenance['warranty_days']),
                            PdfArabicUtils.integer(
                                maintenance['warranty_start']),
                            PdfArabicUtils.integer(maintenance['warranty_end']),
                          ),
                        ],
                      ],
                      body,
                      bold,
                    ),
                  ],
                ),
                if ((report.termsSnapshot ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _note(report.termsSnapshot!, body),
                ],
                pw.SizedBox(height: 8),
                _section(
                  'الصور',
                  h2,
                  [_photoGrid(photos, body, small)],
                ),
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
    DeviceReportModel report,
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
          children: [
            pw.Container(
              width: 56,
              height: 56,
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
                  pw.Text(report.title, style: bold),
                  pw.Text(
                    [
                      if (_first([settings['shop_phone']]).isNotEmpty)
                        'جوال: ${settings['shop_phone']}',
                      if (_first([settings['shop_address']]).isNotEmpty)
                        settings['shop_address'],
                    ].join(' | '),
                    style: small,
                  ),
                ],
              ),
            ),
            pw.Column(
              children: [
                pw.Text(report.reportNumber, style: bold),
                pw.Text(PdfArabicUtils.dateTime(report.createdAt),
                    style: small),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: report.reportNumber,
                  width: 44,
                  height: 44,
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

  pw.Widget _table(
    List<List<String>> rows,
    pw.TextStyle body,
    pw.TextStyle bold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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

  pw.Widget _photoGrid(
    List<DevicePhotoModel> photos,
    pw.TextStyle body,
    pw.TextStyle small,
  ) {
    if (photos.isEmpty) {
      return pw.Text('لا توجد صور في هذا التقرير.', style: small);
    }
    final widgets = <pw.Widget>[];
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final image = PdfArabicUtils.loadImage(photo.originalPath);
      if (image == null) continue;
      widgets.add(
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
                height: 138,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 4),
              pw.Text('${i + 1}. ${photo.photoType}', style: body),
              pw.Text(photo.stageLabel, style: small),
              if ((photo.caption ?? '').trim().isNotEmpty)
                pw.Text(photo.caption!, style: small),
              pw.Text(PdfArabicUtils.dateTime(photo.capturedAt), style: small),
            ],
          ),
        ),
      );
    }
    return widgets.isEmpty
        ? pw.Text('تعذر تضمين الصور المحددة.', style: small)
        : pw.Wrap(children: widgets);
  }

  pw.Widget _note(String text, pw.TextStyle style) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(text, style: style),
    );
  }

  pw.Widget _signatureRow(
    Map<String, dynamic> settings,
    pw.MemoryImage? stamp,
    pw.MemoryImage? signature,
    pw.TextStyle small,
    pw.TextStyle bold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signatureBox('توقيع العميل', null, small, bold),
        _signatureBox('ختم المركز', stamp, small, bold),
        _signatureBox(
          _first([settings['manager_name'], 'توقيع المسؤول']),
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

  pw.Widget _cell(String text, pw.TextStyle style, {PdfColor? fill}) {
    return pw.Container(
      color: fill,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style),
    );
  }

  String _warrantyText(String? type, int? days, int? start, int? end) {
    if (type == null || type == AppConstants.warrantyNone || (days ?? 0) <= 0) {
      return 'بدون ضمان';
    }
    return '${days ?? 0} يوم | من ${PdfArabicUtils.date(start)} إلى ${PdfArabicUtils.date(end)}';
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
}
