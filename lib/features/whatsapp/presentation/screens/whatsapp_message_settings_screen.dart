import 'package:flutter/material.dart';

import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/whatsapp_repository.dart';
import '../../data/whatsapp_template_model.dart';

const _placeholderKeys = [
  'اسم العميل',
  'نوع الجهاز',
  'رقم الجهاز',
  'رقم أمر الصيانة',
  'اسم الفني',
  'تاريخ الاستلام',
  'تاريخ التسليم',
  'مدة الضمان',
];

const _sampleVariables = <String, String>{
  'اسم العميل': 'محمد أحمد',
  'نوع الجهاز': 'آيفون 13 برو',
  'رقم الجهاز': '352099001761481',
  'رقم أمر الصيانة': 'MNT-20260101-0001',
  'اسم الفني': 'خالد',
  'تاريخ الاستلام': '2026-01-01',
  'تاريخ التسليم': '2026-01-03',
  'مدة الضمان': '30 يوم',
};

class WhatsappMessageSettingsScreen extends StatefulWidget {
  const WhatsappMessageSettingsScreen({super.key});

  @override
  State<WhatsappMessageSettingsScreen> createState() =>
      _WhatsappMessageSettingsScreenState();
}

class _WhatsappMessageSettingsScreenState
    extends State<WhatsappMessageSettingsScreen> {
  final _repo = WhatsappRepository();
  final _settings = SettingsService();

  bool _masterEnabled = true;
  bool _autoSend = false;
  bool _loading = true;
  List<WhatsappTemplateModel> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _settings.reload();
    final templates = await _repo.getAutomaticMessageTemplates();
    if (!mounted) return;
    setState(() {
      _masterEnabled = _settings.whatsappMessageTypesMasterEnabled;
      _autoSend = _settings.autoWhatsappSend;
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _saveToggles() async {
    await _settings.save({
      'whatsapp_message_types_master_enabled': _masterEnabled ? 'true' : 'false',
      'auto_whatsapp_send': _autoSend ? 'true' : 'false',
    });
  }

  Future<void> _toggleTemplate(WhatsappTemplateModel template, bool value) async {
    final updated = template.copyWith(isActive: value);
    await _repo.updateTemplate(updated);
    setState(() {
      _templates = _templates
          .map((t) => t.id == template.id ? updated : t)
          .toList();
    });
  }

  Future<void> _editTemplate(WhatsappTemplateModel template) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TemplateEditorDialog(template: template),
    );
    if (result == null) return;
    final updated = template.copyWith(template: result);
    await _repo.updateTemplate(updated);
    setState(() {
      _templates = _templates
          .map((t) => t.id == template.id ? updated : t)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('إعدادات رسائل واتساب')),
      body: LoadingOverlay(
        isLoading: _loading,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تفعيل جميع الرسائل التلقائية'),
                    subtitle: const Text(
                      'إيقافه يوقف كل الرسائل التلقائية أدناه دفعة واحدة',
                    ),
                    value: _masterEnabled,
                    activeColor: AppColors.success,
                    onChanged: (value) {
                      setState(() => _masterEnabled = value);
                      _saveToggles();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إرسال WhatsApp تلقائياً'),
                    subtitle: const Text(
                      'عند الإيقاف، تُجهز الرسالة ويراجعها الموظف قبل الإرسال',
                    ),
                    value: _autoSend,
                    activeColor: AppColors.success,
                    onChanged: (value) {
                      setState(() => _autoSend = value);
                      _saveToggles();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final template in _templates) ...[
              _buildTemplateCard(template, colors),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    WhatsappTemplateModel template,
    AppColorsExtension colors,
  ) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (template.template.trim().isEmpty)
                  Text(
                    'النص الافتراضي',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  )
                else
                  Text(
                    template.template,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editTemplate(template),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'تعديل القالب',
          ),
          Switch(
            value: template.isActive,
            activeColor: AppColors.success,
            onChanged: (value) => _toggleTemplate(template, value),
          ),
        ],
      ),
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  final WhatsappTemplateModel template;
  const _TemplateEditorDialog({required this.template});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late final TextEditingController _ctrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.template.template);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String key) {
    final text = _ctrl.text;
    final selection = _ctrl.selection;
    final insertAt = selection.isValid ? selection.start : text.length;
    final newText =
        text.replaceRange(insertAt, selection.isValid ? selection.end : insertAt, '{$key}');
    _ctrl.text = newText;
    _ctrl.selection =
        TextSelection.collapsed(offset: insertAt + key.length + 2);
    setState(() {});
  }

  String get _preview =>
      widget.template.copyWith(template: _ctrl.text).buildMessage(_sampleVariables);

  Future<void> _sendTest() async {
    final phone = SettingsService().shopWhatsapp.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف رقم واتساب المحل في الإعدادات لتجربة الإرسال'),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    await WhatsAppLauncher.send(phone: phone, message: _preview);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template.name),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اترك النص فارغاً لاستخدام صياغة التطبيق الافتراضية.',
                style: TextStyle(
                    color: Theme.of(context).hintColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'اكتب نص الرسالة هنا...',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in _placeholderKeys)
                    ActionChip(
                      label: Text('{$key}', style: const TextStyle(fontSize: 11)),
                      onPressed: () => _insertPlaceholder(key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_ctrl.text.trim().isNotEmpty) ...[
                Text('معاينة:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).hintColor)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_preview),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _sendTest,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('إرسال تجريبي لرقم المحل'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
