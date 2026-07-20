import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  final _shopIdCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _tradeNameCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _mapUrlCtrl = TextEditingController();
  final _trackingBaseUrlCtrl = TextEditingController();
  final _privacyPolicyUrlCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _deviceReceiverCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _logoPathCtrl = TextEditingController();
  final _stampPathCtrl = TextEditingController();
  final _signaturePathCtrl = TextEditingController();
  final _managerNameCtrl = TextEditingController();
  final _managerTitleCtrl = TextEditingController();
  final _invoiceIntroCtrl = TextEditingController();
  final _generalTermsCtrl = TextEditingController();
  final _returnPolicyCtrl = TextEditingController();
  final _legalNotesCtrl = TextEditingController();
  final _copyrightCtrl = TextEditingController();
  final _invoiceMessageCtrl = TextEditingController();
  final _invoicePrefixCtrl = TextEditingController();
  final _photoRequiredCountCtrl = TextEditingController();
  final _photoRequiredTypesCtrl = TextEditingController();
  final _photoOptionalTypesCtrl = TextEditingController();
  final _photoMaxSizeCtrl = TextEditingController();
  final _photoQualityCtrl = TextEditingController();
  final _photoImagesPerPageCtrl = TextEditingController();
  List<String> _deviceReceivers = [];
  bool _autoBackup = false;
  bool _invoiceResetYearly = true;
  bool _invoiceIncludeIntakePhotos = true;
  bool _invoiceShowSignature = true;
  bool _photoCompress = true;
  bool _photoKeepOriginal = true;
  bool _photoWatermarkReports = false;
  bool _photoShowEmployee = true;
  bool _photoShowDateTime = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shopIdCtrl.dispose();
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _tradeNameCtrl.dispose();
    _crCtrl.dispose();
    _taxNumberCtrl.dispose();
    _whatsappCtrl.dispose();
    _mapUrlCtrl.dispose();
    _trackingBaseUrlCtrl.dispose();
    _privacyPolicyUrlCtrl.dispose();
    _taxRateCtrl.dispose();
    _currencyCtrl.dispose();
    _warrantyCtrl.dispose();
    _deviceReceiverCtrl.dispose();
    _footerCtrl.dispose();
    _logoPathCtrl.dispose();
    _stampPathCtrl.dispose();
    _signaturePathCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerTitleCtrl.dispose();
    _invoiceIntroCtrl.dispose();
    _generalTermsCtrl.dispose();
    _returnPolicyCtrl.dispose();
    _legalNotesCtrl.dispose();
    _copyrightCtrl.dispose();
    _invoiceMessageCtrl.dispose();
    _invoicePrefixCtrl.dispose();
    _photoRequiredCountCtrl.dispose();
    _photoRequiredTypesCtrl.dispose();
    _photoOptionalTypesCtrl.dispose();
    _photoMaxSizeCtrl.dispose();
    _photoQualityCtrl.dispose();
    _photoImagesPerPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _service.reload();
    if (!mounted) return;
    setState(() {
      _shopIdCtrl.text = _service.shopId;
      _shopNameCtrl.text = _service.shopName;
      _phoneCtrl.text = _service.shopPhone;
      _phone2Ctrl.text = _service.shopPhone2;
      _addressCtrl.text = _service.shopAddress;
      _emailCtrl.text = _service.shopEmail;
      _tradeNameCtrl.text = _service.tradeName;
      _crCtrl.text = _service.commercialRegister;
      _taxNumberCtrl.text = _service.taxNumber;
      _whatsappCtrl.text = _service.shopWhatsapp;
      _mapUrlCtrl.text = _service.mapUrl;
      _trackingBaseUrlCtrl.text = _service.trackingBaseUrl;
      _privacyPolicyUrlCtrl.text = _service.privacyPolicyUrl;
      _taxRateCtrl.text = _service.taxRate.toString();
      _currencyCtrl.text = _service.currency;
      _warrantyCtrl.text = _service.warrantyTerms;
      _deviceReceivers = _service.deviceReceiverNames.toList();
      _footerCtrl.text = _service.invoiceFooter;
      _logoPathCtrl.text = _service.logoPath;
      _stampPathCtrl.text = _service.stampPath;
      _signaturePathCtrl.text = _service.signaturePath;
      _managerNameCtrl.text = _service.managerName;
      _managerTitleCtrl.text = _service.managerTitle;
      _invoiceIntroCtrl.text = _service.invoiceIntroText;
      _generalTermsCtrl.text = _service.invoiceGeneralTerms;
      _returnPolicyCtrl.text = _service.invoiceReturnPolicy;
      _legalNotesCtrl.text = _service.invoiceLegalNotes;
      _copyrightCtrl.text = _service.invoiceCopyright;
      _invoiceMessageCtrl.text = _service.invoiceMessageTemplate;
      _invoicePrefixCtrl.text = _service.invoicePrefix;
      _photoRequiredCountCtrl.text = _service.photoRequiredCount.toString();
      _photoRequiredTypesCtrl.text = _service.photoRequiredTypes.join('\n');
      _photoOptionalTypesCtrl.text = _service.photoOptionalTypes.join('\n');
      _photoMaxSizeCtrl.text = _service.photoMaxSizeMb.toString();
      _photoQualityCtrl.text = _service.photoQuality.toString();
      _photoImagesPerPageCtrl.text =
          _service.photoReportImagesPerPage.toString();
      _autoBackup = _service.autoBackup;
      _invoiceResetYearly = _service.invoiceResetYearly;
      _invoiceIncludeIntakePhotos = _service.invoiceIncludeIntakePhotos;
      _invoiceShowSignature = _service.invoiceShowSignature;
      _photoCompress = _service.photoCompress;
      _photoKeepOriginal = _service.photoKeepOriginal;
      _photoWatermarkReports = _service.photoWatermarkReports;
      _photoShowEmployee = _service.photoShowEmployee;
      _photoShowDateTime = _service.photoShowDateTime;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final receiverNames = _normalizedReceiverNames(includeDraft: true);
    setState(() => _saving = true);
    await _service.save({
      'shop_name': _shopNameCtrl.text.trim(),
      'shop_phone': _phoneCtrl.text.trim(),
      'shop_phone2': _phone2Ctrl.text.trim(),
      'shop_address': _addressCtrl.text.trim(),
      'shop_email': _emailCtrl.text.trim(),
      'trade_name': _tradeNameCtrl.text.trim(),
      'commercial_register': _crCtrl.text.trim(),
      'tax_number': _taxNumberCtrl.text.trim(),
      'shop_whatsapp': _whatsappCtrl.text.trim(),
      'map_url': _mapUrlCtrl.text.trim(),
      'tracking_base_url': _trackingBaseUrlCtrl.text.trim(),
      'privacy_policy_url': _privacyPolicyUrlCtrl.text.trim(),
      'tax_rate': _taxRateCtrl.text.trim(),
      'currency':
          _currencyCtrl.text.trim().isEmpty ? 'ر.س' : _currencyCtrl.text.trim(),
      'warranty_terms': _warrantyCtrl.text.trim(),
      'device_receiver_name': receiverNames.isEmpty ? '' : receiverNames.first,
      'device_receiver_names': receiverNames.join('\n'),
      'invoice_footer': _footerCtrl.text.trim(),
      'logo_path': _logoPathCtrl.text.trim(),
      'stamp_path': _stampPathCtrl.text.trim(),
      'signature_path': _signaturePathCtrl.text.trim(),
      'manager_name': _managerNameCtrl.text.trim(),
      'manager_title': _managerTitleCtrl.text.trim(),
      'invoice_intro_text': _invoiceIntroCtrl.text.trim(),
      'invoice_general_terms': _generalTermsCtrl.text.trim(),
      'invoice_return_policy': _returnPolicyCtrl.text.trim(),
      'invoice_legal_notes': _legalNotesCtrl.text.trim(),
      'invoice_copyright': _copyrightCtrl.text.trim(),
      'invoice_message_template': _invoiceMessageCtrl.text.trim(),
      'invoice_prefix': _invoicePrefixCtrl.text.trim().isEmpty
          ? 'INV'
          : _invoicePrefixCtrl.text.trim(),
      'invoice_reset_yearly': _invoiceResetYearly ? 'true' : 'false',
      'invoice_include_intake_photos':
          _invoiceIncludeIntakePhotos ? 'true' : 'false',
      'invoice_show_signature': _invoiceShowSignature ? 'true' : 'false',
      'photo_required_count': _photoRequiredCountCtrl.text.trim().isEmpty
          ? '0'
          : _photoRequiredCountCtrl.text.trim(),
      'photo_required_types': _photoRequiredTypesCtrl.text.trim(),
      'photo_optional_types': _photoOptionalTypesCtrl.text.trim(),
      'photo_max_size_mb': _photoMaxSizeCtrl.text.trim().isEmpty
          ? '10'
          : _photoMaxSizeCtrl.text.trim(),
      'photo_quality': _photoQualityCtrl.text.trim().isEmpty
          ? '85'
          : _photoQualityCtrl.text.trim(),
      'photo_compress': _photoCompress ? 'true' : 'false',
      'photo_keep_original': _photoKeepOriginal ? 'true' : 'false',
      'photo_watermark_reports': _photoWatermarkReports ? 'true' : 'false',
      'photo_report_images_per_page':
          _photoImagesPerPageCtrl.text.trim().isEmpty
              ? '4'
              : _photoImagesPerPageCtrl.text.trim(),
      'photo_show_employee': _photoShowEmployee ? 'true' : 'false',
      'photo_show_datetime': _photoShowDateTime ? 'true' : 'false',
      'auto_backup': _autoBackup ? 'true' : 'false',
      'auto_backup_interval':
          AppConstants.automaticBackupIntervalDays.toString(),
      'shop_setup_completed': 'true',
    });
    if (!mounted) return;
    setState(() {
      _deviceReceivers = receiverNames;
      _deviceReceiverCtrl.clear();
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعدادات')),
    );
  }

  List<String> _normalizedReceiverNames({bool includeDraft = false}) {
    final names = <String>[
      ..._deviceReceivers,
      if (includeDraft) _deviceReceiverCtrl.text,
    ];
    final seen = <String>{};
    return names
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((value) => seen.add(value))
        .toList();
  }

  void _addDeviceReceiver() {
    final name = _deviceReceiverCtrl.text.trim();
    if (name.isEmpty) return;
    if (_deviceReceivers.contains(name)) {
      _deviceReceiverCtrl.clear();
      return;
    }
    setState(() {
      _deviceReceivers = [..._deviceReceivers, name];
      _deviceReceiverCtrl.clear();
    });
  }

  void _removeDeviceReceiver(String name) {
    setState(() {
      _deviceReceivers =
          _deviceReceivers.where((value) => value != name).toList();
    });
  }

  void _makeDefaultDeviceReceiver(String name) {
    setState(() {
      _deviceReceivers = [
        name,
        ..._deviceReceivers.where((value) => value != name),
      ];
    });
  }

  Future<void> _pickLogo() async {
    await _pickImagePath(_logoPathCtrl);
  }

  Future<void> _pickImagePath(TextEditingController controller) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => controller.text = path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: LoadingOverlay(
        isLoading: _saving,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 720;
                  final topSections = isNarrow
                      ? Column(
                          children: [
                            _buildShopSettings(),
                            const SizedBox(height: 16),
                            _buildSystemSettings(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildShopSettings()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSystemSettings()),
                          ],
                        );

                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      topSections,
                      const SizedBox(height: 16),
                      _buildInvoiceSettings(),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('حفظ الإعدادات'),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildShopSettings() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'بيانات المتجر'),
          const SizedBox(height: 16),
          AppFormField(
            label: 'معرف المحل الخاص بهذه النسخة',
            controller: _shopIdCtrl,
            readOnly: true,
            prefix: const Icon(Icons.verified_user_rounded),
          ),
          const SizedBox(height: 12),
          AppFormField(label: 'اسم المتجر', controller: _shopNameCtrl),
          const SizedBox(height: 12),
          AppFormField(label: 'الاسم التجاري', controller: _tradeNameCtrl),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: AppFormField(label: 'الجوال', controller: _phoneCtrl)),
              const SizedBox(width: 12),
              Expanded(
                  child: AppFormField(
                      label: 'جوال إضافي', controller: _phone2Ctrl)),
            ],
          ),
          const SizedBox(height: 12),
          AppFormField(label: 'رقم واتساب', controller: _whatsappCtrl),
          const SizedBox(height: 12),
          AppFormField(label: 'العنوان', controller: _addressCtrl),
          const SizedBox(height: 12),
          AppFormField(
              label: 'رابط الموقع على الخريطة', controller: _mapUrlCtrl),
          const SizedBox(height: 12),
          AppFormField(
            label: 'رابط تتبع العميل',
            controller: _trackingBaseUrlCtrl,
            prefix: const Icon(Icons.link_rounded),
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'رابط سياسة الخصوصية',
            controller: _privacyPolicyUrlCtrl,
            prefix: const Icon(Icons.privacy_tip_rounded),
          ),
          const SizedBox(height: 12),
          AppFormField(label: 'البريد الإلكتروني', controller: _emailCtrl),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: AppFormField(
                      label: 'السجل التجاري', controller: _crCtrl)),
              const SizedBox(width: 12),
              Expanded(
                  child: AppFormField(
                      label: 'الرقم الضريبي', controller: _taxNumberCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSettings() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'إعدادات النظام'),
          const SizedBox(height: 16),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              return SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('فاتح')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('داكن')),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.computer),
                      label: Text('النظام')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  final selected = selection.first;
                  final cubit = context.read<ThemeCubit>();
                  if (selected == ThemeMode.light) cubit.setLight();
                  if (selected == ThemeMode.dark) cubit.setDark();
                  if (selected == ThemeMode.system) cubit.setSystem();
                },
              );
            },
          ),
          const SizedBox(height: 16),
          AppFormField(
            label: 'العملة',
            controller: _currencyCtrl,
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'نسبة الضريبة',
            controller: _taxRateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _buildDeviceReceiverSettings(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/settings/alert-sounds'),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('إعدادات صوت التنبيهات'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('النسخ الاحتياطي التلقائي'),
            subtitle: const Text(
              'يتم إنشاء نسخة تلقائية كل ${AppConstants.automaticBackupIntervalDays} أيام عند فتح شاشة النسخ الاحتياطي',
            ),
            value: _autoBackup,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _autoBackup = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/settings/whatsapp-messages'),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('إعدادات رسائل واتساب'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceReceiverSettings() {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_ind_rounded,
                  color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مستلمو الأجهزة / المهندسون',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deviceReceiverCtrl,
                  textDirection: TextDirection.rtl,
                  onSubmitted: (_) => _addDeviceReceiver(),
                  decoration: const InputDecoration(
                    labelText: 'أضف اسم مستلم أو مهندس صيانة',
                    prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _addDeviceReceiver,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_deviceReceivers.isEmpty)
            Text(
              'أضف الأسماء هنا، وسيظهر أول اسم تلقائياً عند استلام الجوال.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _deviceReceivers)
                  _ReceiverNameChip(
                    name: name,
                    isDefault: name == _deviceReceivers.first,
                    onMakeDefault: () => _makeDefaultDeviceReceiver(name),
                    onDelete: () => _removeDeviceReceiver(name),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSettings() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'إعدادات الفاتورة والضمان'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'بادئة رقم الفاتورة',
                  controller: _invoicePrefixCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إعادة ضبط التسلسل سنوياً'),
                  value: _invoiceResetYearly,
                  activeColor: AppColors.primary,
                  onChanged: (value) =>
                      setState(() => _invoiceResetYearly = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تضمين صور الاستلام في الفاتورة'),
                  value: _invoiceIncludeIntakePhotos,
                  activeColor: AppColors.primary,
                  onChanged: (value) =>
                      setState(() => _invoiceIncludeIntakePhotos = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'نص ترحيبي أعلى الفاتورة',
            controller: _invoiceIntroCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'تذييل الفاتورة',
            controller: _footerCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'اسم المسؤول',
                  controller: _managerNameCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'المسمى الوظيفي',
                  controller: _managerTitleCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إظهار التوقيع'),
                  value: _invoiceShowSignature,
                  activeColor: AppColors.primary,
                  onChanged: (value) =>
                      setState(() => _invoiceShowSignature = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildAssetPicker(
                label: 'شعار المركز',
                controller: _logoPathCtrl,
                icon: Icons.storefront_rounded,
                onPick: _pickLogo,
              ),
              _buildAssetPicker(
                label: 'ختم المركز',
                controller: _stampPathCtrl,
                icon: Icons.verified_rounded,
                onPick: () => _pickImagePath(_stampPathCtrl),
              ),
              _buildAssetPicker(
                label: 'توقيع المسؤول',
                controller: _signaturePathCtrl,
                icon: Icons.draw_rounded,
                onPick: () => _pickImagePath(_signaturePathCtrl),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppFormField(
            label: 'شروط الضمان العامة',
            controller: _warrantyCtrl,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'شروط عامة ثابتة للمركز',
                  controller: _generalTermsCtrl,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'سياسة الاستبدال أو الاسترجاع',
                  controller: _returnPolicyCtrl,
                  maxLines: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'ملاحظات قانونية أو تنظيمية',
                  controller: _legalNotesCtrl,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'نص حقوق الملكية',
                  controller: _copyrightCtrl,
                  maxLines: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'رسالة إرسال الفاتورة للعميل',
            controller: _invoiceMessageCtrl,
            maxLines: 5,
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'إعدادات تصوير الأجهزة والتقارير المصورة'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'عدد الصور المطلوبة عند الاستلام',
                  controller: _photoRequiredCountCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'الحد الأقصى لحجم الصورة MB',
                  controller: _photoMaxSizeCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'جودة حفظ الصور',
                  controller: _photoQualityCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'عدد الصور في كل صفحة تقرير',
                  controller: _photoImagesPerPageCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'أنواع الصور الإلزامية (كل نوع في سطر)',
                  controller: _photoRequiredTypesCtrl,
                  maxLines: 5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  label: 'أنواع الصور الاختيارية (كل نوع في سطر)',
                  controller: _photoOptionalTypesCtrl,
                  maxLines: 5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _SwitchChip(
                label: 'ضغط الصور',
                value: _photoCompress,
                onChanged: (value) => setState(() => _photoCompress = value),
              ),
              _SwitchChip(
                label: 'الاحتفاظ بالأصل',
                value: _photoKeepOriginal,
                onChanged: (value) =>
                    setState(() => _photoKeepOriginal = value),
              ),
              _SwitchChip(
                label: 'علامة مائية في التقرير',
                value: _photoWatermarkReports,
                onChanged: (value) =>
                    setState(() => _photoWatermarkReports = value),
              ),
              _SwitchChip(
                label: 'إظهار اسم الموظف',
                value: _photoShowEmployee,
                onChanged: (value) =>
                    setState(() => _photoShowEmployee = value),
              ),
              _SwitchChip(
                label: 'إظهار التاريخ والوقت',
                value: _photoShowDateTime,
                onChanged: (value) =>
                    setState(() => _photoShowDateTime = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetPicker({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    final path = controller.text.trim();
    final hasFile = path.isNotEmpty && File(path).existsSync();
    return SizedBox(
      width: 360,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasFile
                  ? Image.file(File(path), fit: BoxFit.contain)
                  : Icon(icon, color: AppColors.primary, size: 34),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFormField(label: label, controller: controller),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPick,
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('اختيار صورة'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => controller.clear()),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('مسح'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      avatar: Icon(
        value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        size: 18,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      checkmarkColor: AppColors.primary,
    );
  }
}

class _ReceiverNameChip extends StatelessWidget {
  final String name;
  final bool isDefault;
  final VoidCallback onMakeDefault;
  final VoidCallback onDelete;

  const _ReceiverNameChip({
    required this.name,
    required this.isDefault,
    required this.onMakeDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDefault
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDefault
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDefault ? Icons.verified_user_rounded : Icons.engineering_rounded,
            color: isDefault ? AppColors.success : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (isDefault) ...[
            const SizedBox(width: 6),
            const Text(
              'الأول',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'اجعله الأول عند الاستلام',
              child: IconButton(
                onPressed: onMakeDefault,
                icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
                color: AppColors.primary,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
              ),
            ),
          ],
          Tooltip(
            message: 'حذف الاسم',
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded),
              color: AppColors.error,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 28,
                height: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
