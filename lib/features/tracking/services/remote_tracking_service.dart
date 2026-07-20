import 'dart:convert';
import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/settings_service.dart';

class RemoteTrackingService {
  final DatabaseService _db = DatabaseService();
  final SettingsService _settings = SettingsService();

  Future<String?> syncTicket(String ticketNumber) async {
    final ticket = ticketNumber.trim();
    if (ticket.isEmpty) return null;
    try {
      final shopId = await _db.getCurrentShopId();
      final rows = await _db.rawQuery('''
SELECT m.ticket_number, m.brand, m.model, m.fault_description, m.status,
       m.received_at, m.updated_at
FROM maintenance m
WHERE m.shop_id = ? AND m.ticket_number = ? AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, ticket]);
      if (rows.isEmpty) return null;

      final row = rows.first;
      final payload = jsonEncode({
        'ticket': _text(row['ticket_number']),
        'status': AppConstants.maintenanceStatusLabel(_text(row['status'])),
        'device': '${_text(row['brand'])} ${_text(row['model'])}'.trim(),
        'problem': _text(row['fault_description']),
        'received': _date(row['received_at']),
        'updated': _dateTime(row['updated_at']),
      });
      final key =
          'tracking_remote_${ticket.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
      var endpoint = (await _settings.getSetting(key) ?? '').trim();
      if (endpoint.isNotEmpty && await _write(endpoint, payload)) {
        return endpoint;
      }

      endpoint = await _create(payload) ?? '';
      if (endpoint.isNotEmpty) {
        await _settings.setSetting(key, endpoint);
        return endpoint;
      }
    } catch (_) {
      // لا نفشل حفظ الصيانة إذا كان الإنترنت غير متاح مؤقتًا.
    }
    return null;
  }

  Future<String?> _create(String payload) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request =
          await client.postUrl(Uri.parse('https://jsonblob.com/api/jsonBlob'));
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(payload);
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      if (response.statusCode != HttpStatus.created) return null;
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) return null;
      return location.startsWith('http')
          ? location
          : 'https://jsonblob.com$location';
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _write(String endpoint, String payload) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.putUrl(Uri.parse(endpoint));
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(payload);
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } finally {
      client.close(force: true);
    }
  }

  String _text(Object? value) => value?.toString().trim() ?? '';
  String _date(Object? value) {
    final ms = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String _dateTime(Object? value) {
    final ms = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_date(ms)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
