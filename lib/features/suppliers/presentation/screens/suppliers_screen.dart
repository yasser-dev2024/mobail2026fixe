import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/supplier_model.dart';
import '../cubit/suppliers_cubit.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  late final SuppliersCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = SuppliersCubit()..load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<SuppliersCubit, SuppliersState>(
        listener: (context, state) {
          if (state is SuppliersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error),
            );
          }
          if (state is SuppliersSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم الحفظ بنجاح'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          final suppliers =
              state is SuppliersLoaded ? state.suppliers : <SupplierModel>[];
          return Scaffold(
            backgroundColor: context.appColors.background,
            body: Column(
              children: [
                _buildHeader(context, suppliers.length),
                _buildSearch(context),
                Expanded(
                  child: state is SuppliersLoading
                      ? const Center(child: CircularProgressIndicator())
                      : suppliers.isEmpty
                          ? _buildEmpty()
                          : _buildList(context, suppliers),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showForm(context, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'إضافة مورد',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الموردون',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('$count مورد مسجل',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchCtrl,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'بحث باسم المورد أو رقم الهاتف...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _cubit.load();
                  },
                )
              : null,
        ),
        onChanged: (v) => _cubit.load(search: v.isEmpty ? null : v),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<SupplierModel> suppliers) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: suppliers.length,
      itemBuilder: (context, i) => _SupplierCard(
        supplier: suppliers[i],
        onEdit: () => _showForm(context, suppliers[i]),
        onDelete: () => _confirmDelete(context, suppliers[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'لا يوجد موردون',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على الزر أدناه لإضافة مورد جديد',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, SupplierModel? supplier) {
    showDialog(
      context: context,
      builder: (_) => _SupplierFormDialog(
        supplier: supplier,
        onSave: (s) => _cubit.save(s, isNew: supplier == null),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف المورد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        content:
            Text('هل تريد حذف "${supplier.name}"؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _cubit.delete(supplier.id);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supplier Card
// ---------------------------------------------------------------------------

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fmt = NumberFormat('#,##0.00', 'ar');
    final hasDebt = supplier.balance > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  supplier.name.isNotEmpty ? supplier.name[0] : 'م',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (supplier.phone != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.phone_rounded,
                          size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        supplier.phone!,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ]),
                  ],
                  if (supplier.email != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.email_rounded,
                          size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        supplier.email!,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasDebt
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasDebt
                        ? '${fmt.format(supplier.balance)} ر.س'
                        : 'لا يوجد دين',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasDebt ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.delete_rounded,
                            size: 18, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supplier Form Dialog
// ---------------------------------------------------------------------------

class _SupplierFormDialog extends StatefulWidget {
  final SupplierModel? supplier;
  final void Function(SupplierModel) onSave;

  const _SupplierFormDialog({this.supplier, required this.onSave});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _phone2Ctrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _phone2Ctrl = TextEditingController(text: s?.phone2 ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;
    return Dialog(
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'تعديل المورد' : 'إضافة مورد جديد',
                  style: GoogleFonts.cairo(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 20),
                _field(_nameCtrl, 'اسم المورد *', required: true),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_phoneCtrl, 'رقم الهاتف')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_phone2Ctrl, 'رقم هاتف إضافي')),
                ]),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'البريد الإلكتروني'),
                const SizedBox(height: 12),
                _field(_addressCtrl, 'العنوان'),
                const SizedBox(height: 12),
                _field(_notesCtrl, 'ملاحظات', maxLines: 2),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إلغاء', style: GoogleFonts.cairo()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        isEdit ? 'تحديث' : 'إضافة',
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final s = widget.supplier;
    String? nullable(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final model = s != null
        ? s.copyWith(
            name: _nameCtrl.text.trim(),
            phone: nullable(_phoneCtrl),
            phone2: nullable(_phone2Ctrl),
            email: nullable(_emailCtrl),
            address: nullable(_addressCtrl),
            notes: nullable(_notesCtrl),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
        : SupplierModel.create(
            name: _nameCtrl.text.trim(),
            phone: nullable(_phoneCtrl),
            phone2: nullable(_phone2Ctrl),
            email: nullable(_emailCtrl),
            address: nullable(_addressCtrl),
            notes: nullable(_notesCtrl),
          );
    widget.onSave(model);
    Navigator.pop(context);
  }
}
