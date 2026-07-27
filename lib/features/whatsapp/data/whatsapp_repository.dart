import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/document_share_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../auth/data/auth_repository.dart';
import '../../tracking/data/tracking_service.dart';
import '../../warranty/services/warranty_pdf_service.dart';
import 'whatsapp_message_model.dart';
import 'whatsapp_template_model.dart';

class _WhatsappPdfAttachment {
  final String documentTitle;
  final String filePrefix;
  final String note;

  const _WhatsappPdfAttachment({
    required this.documentTitle,
    required this.filePrefix,
    required this.note,
  });
}

class WhatsappRepository {
  static final WhatsappRepository _instance = WhatsappRepository._internal();
  factory WhatsappRepository() => _instance;
  WhatsappRepository._internal();

  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  static const String statusPrepared = 'prepared';
  static const String statusSent = 'sent';
  static const String statusFailed = 'failed';

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  /// Templates for the manual composer screen only (System B, `waTpl*`
  /// keys) — excludes the automatic maintenance-workflow templates
  /// (`wamsg_*` keys, System A) so the two systems' template lists stay
  /// visually separate even though both live in the same table.
  Future<List<WhatsappTemplateModel>> getTemplates() async {
    final rows = await _db.query(
      'whatsapp_templates',
      where: "is_active = ? AND key NOT LIKE '$_wamsgKeyPrefix%'",
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return rows.map(WhatsappTemplateModel.fromMap).toList();
  }

  static const _wamsgKeyPrefix = 'wamsg_';

  /// The 10 automatic maintenance-workflow message templates (System A),
  /// for the WhatsApp message settings page — includes inactive ones too,
  /// since that page is exactly where an owner re-enables them.
  Future<List<WhatsappTemplateModel>> getAutomaticMessageTemplates() async {
    final rows = await _db.query(
      'whatsapp_templates',
      where: "key LIKE '$_wamsgKeyPrefix%'",
      orderBy: 'name ASC',
    );
    return rows.map(WhatsappTemplateModel.fromMap).toList();
  }

  Future<WhatsappTemplateModel?> getTemplate(String key) async {
    final rows = await _db.query(
      'whatsapp_templates',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WhatsappTemplateModel.fromMap(rows.first);
  }

  Future<void> updateTemplate(WhatsappTemplateModel template) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'whatsapp_templates',
      {
        'name': template.name,
        'template': template.template,
        'is_active': template.isActive ? 1 : 0,
        'updated_at': now,
      },
      template.id,
    );
  }

  // ---------------------------------------------------------------------------
  // Maintenance workflow messages
  // ---------------------------------------------------------------------------

  Future<WhatsappMessageModel?> ensureCurrentMaintenanceMessage(
    String maintenanceId,
  ) async {
    final data = await _loadMaintenanceMessageData(maintenanceId);
    if (data == null) return null;
    final latest = await getLatestMessageForMaintenance(maintenanceId);
    if (latest != null &&
        (latest.status == statusPrepared || latest.status == statusFailed) &&
        _isMessageTypeCurrentForStatus(latest.messageType, data)) {
      if (await _messageNeedsRefresh(latest, data)) {
        return prepareMaintenanceMessage(
          maintenanceId,
          latest.messageType,
          forceNew: true,
        );
      }
      return latest;
    }
    final type = await _messageTypeForStatus(data);
    if (type == null) return null;
    return prepareMaintenanceMessage(maintenanceId, type);
  }

  Future<WhatsappMessageModel> prepareMaintenanceMessage(
    String maintenanceId,
    String messageType, {
    bool forceNew = false,
  }) async {
    final data = await _loadMaintenanceMessageData(maintenanceId);
    if (data == null) {
      throw Exception('طلب الصيانة غير موجود');
    }

    if (!forceNew) {
      final existing = await _latestMessage(
        maintenanceId: maintenanceId,
        messageType: messageType,
      );
      if (existing != null &&
          (existing.status == statusPrepared ||
              existing.status == statusSent)) {
        final needsRefresh = await _messageNeedsRefresh(existing, data);
        if (!needsRefresh) return existing;
      }
    }

    final phone = _text(data['customer_phone']);
    final normalizedPhone = normalizePhone(phone);
    final now = DateTime.now().millisecondsSinceEpoch;
    final message = await _buildMessage(data, messageType);
    final model = WhatsappMessageModel(
      id: _uuid.v4(),
      maintenanceId: maintenanceId,
      customerId: _text(data['customer_id']),
      customerName: _text(data['customer_name']),
      phone: phone,
      normalizedPhone: normalizedPhone,
      messageType: messageType,
      message: message,
      status: statusPrepared,
      provider: 'desktop',
      preparedAt: now,
      updatedAt: now,
      retryCount: 0,
    );
    await _db.insert('whatsapp_messages', model.toMap());
    return model;
  }

  Future<bool> _messageNeedsRefresh(
    WhatsappMessageModel message,
    Map<String, dynamic> data,
  ) async {
    if (message.messageType != AppConstants.waMsgReceived) return false;
    final trackingUrl =
        await TrackingService().buildTrackingUrl(_text(data['ticket_number']));
    return trackingUrl.isNotEmpty && !message.message.contains(trackingUrl);
  }

  Future<String> ensureRequiredTrackingLink(
    WhatsappMessageModel message,
    String text,
  ) async {
    final cleanText = _stripUnsupportedTrackingLinks(text.trim());
    if (message.messageType != AppConstants.waMsgReceived) {
      return cleanText;
    }

    final data = await _loadMaintenanceMessageData(message.maintenanceId);
    if (data == null) return cleanText;

    final ticket = _text(data['ticket_number']);
    final trackingUrl = await TrackingService().buildTrackingUrl(ticket);
    if (trackingUrl.isEmpty || cleanText.contains(trackingUrl)) {
      return cleanText;
    }

    return [
      'رابط تتبع الجهاز:',
      trackingUrl,
      '',
      cleanText,
    ].join('\n');
  }

  static String buildReceivedCustomerMessage({
    required String customerName,
    required String trackingUrl,
    required String receivedDate,
    required String device,
    required String problem,
  }) {
    final name =
        customerName.trim().isEmpty ? 'عميلنا العزيز' : customerName.trim();
    final cleanDevice = device.trim().isEmpty ? 'غير محدد' : device.trim();
    final cleanProblem = problem.trim().isEmpty ? 'غير محددة' : problem.trim();
    return [
      'مرحباً $name،',
      '',
      if (trackingUrl.trim().isNotEmpty) ...[
        'رابط تتبع الجهاز:',
        trackingUrl.trim(),
        '',
      ],
      'تاريخ الاستلام: $receivedDate',
      '',
      'نوع الجوال: $cleanDevice',
      '',
      'المشكلة: $cleanProblem',
      '',
      'شكراً لثقتكم بنا، سنعتني بجهازكم ونبقيكم على اطلاع حتى اكتمال الصيانة بإذن الله.',
    ].join('\n');
  }

  String _stripUnsupportedTrackingLinks(String text) {
    final lines = text.split('\n');
    final cleaned = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final next = i + 1 < lines.length ? lines[i + 1] : '';
      if (isUnsupportedTrackingLink(line)) {
        if (cleaned.isNotEmpty && cleaned.last.contains('رابط تتبع')) {
          cleaned.removeLast();
        }
        continue;
      }
      if (line.contains('رابط تتبع') && isUnsupportedTrackingLink(next)) {
        continue;
      }
      cleaned.add(line);
    }
    return cleaned.join('\n').trim();
  }

  static bool isUnsupportedTrackingLink(String value) {
    final lower = value.toLowerCase();
    final legacyHost = ['war', 'shati', 'app.com'].join();
    return lower.contains(legacyHost) ||
        lower.contains('proshop.example.com') ||
        lower.contains('proshop.local') ||
        lower.startsWith('proshop://');
  }

  /// Whether the automatic pipeline (this method, [prepareDueMessages]) is
  /// allowed to prepare/send [messageType] right now — the master switch
  /// plus this type's own toggle from the WhatsApp message settings page.
  /// Deliberately **not** checked inside [prepareMaintenanceMessage] or
  /// [_buildMessage] themselves, since those are shared with the manual
  /// "send now" bypass buttons in the repair board, which must keep working
  /// regardless of this automatic-pipeline setting.
  Future<bool> _isMessageTypeEnabledForAutoPipeline(String messageType) async {
    final settings = SettingsService();
    await settings.load();
    if (!settings.whatsappMessageTypesMasterEnabled) return false;
    final template = await getTemplate(_templateKeyForMessageType(messageType));
    return template?.isActive ?? true;
  }

  Future<void> prepareAndMaybeAutoSend(
    String maintenanceId,
    String messageType,
  ) async {
    if (!await _isMessageTypeEnabledForAutoPipeline(messageType)) return;

    final prepared =
        await prepareMaintenanceMessage(maintenanceId, messageType);
    final settings = SettingsService();
    await settings.load();
    if (!settings.autoWhatsappSend) return;

    final user = AuthRepository().getCurrentUser();
    await sendPreparedMessage(
      prepared.id,
      message: prepared.message,
      sentBy: user?.username ?? user?.name,
    );
  }

  Future<void> prepareDueMessages() async {
    final shopId = await _db.getCurrentShopId();
    final readyRows = await _db.rawQuery('''
SELECT m.id
FROM maintenance m
WHERE m.shop_id = ?
  AND m.status = ?
  AND m.deleted_at IS NULL
''', [shopId, AppConstants.statusReady]);
    for (final row in readyRows) {
      final maintenanceId = row['id'] as String;
      final data = await _loadMaintenanceMessageData(maintenanceId);
      final type = data == null ? null : await _messageTypeForStatus(data);
      if (type == null) continue;
      if (!await _isMessageTypeEnabledForAutoPipeline(type)) continue;
      await ensureCurrentMaintenanceMessage(maintenanceId);
    }

    if (!await _isMessageTypeEnabledForAutoPipeline(
        AppConstants.waMsgWarrantyExpiring)) {
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysLater = today.add(const Duration(days: 7));
    final warrantyRows = await _db.rawQuery('''
SELECT m.id
FROM maintenance m
JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE w.is_void = 0
  AND m.shop_id = ?
  AND w.end_date >= ?
  AND w.end_date < ?
  AND m.deleted_at IS NULL
''', [
      shopId,
      today.millisecondsSinceEpoch,
      sevenDaysLater.add(const Duration(days: 1)).millisecondsSinceEpoch,
    ]);
    for (final row in warrantyRows) {
      await prepareMaintenanceMessage(
        row['id'] as String,
        AppConstants.waMsgWarrantyExpiring,
      );
    }
  }

  Future<List<WhatsappMessageModel>> getMessagesForMaintenance(
    String maintenanceId,
  ) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT wm.*
      FROM whatsapp_messages wm
      JOIN maintenance m ON m.id = wm.maintenance_id
      WHERE m.shop_id = ?
        AND wm.maintenance_id = ?
      ORDER BY wm.prepared_at DESC
      ''',
      [shopId, maintenanceId],
    );
    return rows.map(WhatsappMessageModel.fromMap).toList();
  }

  Future<WhatsappMessageModel?> getMessageById(String id) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT wm.*
      FROM whatsapp_messages wm
      JOIN maintenance m ON m.id = wm.maintenance_id
      WHERE m.shop_id = ?
        AND wm.id = ?
      LIMIT 1
      ''',
      [shopId, id],
    );
    return rows.isEmpty ? null : WhatsappMessageModel.fromMap(rows.first);
  }

  Future<WhatsappMessageModel?> getLatestMessageForMaintenance(
    String maintenanceId,
  ) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT wm.*
      FROM whatsapp_messages wm
      JOIN maintenance m ON m.id = wm.maintenance_id
      WHERE m.shop_id = ?
        AND wm.maintenance_id = ?
      ORDER BY wm.prepared_at DESC
      LIMIT 1
      ''',
      [shopId, maintenanceId],
    );
    return rows.isEmpty ? null : WhatsappMessageModel.fromMap(rows.first);
  }

  Future<void> sendPreparedMessage(
    String messageId, {
    required String message,
    String? sentBy,
  }) async {
    final model = await getMessageById(messageId);
    if (model == null) {
      throw Exception('رسالة WhatsApp غير موجودة');
    }

    final cleanMessage = await ensureRequiredTrackingLink(
      model,
      message,
    );
    if (cleanMessage.isEmpty) {
      throw Exception('نص الرسالة فارغ');
    }

    final normalizedPhone = normalizePhone(model.phone);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (normalizedPhone == null) {
      await _markMessageFailed(
        model,
        'رقم العميل غير صالح',
        editedMessage: cleanMessage,
      );
      throw Exception('رقم العميل غير صالح ولا يمكن فتح WhatsApp');
    }

    final pdfAttachment = _pdfAttachmentFor(model.messageType);
    final launchOk = pdfAttachment == null
        ? await WhatsAppLauncher.send(
            phone: normalizedPhone,
            message: cleanMessage,
          )
        : await _sharePreparedPdfMessage(
            model: model,
            phone: normalizedPhone,
            message: cleanMessage,
            attachment: pdfAttachment,
          );
    if (!launchOk) {
      await _markMessageFailed(
        model,
        pdfAttachment == null
            ? 'تعذر فتح WhatsApp Desktop أو WhatsApp Web'
            : 'تعذر فتح WhatsApp أو مشاركة ملف PDF',
        editedMessage: cleanMessage,
      );
      throw Exception(
        pdfAttachment == null
            ? 'تعذر فتح WhatsApp Desktop أو WhatsApp Web'
            : 'تعذر فتح WhatsApp أو مشاركة ملف PDF',
      );
    }

    await _db.update(
      'whatsapp_messages',
      {
        'phone': model.phone,
        'normalized_phone': normalizedPhone,
        'message': cleanMessage,
        'status': statusSent,
        'provider': pdfAttachment == null ? 'desktop' : 'whatsapp_pdf',
        'sent_at': now,
        'sent_by': sentBy,
        'failure_reason': null,
        'retry_count': model.status == statusSent
            ? model.retryCount + 1
            : model.retryCount,
        'edited_at': cleanMessage != model.message ? now : model.editedAt,
        'updated_at': now,
      },
      messageId,
    );

    await _db.insert('whatsapp_logs', {
      'id': _uuid.v4(),
      'customer_id': model.customerId,
      'phone': normalizedPhone,
      'message': cleanMessage,
      'template_key': model.messageType,
      'reference_id': model.maintenanceId,
      'sent_at': now,
    });
  }

  Future<bool> _sharePreparedPdfMessage({
    required WhatsappMessageModel model,
    required String phone,
    required String message,
    required _WhatsappPdfAttachment attachment,
  }) async {
    final pdf = await WarrantyPdfService().createForMaintenance(
      model.maintenanceId,
      documentTitle: attachment.documentTitle,
      filePrefix: attachment.filePrefix,
    );
    final messageWithNote = [
      message,
      '',
      attachment.note,
    ].join('\n');
    return DocumentShareService.sharePdfToWhatsApp(
      filePath: pdf.filePath,
      phone: phone,
      message: messageWithNote,
    );
  }

  _WhatsappPdfAttachment? _pdfAttachmentFor(String messageType) {
    switch (messageType) {
      case AppConstants.waMsgReceived:
        return null;
      case AppConstants.waMsgDelivered:
        return const _WhatsappPdfAttachment(
          documentTitle: 'وثيقة ضمان الصيانة',
          filePrefix: 'Warranty',
          note: 'مرفق ملف PDF لوثيقة الضمان.',
        );
      default:
        return null;
    }
  }

  Future<void> _markMessageFailed(
    WhatsappMessageModel model,
    String reason, {
    String? editedMessage,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'whatsapp_messages',
      {
        'message': editedMessage ?? model.message,
        'status': statusFailed,
        'failure_reason': reason,
        'retry_count': model.retryCount + 1,
        'edited_at': editedMessage != null && editedMessage != model.message
            ? now
            : model.editedAt,
        'updated_at': now,
      },
      model.id,
    );
  }

  Future<WhatsappMessageModel?> _latestMessage({
    required String maintenanceId,
    required String messageType,
  }) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT wm.*
      FROM whatsapp_messages wm
      JOIN maintenance m ON m.id = wm.maintenance_id
      WHERE m.shop_id = ?
        AND wm.maintenance_id = ?
        AND wm.message_type = ?
      ORDER BY wm.prepared_at DESC
      LIMIT 1
      ''',
      [shopId, maintenanceId, messageType],
    );
    return rows.isEmpty ? null : WhatsappMessageModel.fromMap(rows.first);
  }

  Future<Map<String, dynamic>?> _loadMaintenanceMessageData(
    String maintenanceId,
  ) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT m.*,
       c.id AS customer_id,
       c.name AS customer_name,
       c.phone AS customer_phone,
       w.start_date AS warranty_start_date,
       w.end_date AS warranty_end_date,
       w.warranty_days AS warranty_days_value,
       t.name AS technician_name
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id AND w.is_void = 0
LEFT JOIN users t ON t.id = m.technician_id
WHERE m.shop_id = ?
  AND m.id = ?
  AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, maintenanceId]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<String?> _messageTypeForStatus(Map<String, dynamic> data) async {
    final status = _text(data['status']);
    switch (status) {
      case AppConstants.statusNew:
      case AppConstants.statusWaitingInspection:
        return AppConstants.waMsgReceived;
      case AppConstants.statusRepaired:
      case AppConstants.statusReady:
        return _readyMessageType(data);
      case AppConstants.statusWaitingPart:
        return AppConstants.waMsgNeedsPart;
      case AppConstants.statusUnrepairable:
        return AppConstants.waMsgUnrepairable;
      case AppConstants.statusDelivered:
        return AppConstants.waMsgDelivered;
      case AppConstants.statusWarrantyReturn:
        return AppConstants.waMsgWarrantyClaim;
      default:
        return null;
    }
  }

  bool _isMessageTypeCurrentForStatus(
    String messageType,
    Map<String, dynamic> data,
  ) {
    final status = _text(data['status']);
    switch (status) {
      case AppConstants.statusNew:
      case AppConstants.statusWaitingInspection:
        return messageType == AppConstants.waMsgReceived;
      case AppConstants.statusRepaired:
      case AppConstants.statusReady:
        return messageType == AppConstants.waMsgReady ||
            messageType == AppConstants.waMsgReadyReminder1 ||
            messageType == AppConstants.waMsgReadyReminder3 ||
            messageType == AppConstants.waMsgReadyReminder7;
      case AppConstants.statusWaitingPart:
        return messageType == AppConstants.waMsgNeedsPart;
      case AppConstants.statusUnrepairable:
        return messageType == AppConstants.waMsgUnrepairable;
      case AppConstants.statusDelivered:
        return messageType == AppConstants.waMsgDelivered ||
            messageType == AppConstants.waMsgWarrantyExpiring;
      case AppConstants.statusWarrantyReturn:
        return messageType == AppConstants.waMsgWarrantyClaim;
      default:
        return false;
    }
  }

  Future<String> _readyMessageType(Map<String, dynamic> data) async {
    final readyAt = await _readyChangedAt(_text(data['id'])) ??
        _int(data['updated_at']) ??
        DateTime.now().millisecondsSinceEpoch;
    final readyDate = DateTime.fromMillisecondsSinceEpoch(readyAt);
    final ageDays = DateTime.now().difference(readyDate).inDays;
    if (ageDays >= 7) return AppConstants.waMsgReadyReminder7;
    if (ageDays >= 3) return AppConstants.waMsgReadyReminder3;
    if (ageDays >= 1) return AppConstants.waMsgReadyReminder1;
    return AppConstants.waMsgReady;
  }

  Future<int?> _readyChangedAt(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT h.changed_at
FROM maintenance_status_history h
JOIN maintenance m ON m.id = h.maintenance_id
WHERE m.shop_id = ?
  AND h.maintenance_id = ?
  AND h.new_status = ?
ORDER BY h.changed_at DESC
LIMIT 1
''', [shopId, maintenanceId, AppConstants.statusReady]);
    if (rows.isEmpty) return null;
    return _int(rows.first['changed_at']);
  }

  /// Maps a `waMsg*` message type to its `wamsg_*` template key. Distinct
  /// from the raw `waMsg*`/`waTpl*` constant strings themselves, some of
  /// which collide (e.g. both `waMsgReady` and the manual-composer's
  /// `waTplReady` are `'ready'`).
  static String _templateKeyForMessageType(String messageType) =>
      '$_wamsgKeyPrefix$messageType';

  Future<String> _buildMessage(
    Map<String, dynamic> data,
    String messageType,
  ) async {
    final name = _fallback(_text(data['customer_name']), 'العميل');
    final brand = _text(data['brand']);
    final model = _text(data['model']);
    final device = _fallback('$brand $model'.trim(), 'الجهاز');
    final ticket = _text(data['ticket_number']);
    final trackingUrl = await TrackingService().buildTrackingUrl(ticket);
    final repairDetails = _repairDetails(data);
    final cost = _money(_num(data['total_cost']));
    final warrantyDays = _warrantyDays(data);
    final warrantyStart = _int(data['warranty_start_date']) ??
        _int(data['warranty_start']) ??
        _int(data['delivered_at']);
    final warrantyEnd =
        _int(data['warranty_end_date']) ?? _int(data['warranty_end']);
    final readyAt = await _readyChangedAt(_text(data['id'])) ??
        _int(data['updated_at']) ??
        DateTime.now().millisecondsSinceEpoch;
    final requiredPart = await _requiredPart(_text(data['id']));

    // A shop owner can customize any of the 10 automatic message types from
    // the WhatsApp message settings page. Templates are seeded with empty
    // text and `is_active: 1`, so this only changes behavior once an owner
    // explicitly writes and saves their own wording — otherwise it falls
    // straight through to the exact hardcoded switch below, unchanged.
    final customTemplate =
        await getTemplate(_templateKeyForMessageType(messageType));
    if (customTemplate != null &&
        customTemplate.isActive &&
        customTemplate.template.trim().isNotEmpty) {
      final unrepairableReason = messageType == AppConstants.waMsgUnrepairable
          ? await _unrepairableReason(_text(data['id']), data)
          : '';
      final variables = <String, String>{
        'اسم العميل': name,
        'نوع الجهاز': device,
        'رقم الجهاز': _fallback(_text(data['imei']), 'غير محدد'),
        'رقم أمر الصيانة': ticket,
        'اسم الفني': _fallback(_text(data['technician_name']), 'غير محدد'),
        'تاريخ الاستلام': _date(_int(data['received_at'])),
        'تاريخ التسليم': _date(_int(data['delivered_at'])),
        'مدة الضمان': warrantyDays,
        'رابط التتبع': trackingUrl,
        'الصيانة التي تمت': repairDetails,
        'التكلفة': cost,
        'القطعة المطلوبة': _fallback(requiredPart, 'غير محددة'),
        'سبب تعذر الإصلاح': unrepairableReason,
        'بداية الضمان': _date(warrantyStart),
        'تاريخ انتهاء الضمان': _date(warrantyEnd),
        'تاريخ جاهزية الجهاز': _date(readyAt),
        'المشكلة المسجلة':
            _fallback(_text(data['fault_description']), 'غير محددة'),
      };
      return customTemplate.buildMessage(variables);
    }

    switch (messageType) {
      case AppConstants.waMsgReceived:
        return buildReceivedCustomerMessage(
          customerName: name,
          trackingUrl: trackingUrl,
          receivedDate: _date(_int(data['received_at'])),
          device: device,
          problem: _text(data['fault_description']),
        );
      case AppConstants.waMsgReady:
        return [
          'مرحباً $name،',
          '',
          'تم الانتهاء من صيانة جهازكم وأصبح جاهزاً للاستلام.',
          '',
          'الجهاز: $device',
          '',
          'الصيانة التي تمت: $repairDetails',
          '',
          'التكلفة: $cost',
          '',
          'مدة الضمان: $warrantyDays',
          '',
          'تاريخ انتهاء الضمان: ${_date(warrantyEnd)}',
          '',
          'رقم الطلب: $ticket',
        ].join('\n');
      case AppConstants.waMsgNeedsPart:
        return [
          'مرحباً $name،',
          '',
          'تم فحص جهازكم، ويحتاج حالياً إلى قطعة غيار لإكمال الصيانة.',
          '',
          'الجهاز: $device',
          '',
          'القطعة المطلوبة: ${_fallback(requiredPart, 'غير محددة')}',
          '',
          'رقم الطلب: $ticket',
          '',
          'سيتم التواصل معكم عند اكتمال الصيانة.',
        ].join('\n');
      case AppConstants.waMsgUnrepairable:
        return [
          'مرحباً $name،',
          '',
          'تم فحص جهازكم.',
          '',
          'الجهاز: $device',
          '',
          'تعذر إتمام الإصلاح بسبب:',
          '',
          await _unrepairableReason(_text(data['id']), data),
          '',
          'يمكنكم مراجعة المحل لاستلام الجهاز.',
          '',
          'رقم الطلب: $ticket',
        ].join('\n');
      case AppConstants.waMsgDelivered:
        return [
          'مرحباً $name،',
          '',
          'تم تسليم جهازكم بنجاح.',
          '',
          'الجهاز: $device',
          '',
          'الصيانة التي تمت: $repairDetails',
          '',
          'مدة الضمان: $warrantyDays',
          '',
          'بداية الضمان: ${_date(warrantyStart)}',
          '',
          'نهاية الضمان: ${_date(warrantyEnd)}',
          '',
          'رقم الطلب: $ticket',
          '',
          'نشكركم لاختياركم خدماتنا.',
        ].join('\n');
      case AppConstants.waMsgReadyReminder1:
      case AppConstants.waMsgReadyReminder3:
      case AppConstants.waMsgReadyReminder7:
        return [
          'مرحباً $name،',
          '',
          'نذكركم بأن جهازكم ما زال جاهزاً للاستلام.',
          '',
          'الجهاز: $device',
          '',
          'رقم الطلب: $ticket',
          '',
          'تاريخ جاهزية الجهاز: ${_date(readyAt)}',
        ].join('\n');
      case AppConstants.waMsgWarrantyExpiring:
        return [
          'مرحباً $name،',
          '',
          'نود تذكيركم بأن ضمان صيانة جهازكم سينتهي قريباً.',
          '',
          'الجهاز: $device',
          '',
          'الصيانة المشمولة: $repairDetails',
          '',
          'تاريخ انتهاء الضمان: ${_date(warrantyEnd)}',
        ].join('\n');
      case AppConstants.waMsgWarrantyClaim:
        return [
          'مرحباً $name،',
          '',
          'تم استلام جهازكم للفحص ضمن طلب الضمان.',
          '',
          'الجهاز: $device',
          '',
          'رقم الطلب: $ticket',
          '',
          'سنقوم بفحص الجهاز وإبلاغكم بالنتيجة.',
        ].join('\n');
      default:
        return [
          'مرحباً $name،',
          '',
          'تحديث بخصوص جهازكم $device.',
          '',
          'رقم الطلب: $ticket',
        ].join('\n');
    }
  }

  Future<String> _unrepairableReason(
    String maintenanceId,
    Map<String, dynamic> data,
  ) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT h.reason, h.notes
FROM maintenance_status_history h
JOIN maintenance m ON m.id = h.maintenance_id
WHERE m.shop_id = ?
  AND h.maintenance_id = ?
  AND h.new_status = ?
ORDER BY h.changed_at DESC
LIMIT 1
''', [shopId, maintenanceId, AppConstants.statusUnrepairable]);
    if (rows.isNotEmpty) {
      final reason = _text(rows.first['reason']);
      final notes = _text(rows.first['notes']);
      final combined = [reason, notes].where((v) => v.isNotEmpty).join(' - ');
      if (combined.isNotEmpty) return combined;
    }
    return _fallback(
      _text(data['internal_notes']).isNotEmpty
          ? _text(data['internal_notes'])
          : _text(data['notes']),
      _fallback(_text(data['fault_description']), 'تعذر الإصلاح بعد الفحص'),
    );
  }

  String _repairDetails(Map<String, dynamic> data) {
    final notes = _text(data['notes']);
    final internalNotes = _text(data['internal_notes']);
    if (notes.isNotEmpty) return notes;
    if (internalNotes.isNotEmpty) return internalNotes;
    return _fallback(_text(data['fault_description']), 'صيانة الجهاز');
  }

  Future<String> _requiredPart(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery('''
SELECT p.product_name
FROM maintenance_parts p
JOIN maintenance m ON m.id = p.maintenance_id
WHERE m.shop_id = ?
  AND p.maintenance_id = ?
ORDER BY p.created_at DESC
LIMIT 1
''', [shopId, maintenanceId]);
    if (rows.isEmpty) return '';
    return _text(rows.first['product_name']);
  }

  String _warrantyDays(Map<String, dynamic> data) {
    final days =
        _int(data['warranty_days_value']) ?? _int(data['warranty_days']);
    if (days == null || days <= 0) return 'لا يوجد ضمان';
    return '$days يوم';
  }

  // ---------------------------------------------------------------------------
  // Direct/manual sending and logs
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(
    String phone,
    String message, {
    String? customerId,
    String? referenceId,
    String? templateKey,
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw Exception('نص الرسالة فارغ');
    }

    final cleanPhone = normalizePhone(phone);
    if (cleanPhone == null) {
      throw Exception('رقم العميل غير صالح ولا يمكن فتح WhatsApp');
    }

    final launched = await WhatsAppLauncher.send(
      phone: cleanPhone,
      message: cleanMessage,
    );
    if (!launched) {
      throw Exception('تعذر فتح WhatsApp Desktop أو WhatsApp Web');
    }

    await _db.insert('whatsapp_logs', {
      'id': _uuid.v4(),
      'customer_id': customerId,
      'phone': cleanPhone,
      'message': cleanMessage,
      'template_key': templateKey,
      'reference_id': referenceId,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getLogs({String? customerId}) async {
    if (customerId != null) {
      return _db.query(
        'whatsapp_logs',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'sent_at DESC',
      );
    }
    return _db.query('whatsapp_logs', orderBy: 'sent_at DESC');
  }

  String? normalizePhone(String phone) {
    var clean = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    clean = clean.replaceFirst(RegExp(r'^\+'), '');
    if (clean.startsWith('00')) clean = clean.substring(2);
    clean = clean.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('05') && clean.length == 10) {
      clean = '966${clean.substring(1)}';
    } else if (clean.startsWith('5') && clean.length == 9) {
      clean = '966$clean';
    }
    if (clean.length < 8 || clean.length > 15) return null;
    if (RegExp(r'^0+$').hasMatch(clean)) return null;
    return clean;
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _date(int? ms) {
    if (ms == null || ms <= 0) return 'غير محدد';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _money(double value) {
    if (value <= 0) return 'غير محددة';
    return '${value.toStringAsFixed(2)} ر.س';
  }
}
