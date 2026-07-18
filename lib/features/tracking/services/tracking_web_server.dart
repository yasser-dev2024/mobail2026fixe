import 'dart:async';
import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../data/tracking_service.dart';

class TrackingWebServer {
  TrackingWebServer._();
  static final instance = TrackingWebServer._();
  static const port = 8787;
  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      unawaited(_serve(_server!));
    } catch (_) {
      // تعطل صفحة التتبع لا يجب أن يمنع تشغيل التطبيق.
    }
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } catch (_) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.html
          ..write(_page(
              'تعذر فتح التتبع', _message('حدث خطأ مؤقت. أعد فتح الرابط.')));
        await request.response.close();
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final parts = request.uri.pathSegments;
    if (parts.length != 2 || parts.first != 'track') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.html
        ..write(_page('رابط غير صحيح', _message('رابط التتبع غير مكتمل.')));
      await request.response.close();
      return;
    }
    final record =
        await TrackingService().loadByCode(Uri.decodeComponent(parts[1]));
    request.response.headers
      ..contentType = ContentType.html
      ..set('Cache-Control', 'no-store');
    if (record == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write(_page(
            'الطلب غير موجود', _message('لم يتم العثور على طلب بهذا الرقم.')));
    } else {
      request.response.write(_trackingPage(record));
    }
    await request.response.close();
  }

  String _trackingPage(TrackingRecord record) {
    final device = '${record.brand} ${record.model}'.trim();
    final history = record.history.isEmpty
        ? '<p class="muted">لا توجد تحديثات مسجلة بعد.</p>'
        : record.history.reversed
            .map((item) =>
                '<div class="event"><i></i><div><b>${_escape(item.label)}</b><small>${_date(item.changedAt)}</small></div></div>')
            .join();
    return _page('تتبع صيانة جهازك', '''
<section class="hero"><div class="logo">✓</div><div><h1>تتبع صيانة جهازك</h1><p>متابعة واضحة لحالة جهازك</p></div></section>
<section class="status"><small>الحالة الحالية</small><h2>${_escape(AppConstants.maintenanceStatusLabel(record.status))}</h2><p>رقم الطلب: ${_escape(record.ticketNumber)}</p></section>
<section class="card"><h3>بيانات الجهاز</h3>${_row('نوع الجوال', device)}${_row('المشكلة', record.faultDescription)}${_row('تاريخ الاستلام', _date(record.receivedAt))}${_row('آخر تحديث', _date(record.updatedAt))}</section>
<section class="card"><h3>مراحل الصيانة</h3>$history</section><footer>شكراً لثقتكم بنا، نسعد بخدمتكم دائماً.</footer>''');
  }

  String _row(String label, String value) =>
      '<div class="row"><span>${_escape(label)}</span><b>${_escape(value.isEmpty ? 'غير محدد' : value)}</b></div>';
  String _message(String text) =>
      '<section class="card message"><h2>${_escape(text)}</h2></section>';
  String _date(int? ms) {
    if (ms == null) return 'غير محدد';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _escape(Object? value) => (value?.toString() ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  String _page(String title, String body) =>
      '''<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${_escape(title)}</title><style>
*{box-sizing:border-box}body{margin:0;background:#effaf5;color:#132238;font-family:Tahoma,Arial,sans-serif}.wrap{max-width:760px;margin:auto;padding:20px}.hero,.status,.card{border-radius:24px;padding:22px;margin-bottom:16px}.hero{display:flex;align-items:center;gap:14px;background:linear-gradient(135deg,#08a97e,#087257);color:#fff}.hero h1{margin:0 0 8px}.hero p{margin:0}.logo{width:64px;height:64px;border-radius:18px;background:#fff;color:#08a97e;display:grid;place-items:center;font-size:36px}.status{background:linear-gradient(135deg,#10b981,#07936e);color:#fff}.status h2{font-size:31px;margin:8px 0}.card{background:#fff;box-shadow:0 10px 30px #08725718}.card h3{margin:0 0 14px}.row{display:flex;justify-content:space-between;gap:14px;padding:14px 0;border-bottom:1px solid #e8f1ed}.event{display:flex;gap:12px;padding:10px 0}.event i{width:12px;height:12px;margin-top:5px;border-radius:50%;background:#08a97e}.event div{display:flex;flex-direction:column;gap:4px}.event small,.muted,.row span{color:#64748b}.message{text-align:center;margin-top:25vh}footer{text-align:center;color:#087257;font-weight:bold;padding:10px}@media(max-width:520px){.wrap{padding:12px}.row{flex-direction:column;gap:6px}}</style></head><body><main class="wrap">$body</main></body></html>''';
}
