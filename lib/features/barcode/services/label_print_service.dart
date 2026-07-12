import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LabelPrintService {
  // ── Font loader ─────────────────────────────────────────────────────────────
  // Tries Windows system fonts first (Tahoma has excellent Arabic support).
  // Falls back to Google Fonts download, then to the built-in PDF font.

  static Future<_Fonts> _loadFonts() async {
    // 1. Windows system fonts (offline, best quality)
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

    // 2. Google Fonts (requires internet on first use)
    try {
      return _Fonts(
        regular: await PdfGoogleFonts.notoNaskhArabicRegular(),
        bold: await PdfGoogleFonts.notoNaskhArabicBold(),
      );
    } catch (_) {}

    // 3. Built-in PDF font (no Arabic shaping — last resort)
    return const _Fonts(regular: null, bold: null);
  }

  // ── Label (100×70 mm) ───────────────────────────────────────────────────────

  static Future<void> printMaintenanceLabel({
    required String ticketNumber,
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    String shopName = 'ProShop - صيانة الجوالات',
  }) async {
    await Printing.layoutPdf(
      name: 'ملصق الجهاز - $ticketNumber',
      onLayout: (format) async => _buildLabelPdf(
        ticketNumber: ticketNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        deviceBrand: deviceBrand,
        deviceModel: deviceModel,
        shopName: shopName,
      ),
    );
  }

  static Future<Uint8List> _buildLabelPdf({
    required String ticketNumber,
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    required String shopName,
  }) async {
    final fonts = await _loadFonts();

    final labelStyle = pw.TextStyle(font: fonts.regular, fontSize: 8);
    final boldStyle = pw.TextStyle(
        font: fonts.bold, fontSize: 9, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: fonts.bold,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800);
    final shopStyle =
        pw.TextStyle(font: fonts.bold, fontSize: 8, color: PdfColors.grey700);

    const labelW = 100.0 * PdfPageFormat.mm;
    const labelH = 70.0 * PdfPageFormat.mm;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(labelW, labelH),
        margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text(shopName, style: shopStyle),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(ticketNumber, style: titleStyle),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.Text('العميل: ', style: boldStyle),
                      pw.Expanded(
                          child: pw.Text(customerName, style: boldStyle)),
                    ]),
                    pw.SizedBox(height: 3),
                    pw.Row(children: [
                      pw.Text('الجوال: ', style: labelStyle),
                      pw.Expanded(
                          child: pw.Text(customerPhone, style: labelStyle)),
                    ]),
                    pw.SizedBox(height: 3),
                    pw.Row(children: [
                      pw.Text('الجهاز: ', style: labelStyle),
                      pw.Expanded(
                          child: pw.Text('$deviceBrand $deviceModel',
                              style: boldStyle)),
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(width: 5 * PdfPageFormat.mm),
              pw.Column(children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: ticketNumber,
                  width: 52 * PdfPageFormat.mm,
                  height: 52 * PdfPageFormat.mm,
                ),
                pw.SizedBox(height: 3),
                pw.Text(ticketNumber,
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ]),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  // ── Receipt (A4) ────────────────────────────────────────────────────────────

  static Future<void> printReceipt({
    required String ticketNumber,
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    required String faultDescription,
    required double laborCost,
    required double partsCost,
    required double totalCost,
    required double advancePaid,
    required double remainingAmount,
    required int receivedAt,
    String? imei,
    String? color,
    String? technicianName,
    String? notes,
    int? estimatedDelivery,
    String shopName = 'ProShop - صيانة الجوالات',
  }) async {
    await Printing.layoutPdf(
      name: 'إيصال استلام - $ticketNumber',
      onLayout: (format) async => _buildReceiptPdf(
        ticketNumber: ticketNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        deviceBrand: deviceBrand,
        deviceModel: deviceModel,
        faultDescription: faultDescription,
        laborCost: laborCost,
        partsCost: partsCost,
        totalCost: totalCost,
        advancePaid: advancePaid,
        remainingAmount: remainingAmount,
        receivedAt: receivedAt,
        imei: imei,
        color: color,
        technicianName: technicianName,
        notes: notes,
        estimatedDelivery: estimatedDelivery,
        shopName: shopName,
      ),
    );
  }

  static Future<Uint8List> _buildReceiptPdf({
    required String ticketNumber,
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    required String faultDescription,
    required double laborCost,
    required double partsCost,
    required double totalCost,
    required double advancePaid,
    required double remainingAmount,
    required int receivedAt,
    String? imei,
    String? color,
    String? technicianName,
    String? notes,
    int? estimatedDelivery,
    required String shopName,
  }) async {
    final fonts = await _loadFonts();

    final body = pw.TextStyle(font: fonts.regular, fontSize: 10);
    final bodyBold = pw.TextStyle(
        font: fonts.bold, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final h1 = pw.TextStyle(
        font: fonts.bold,
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900);
    final h2 = pw.TextStyle(
        font: fonts.bold,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800);
    final small = pw.TextStyle(font: fonts.regular, fontSize: 8);

    String fmtDate(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day}/${d.month}/${d.year}';
    }

    String fmtMoney(double v) => '${v.toStringAsFixed(2)} ر.س';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20 * PdfPageFormat.mm),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName, style: h1),
                      pw.SizedBox(height: 4),
                      pw.Text('إيصال استلام جهاز',
                          style: pw.TextStyle(
                              font: fonts.regular,
                              fontSize: 13,
                              color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: ticketNumber,
                        width: 60,
                        height: 60,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(ticketNumber,
                          style: pw.TextStyle(
                              font: fonts.bold,
                              fontSize: 9,
                              color: PdfColors.blue800),
                          textAlign: pw.TextAlign.center),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.blue800),
              pw.SizedBox(height: 6),

              // Ticket number + date row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(
                      text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'رقم الطلب: ', style: bodyBold),
                    pw.TextSpan(
                        text: ticketNumber,
                        style: pw.TextStyle(
                            font: fonts.bold,
                            fontSize: 12,
                            color: PdfColors.blue900)),
                  ])),
                  pw.RichText(
                      text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'تاريخ الاستلام: ', style: bodyBold),
                    pw.TextSpan(text: fmtDate(receivedAt), style: body),
                  ])),
                ],
              ),

              pw.SizedBox(height: 10),

              // Two-column: customer | device
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('بيانات العميل', style: h2),
                          pw.SizedBox(height: 6),
                          _receiptRow('الاسم', customerName, body, bodyBold),
                          _receiptRow('الجوال', customerPhone, body, bodyBold),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Device
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.blue200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('بيانات الجهاز', style: h2),
                          pw.SizedBox(height: 6),
                          _receiptRow('الجهاز', '$deviceBrand $deviceModel',
                              body, bodyBold),
                          if (imei != null && imei.isNotEmpty)
                            _receiptRow('IMEI', imei, body, bodyBold),
                          if (color != null && color.isNotEmpty)
                            _receiptRow('اللون', color, body, bodyBold),
                          if (technicianName != null &&
                              technicianName.isNotEmpty)
                            _receiptRow(
                                'الفني', technicianName, body, bodyBold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Fault description
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.orange200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('وصف المشكلة', style: h2),
                    pw.SizedBox(height: 4),
                    pw.Text(faultDescription, style: body),
                    if (notes != null && notes.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('ملاحظات: $notes',
                          style: pw.TextStyle(
                              font: fonts.regular,
                              fontSize: 9,
                              color: PdfColors.grey600)),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Cost summary
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('ملخص التكلفة', style: h2),
                    pw.SizedBox(height: 6),
                    _costRow(
                        'أجرة الصيانة', laborCost, body, bodyBold, fmtMoney),
                    _costRow(
                        'تكلفة القطع', partsCost, body, bodyBold, fmtMoney),
                    pw.Divider(color: PdfColors.grey400),
                    _costRow(
                        'الإجمالي', totalCost, bodyBold, bodyBold, fmtMoney),
                    _costRow(
                        'مدفوع مقدماً', advancePaid, body, bodyBold, fmtMoney),
                    _costRow(
                        'المتبقي',
                        remainingAmount,
                        pw.TextStyle(
                            font: fonts.bold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: remainingAmount > 0
                                ? PdfColors.red700
                                : PdfColors.green700),
                        bodyBold,
                        fmtMoney),
                    if (estimatedDelivery != null) ...[
                      pw.SizedBox(height: 6),
                      pw.RichText(
                          text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: 'الموعد المتوقع للتسليم: ', style: bodyBold),
                        pw.TextSpan(
                            text: fmtDate(estimatedDelivery), style: body),
                      ])),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBox('توقيع العميل', small),
                  _signatureBox('توقيع الموظف', small),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'شكراً لثقتكم بنا — ${shopName.split(' - ').first}',
                  style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 9,
                      color: PdfColors.grey500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  // ── Delivery Slip (A4) ──────────────────────────────────────────────────────

  static Future<void> printDeliverySlip({
    required String ticketNumber,
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    required double totalCost,
    required double advancePaid,
    required double remainingAmount,
    required int receivedAt,
    int? deliveredAt,
    String? imei,
    String shopName = 'ProShop - صيانة الجوالات',
  }) async {
    await Printing.layoutPdf(
      name: 'وصل تسليم - $ticketNumber',
      onLayout: (format) async => _buildDeliverySlipPdf(
        ticketNumber: ticketNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        deviceBrand: deviceBrand,
        deviceModel: deviceModel,
        totalCost: totalCost,
        advancePaid: advancePaid,
        remainingAmount: remainingAmount,
        receivedAt: receivedAt,
        deliveredAt: deliveredAt,
        imei: imei,
        shopName: shopName,
      ),
    );
  }

  static Future<Uint8List> _buildDeliverySlipPdf({
    required String ticketNumber,
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    required double totalCost,
    required double advancePaid,
    required double remainingAmount,
    required int receivedAt,
    int? deliveredAt,
    String? imei,
    required String shopName,
  }) async {
    final fonts = await _loadFonts();

    final body = pw.TextStyle(font: fonts.regular, fontSize: 11);
    final bodyBold = pw.TextStyle(
        font: fonts.bold, fontSize: 11, fontWeight: pw.FontWeight.bold);
    final h1 = pw.TextStyle(
        font: fonts.bold,
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green900);
    final h2 = pw.TextStyle(
        font: fonts.bold,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green800);
    final small = pw.TextStyle(font: fonts.regular, fontSize: 8);

    String fmtDate(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day}/${d.month}/${d.year}';
    }

    String fmtMoney(double v) => '${v.toStringAsFixed(2)} ر.س';

    final now = DateTime.now();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20 * PdfPageFormat.mm),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName, style: h1),
                      pw.SizedBox(height: 4),
                      pw.Text('وصل تسليم جهاز',
                          style: pw.TextStyle(
                              font: fonts.regular,
                              fontSize: 14,
                              color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'تاريخ التسليم: ${fmtDate(deliveredAt ?? now.millisecondsSinceEpoch)}',
                          style: body),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: ticketNumber,
                        width: 70,
                        height: 70,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(ticketNumber,
                          style: pw.TextStyle(
                              font: fonts.bold,
                              fontSize: 10,
                              color: PdfColors.green800),
                          textAlign: pw.TextAlign.center),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 2, color: PdfColors.green800),
              pw.SizedBox(height: 10),

              // Main content box
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.green200, width: 1.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('تفاصيل التسليم', style: h2),
                    pw.SizedBox(height: 10),
                    _receiptRow('رقم الطلب', ticketNumber, body, bodyBold),
                    _receiptRow('اسم العميل', customerName, body, bodyBold),
                    _receiptRow('رقم الجوال', customerPhone, body, bodyBold),
                    _receiptRow(
                        'الجهاز', '$deviceBrand $deviceModel', body, bodyBold),
                    if (imei != null && imei.isNotEmpty)
                      _receiptRow('IMEI', imei, body, bodyBold),
                    _receiptRow(
                        'تاريخ الاستلام', fmtDate(receivedAt), body, bodyBold),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.green300),
                    pw.SizedBox(height: 6),
                    _costRow(
                        'إجمالي الصيانة', totalCost, body, bodyBold, fmtMoney),
                    _costRow('المبلغ المدفوع مقدماً', advancePaid, body,
                        bodyBold, fmtMoney),
                    _costRow(
                      'المبلغ المتبقي',
                      remainingAmount,
                      pw.TextStyle(
                          font: fonts.bold,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: remainingAmount > 0
                              ? PdfColors.red700
                              : PdfColors.green700),
                      bodyBold,
                      fmtMoney,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Customer acknowledgement
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'أقر أنا العميل / $customerName باستلام الجهاز $deviceBrand $deviceModel '
                  'في حالة جيدة وبكامل ملحقاته، وأن جميع المبالغ المستحقة قد سُدِّدت بالكامل.',
                  style: body,
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBox('توقيع العميل', small),
                  _signatureBox('توقيع الموظف', small),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'شكراً لثقتكم بنا — ${shopName.split(' - ').first}',
                  style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 9,
                      color: PdfColors.grey500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  static pw.Widget _receiptRow(
      String label, String value, pw.TextStyle body, pw.TextStyle bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: bold),
          ),
          pw.Text(': ', style: bold),
          pw.Expanded(child: pw.Text(value, style: body)),
        ],
      ),
    );
  }

  static pw.Widget _costRow(
    String label,
    double amount,
    pw.TextStyle labelStyle,
    pw.TextStyle bold,
    String Function(double) fmt,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: labelStyle),
          pw.Text(fmt(amount), style: labelStyle),
        ],
      ),
    );
  }

  static pw.Widget _signatureBox(String label, pw.TextStyle style) {
    return pw.Container(
      width: 160,
      child: pw.Column(
        children: [
          pw.Container(
            height: 40,
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(label, style: style),
        ],
      ),
    );
  }
}

class _Fonts {
  final pw.Font? regular;
  final pw.Font? bold;
  const _Fonts({required this.regular, required this.bold});
}
