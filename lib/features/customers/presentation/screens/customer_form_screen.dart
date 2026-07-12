import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/customer_model.dart';
import '../../data/customers_repository.dart';

class CustomerFormScreen extends StatefulWidget {
  final String? customerId;
  const CustomerFormScreen({super.key, this.customerId});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CustomersRepository();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _customerType = 'regular';

  bool _loading = false;
  bool _saving = false;
  CustomerModel? _existing;

  bool get _isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final customer = await _repo.getById(widget.customerId!);
    if (customer != null && mounted) {
      _existing = customer;
      _nameCtrl.text = customer.name;
      _phoneCtrl.text = customer.phone;
      _phone2Ctrl.text = customer.phone2 ?? '';
      _emailCtrl.text = customer.email ?? '';
      _addressCtrl.text = customer.address ?? '';
      _notesCtrl.text = customer.notes ?? '';
      _customerType = customer.customerType;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (_isEditing && _existing != null) {
        final updated = _existing!.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          phone2:
              _phone2Ctrl.text.trim().isEmpty ? null : _phone2Ctrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          customerType: _customerType,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _repo.update(updated);
      } else {
        final customer = CustomerModel.create(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          phone2:
              _phone2Ctrl.text.trim().isEmpty ? null : _phone2Ctrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          customerType: _customerType,
        );
        await _repo.create(customer);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('حدث خطأ: ${e.toString()}', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.lightText),
            onPressed: () => context.pop(),
          ),
          title: Text(
            _isEditing ? 'تعديل العميل' : 'عميل جديد',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              color: AppColors.lightText,
              fontSize: 18,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text('حفظ',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'البيانات الأساسية'),
                      const SizedBox(height: 12),
                      _field(
                        controller: _nameCtrl,
                        label: 'الاسم',
                        icon: Icons.person_outline,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _phoneCtrl,
                        label: 'الجوال',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _phone2Ctrl,
                        label: 'جوال إضافي',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _emailCtrl,
                        label: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader(title: 'بيانات إضافية'),
                      const SizedBox(height: 12),
                      _field(
                        controller: _addressCtrl,
                        label: 'العنوان',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildTypeSelector(),
                      const SizedBox(height: 12),
                      _field(
                        controller: _notesCtrl,
                        label: 'ملاحظات',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  _isEditing ? 'حفظ التعديلات' : 'إضافة العميل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.cairo(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(
            color: AppColors.lightTextSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      ('regular', 'عادي', AppColors.secondary),
      ('vip', 'مميز', AppColors.warning),
      ('wholesale', 'جملة', AppColors.info),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع العميل',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: types.map((t) {
            final selected = _customerType == t.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _customerType = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        selected ? t.$3.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? t.$3 : AppColors.lightBorder,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    t.$2,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? t.$3 : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.lightText,
          ),
        ),
      ],
    );
  }
}
