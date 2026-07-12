import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/whatsapp_repository.dart';
import '../../data/whatsapp_template_model.dart';

class WhatsappScreen extends StatefulWidget {
  const WhatsappScreen({super.key});

  @override
  State<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends State<WhatsappScreen> {
  final _repo = WhatsappRepository();
  final _db = DatabaseService();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  List<WhatsappTemplateModel> _templates = [];
  List<Map<String, dynamic>> _logs = [];
  WhatsappTemplateModel? _selectedTemplate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final templates = await _repo.getTemplates();
    final logs = await _repo.getLogs();
    final prefill = await _routePrefill(templates);
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _logs = logs;
      _selectedTemplate =
          prefill?.template ?? (templates.isEmpty ? null : templates.first);
      _phoneCtrl.text = prefill?.phone ?? _phoneCtrl.text;
      _messageCtrl.text =
          prefill?.message ?? _selectedTemplate?.template ?? _messageCtrl.text;
      _loading = false;
    });
  }

  Future<_WhatsappPrefill?> _routePrefill(
    List<WhatsappTemplateModel> templates,
  ) async {
    final params = GoRouterState.of(context).uri.queryParameters;
    final directPhone = params['phone'];
    final directMessage = params['message'];
    if (directPhone != null || directMessage != null) {
      return _WhatsappPrefill(
        phone: directPhone ?? '',
        message: directMessage ?? '',
        template: null,
      );
    }

    final maintenanceId = params['maintenanceId'];
    if (maintenanceId == null || maintenanceId.isEmpty) return null;

    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT
        m.ticket_number,
        m.brand,
        m.model,
        m.status,
        m.estimated_delivery,
        m.warranty_end,
        c.name AS customer_name,
        c.phone AS customer_phone,
        c.phone2 AS customer_phone2
      FROM maintenance m
      LEFT JOIN customers c ON c.id = m.customer_id AND c.shop_id = m.shop_id
      WHERE m.shop_id = ? AND m.id = ? AND m.deleted_at IS NULL
      LIMIT 1
      ''',
      [shopId, maintenanceId],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final status = row['status'] as String? ?? AppConstants.statusNew;
    final templateKey = _templateKeyForStatus(status);
    WhatsappTemplateModel? template;
    for (final item in templates) {
      if (item.key == templateKey) {
        template = item;
        break;
      }
    }
    final customerName = row['customer_name'] as String? ?? 'عميلنا';
    final device = '${row['brand'] ?? ''} ${row['model'] ?? ''}'.trim();
    final deliveryDate = _formatOptionalDate(row['estimated_delivery'] as int?);
    final warrantyEnd = _formatOptionalDate(row['warranty_end'] as int?);
    final variables = {
      'customer_name': customerName,
      'device': device.isEmpty ? 'جهازك' : device,
      'ticket_number': row['ticket_number'] as String? ?? '',
      'delivery_date': deliveryDate,
      'warranty_end': warrantyEnd,
      'status': _statusLabel(status),
    };

    final message = template?.buildMessage(variables) ??
        'السلام عليكم $customerName،\nحالة جهازك ${variables['device']}: ${variables['status']}.\nرقم الصيانة: ${variables['ticket_number']}';

    return _WhatsappPrefill(
      phone: (row['customer_phone'] as String?) ??
          (row['customer_phone2'] as String?) ??
          '',
      message: message,
      template: template,
    );
  }

  String _templateKeyForStatus(String status) {
    switch (status) {
      case AppConstants.statusInspecting:
      case AppConstants.statusWaitingInspection:
        return AppConstants.waTplInspecting;
      case AppConstants.statusWaitingCustomerApproval:
      case AppConstants.statusCustomerApproved:
      case AppConstants.statusCustomerRejected:
        return AppConstants.waTplInspecting;
      case AppConstants.statusWaitingPart:
        return AppConstants.waTplWaiting;
      case AppConstants.statusRepaired:
      case AppConstants.statusRepairing:
      case AppConstants.statusUnderTesting:
        return AppConstants.waTplRepaired;
      case AppConstants.statusReady:
      case AppConstants.statusDelivered:
        return AppConstants.waTplReady;
      case AppConstants.statusNew:
      default:
        return AppConstants.waTplReceived;
    }
  }

  String _statusLabel(String status) {
    return AppConstants.maintenanceStatusLabel(status);
  }

  String _formatOptionalDate(int? millis) {
    if (millis == null) return '';
    return DateFormat('yyyy/MM/dd', 'ar')
        .format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  Future<void> _send() async {
    final phone = _phoneCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (phone.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الجوال ونص الرسالة')),
      );
      return;
    }
    try {
      await _repo.sendMessage(
        phone,
        message,
        templateKey: _selectedTemplate?.key,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر فتح واتساب: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: _messageCtrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرسالة')),
    );
  }

  Future<void> _editTemplate(WhatsappTemplateModel template) async {
    final nameCtrl = TextEditingController(text: template.name);
    final bodyCtrl = TextEditingController(text: template.template);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل قالب واتساب'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم القالب'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة',
                  hintText: '{customer_name} {ticket_number} {device}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await _repo.updateTemplate(
                template.copyWith(
                  name: nameCtrl.text.trim(),
                  template: bodyCtrl.text.trim(),
                ),
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    bodyCtrl.dispose();
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                final padding = constraints.maxWidth < 520 ? 14.0 : 24.0;
                return ListView(
                  padding: EdgeInsets.all(padding),
                  children: [
                    if (narrow) ...[
                      _buildComposer(),
                      const SizedBox(height: 14),
                      _buildTemplates(),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildComposer()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTemplates()),
                        ],
                      ),
                    const SizedBox(height: 16),
                    _buildLogs(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildComposer() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'إرسال رسالة'),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الجوال',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WhatsappTemplateModel>(
            value: _selectedTemplate,
            decoration: const InputDecoration(labelText: 'القالب'),
            items: _templates
                .map((template) => DropdownMenuItem(
                    value: template, child: Text(template.name)))
                .toList(),
            onChanged: (template) {
              setState(() {
                _selectedTemplate = template;
                _messageCtrl.text = template?.template ?? '';
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'نص الرسالة'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('فتح واتساب'),
              ),
              OutlinedButton.icon(
                onPressed: _copyMessage,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ الرسالة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplates() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'القوالب'),
          const SizedBox(height: 12),
          ..._templates.map(
            (template) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary),
              title: Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                template.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                onPressed: () => _editTemplate(template),
                icon: const Icon(Icons.edit_outlined),
              ),
              onTap: () => setState(() {
                _selectedTemplate = template;
                _messageCtrl.text = template.template;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogs() {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'سجل الرسائل'),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            const EmptyState(
                message: 'لا توجد رسائل مرسلة', icon: Icons.history_rounded)
          else
            ..._logs.take(50).map((log) {
              final sentAt =
                  DateTime.fromMillisecondsSinceEpoch(log['sent_at'] as int);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.done_all_rounded,
                    color: AppColors.success),
                title: Text(log['phone'] as String? ?? ''),
                subtitle: Text(
                  log['message'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(formatter.format(sentAt)),
              );
            }),
        ],
      ),
    );
  }
}

class _WhatsappPrefill {
  final String phone;
  final String message;
  final WhatsappTemplateModel? template;

  const _WhatsappPrefill({
    required this.phone,
    required this.message,
    required this.template,
  });
}
