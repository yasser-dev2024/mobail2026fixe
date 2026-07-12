import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settings = SettingsService();

  final _shopIdCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _tradeNameCtrl = TextEditingController();
  final _managerNameCtrl = TextEditingController();
  final _commercialRegisterCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();

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
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _tradeNameCtrl.dispose();
    _managerNameCtrl.dispose();
    _commercialRegisterCtrl.dispose();
    _taxNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final shopId = await DatabaseService().getCurrentShopId();
    await _settings.reload();
    if (!mounted) return;

    final shopName = _settings.shopName.trim();
    setState(() {
      _shopIdCtrl.text = shopId;
      _shopNameCtrl.text =
          shopName == SettingsService.defaultShopName ? '' : _settings.shopName;
      _phoneCtrl.text = _settings.shopPhone;
      _whatsappCtrl.text = _settings.shopWhatsapp;
      _addressCtrl.text = _settings.shopAddress;
      _tradeNameCtrl.text = _settings.tradeName;
      _managerNameCtrl.text = _settings.managerName;
      _commercialRegisterCtrl.text = _settings.commercialRegister;
      _taxNumberCtrl.text = _settings.taxNumber;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final whatsapp = _whatsappCtrl.text.trim();
      await _settings.completeShopSetup({
        'shop_name': _shopNameCtrl.text.trim(),
        'shop_phone': phone,
        'shop_whatsapp': whatsapp.isEmpty ? phone : whatsapp,
        'shop_address': _addressCtrl.text.trim(),
        'trade_name': _tradeNameCtrl.text.trim(),
        'manager_name': _managerNameCtrl.text.trim(),
        'commercial_register': _commercialRegisterCtrl.text.trim(),
        'tax_number': _taxNumberCtrl.text.trim(),
      });

      if (!mounted) return;
      context.go('/repair-board');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ بيانات المحل. حاول مرة أخرى.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: LoadingOverlay(
        isLoading: _saving,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 720;
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 44 : 18,
                        vertical: isTablet ? 34 : 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isTablet ? 760 : 520,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SetupHeader(isTablet: isTablet),
                                SizedBox(height: isTablet ? 24 : 18),
                                AppCard(
                                  padding: EdgeInsets.all(isTablet ? 24 : 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SectionHeader(
                                        title: 'تسجيل بيانات المحل',
                                      ),
                                      const SizedBox(height: 16),
                                      AppFormField(
                                        label: 'معرف المحل الخاص بهذه النسخة',
                                        controller: _shopIdCtrl,
                                        readOnly: true,
                                        prefix: const Icon(
                                          Icons.verified_user_rounded,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      AppFormField(
                                        label: 'اسم المحل',
                                        controller: _shopNameCtrl,
                                        required: true,
                                        validator: _requiredText,
                                        prefix: const Icon(Icons.store_rounded),
                                      ),
                                      const SizedBox(height: 12),
                                      AppFormField(
                                        label: 'الاسم التجاري',
                                        controller: _tradeNameCtrl,
                                        prefix: const Icon(
                                          Icons.badge_rounded,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _TwoSetupFields(
                                        first: AppFormField(
                                          label: 'جوال المحل',
                                          controller: _phoneCtrl,
                                          required: true,
                                          validator: _requiredText,
                                          keyboardType: TextInputType.phone,
                                          prefix: const Icon(
                                            Icons.phone_rounded,
                                          ),
                                        ),
                                        second: AppFormField(
                                          label: 'رقم واتساب',
                                          controller: _whatsappCtrl,
                                          keyboardType: TextInputType.phone,
                                          prefix: const Icon(
                                            Icons.chat_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      AppFormField(
                                        label: 'العنوان',
                                        controller: _addressCtrl,
                                        prefix: const Icon(
                                          Icons.location_on_rounded,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      AppFormField(
                                        label: 'اسم المسؤول',
                                        controller: _managerNameCtrl,
                                        prefix: const Icon(
                                          Icons.person_rounded,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _TwoSetupFields(
                                        first: AppFormField(
                                          label: 'السجل التجاري',
                                          controller: _commercialRegisterCtrl,
                                          prefix: const Icon(
                                            Icons.assignment_rounded,
                                          ),
                                        ),
                                        second: AppFormField(
                                          label: 'الرقم الضريبي',
                                          controller: _taxNumberCtrl,
                                          prefix: const Icon(
                                            Icons.receipt_long_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      SizedBox(
                                        height: 52,
                                        child: ElevatedButton.icon(
                                          onPressed: _save,
                                          icon: const Icon(
                                            Icons.login_rounded,
                                          ),
                                          label: const Text(
                                            'حفظ والدخول للتطبيق',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.isTablet});

  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Container(
          width: isTablet ? 152 : 126,
          height: isTablet ? 152 : 126,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'إعداد المحل لأول مرة',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: isTablet ? 32 : 26,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'سيتم حفظ هذه البيانات لهذه النسخة فقط، وبعدها يفتح التطبيق مباشرة على شاشة العمل.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _TwoSetupFields extends StatelessWidget {
  const _TwoSetupFields({
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
