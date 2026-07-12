import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_service.dart';
import '../../../suppliers/data/supplier_model.dart';
import '../../data/product_model.dart';
import '../../data/inventory_repository.dart';
import '../cubit/inventory_cubit.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = InventoryRepository();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  final _lowStockCtrl = TextEditingController(text: '5');
  final _purchasePriceCtrl = TextEditingController(text: '0');
  final _salePriceCtrl = TextEditingController(text: '0');
  final _warrantyDaysCtrl = TextEditingController(text: '0');

  // State
  String? _categoryKey;
  String? _supplierId;
  bool _isService = false;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isEdit = false;
  ProductModel? _existing;

  List<SupplierModel> _suppliers = [];

  static const _categories = [
    _CatDef('phones', 'جوالات'),
    _CatDef('screens', 'شاشات'),
    _CatDef('batteries', 'بطاريات'),
    _CatDef('chargers', 'شواحن'),
    _CatDef('earphones', 'سماعات'),
    _CatDef('cases', 'كفرات'),
    _CatDef('spare_parts', 'قطع غيار'),
    _CatDef('services', 'خدمات'),
    _CatDef('other', 'أخرى'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    if (widget.productId != null) {
      _isEdit = true;
      _loadExisting();
    }
  }

  Future<void> _loadSuppliers() async {
    final db = DatabaseService();
    final rows = await db.query(
      'suppliers',
      where: 'is_active = 1 AND deleted_at IS NULL',
      orderBy: 'name ASC',
    );
    if (!mounted) return;
    setState(() {
      _suppliers = rows.map(SupplierModel.fromMap).toList();
    });
  }

  Future<void> _loadExisting() async {
    final product = await _repo.getById(widget.productId!);
    if (product == null || !mounted) return;
    setState(() {
      _existing = product;
      _nameCtrl.text = product.name;
      _barcodeCtrl.text = product.barcode ?? '';
      _descCtrl.text = product.description ?? '';
      _qtyCtrl.text = product.quantity.toString();
      _lowStockCtrl.text = product.lowStockThreshold.toString();
      _purchasePriceCtrl.text = product.purchasePrice.toStringAsFixed(2);
      _salePriceCtrl.text = product.salePrice.toStringAsFixed(2);
      _warrantyDaysCtrl.text = product.warrantyDays.toString();
      _categoryKey = product.categoryKey;
      _supplierId = product.supplierId;
      _isService = product.isService;
      _isActive = product.isActive;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final qty = int.tryParse(_qtyCtrl.text) ?? 0;
      final lowStock = int.tryParse(_lowStockCtrl.text) ?? 5;
      final purchasePrice = double.tryParse(_purchasePriceCtrl.text) ?? 0;
      final salePrice = double.tryParse(_salePriceCtrl.text) ?? 0;
      final warrantyDays = int.tryParse(_warrantyDaysCtrl.text) ?? 0;

      if (_isEdit && _existing != null) {
        final updated = _existing!.copyWith(
          categoryKey: _categoryKey,
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          quantity: qty,
          lowStockThreshold: lowStock,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          supplierId: _supplierId,
          warrantyDays: warrantyDays,
          isService: _isService,
          isActive: _isActive,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        if (mounted) {
          context.read<InventoryCubit>().update(updated);
        }
      } else {
        final product = ProductModel.create(
          categoryKey: _categoryKey,
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          quantity: qty,
          lowStockThreshold: lowStock,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          supplierId: _supplierId,
          warrantyDays: warrantyDays,
          isService: _isService,
          isActive: _isActive,
        );
        if (mounted) {
          context.read<InventoryCubit>().create(product);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _lowStockCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _salePriceCtrl.dispose();
    _warrantyDaysCtrl.dispose();
    super.dispose();
  }

  void _cancel() {
    context.go('/inventory');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocListener<InventoryCubit, InventoryState>(
      listener: (context, state) {
        if (state is InventorySaved) {
          context.go('/inventory');
        }
        if (state is InventoryError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(
            _isEdit ? 'تعديل المنتج' : 'إضافة منتج جديد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: _cancel,
          ),
          actions: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, color: AppColors.primary),
                label: Text(
                  'حفظ',
                  style: GoogleFonts.cairo(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isEdit ? 'حفظ التعديلات' : 'حفظ المنتج',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _cancel,
                  icon: const Icon(Icons.close_rounded),
                  label: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Basic info ────────────────────────────────────────────────
              _FormSection(
                title: 'المعلومات الأساسية',
                child: Column(
                  children: [
                    // Category
                    DropdownButtonFormField<String>(
                      value: _categoryKey,
                      decoration: InputDecoration(
                        labelText: 'الفئة',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.category_rounded),
                      ),
                      hint: Text('اختر الفئة', style: GoogleFonts.cairo()),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c.key,
                                child:
                                    Text(c.label, style: GoogleFonts.cairo()),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryKey = v),
                    ),

                    const SizedBox(height: 10),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'اسم المنتج *',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'اسم المنتج مطلوب'
                          : null,
                    ),

                    const SizedBox(height: 10),

                    // Barcode
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(
                        labelText: 'الباركود',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.qr_code_rounded),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'الوصف',
                        labelStyle: GoogleFonts.cairo(),
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 28),
                          child: Icon(Icons.description_rounded),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Is service toggle
                    SwitchListTile(
                      value: _isService,
                      onChanged: (v) => setState(() => _isService = v),
                      title: Text('خدمة (بدون مخزون)',
                          style: GoogleFonts.cairo(fontSize: 14)),
                      secondary: const Icon(
                          Icons.miscellaneous_services_rounded,
                          color: AppColors.primary),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                    ),

                    // Is active toggle
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      title:
                          Text('نشط', style: GoogleFonts.cairo(fontSize: 14)),
                      secondary: const Icon(Icons.toggle_on_rounded,
                          color: AppColors.success),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Stock ─────────────────────────────────────────────────────
              if (!_isService) ...[
                _FormSection(
                  title: 'المخزون',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'الكمية',
                            labelStyle: GoogleFonts.cairo(),
                            prefixIcon: const Icon(Icons.numbers_rounded),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 0) {
                              return 'كمية غير صالحة';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lowStockCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'حد التنبيه',
                            labelStyle: GoogleFonts.cairo(),
                            prefixIcon: const Icon(Icons.warning_amber_rounded),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 0) {
                              return 'قيمة غير صالحة';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Pricing ───────────────────────────────────────────────────
              _FormSection(
                title: 'الأسعار',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textDirection: TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: 'سعر الشراء',
                              labelStyle: GoogleFonts.cairo(),
                              prefixIcon:
                                  const Icon(Icons.shopping_bag_rounded),
                              suffixText: 'ر.س',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _salePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textDirection: TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: 'سعر البيع *',
                              labelStyle: GoogleFonts.cairo(),
                              prefixIcon: const Icon(Icons.sell_rounded),
                              suffixText: 'ر.س',
                            ),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 0) {
                                return 'سعر غير صالح';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // Live profit display
                    if (_purchasePriceCtrl.text.isNotEmpty &&
                        _salePriceCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (ctx) {
                        final purchase =
                            double.tryParse(_purchasePriceCtrl.text) ?? 0;
                        final sale = double.tryParse(_salePriceCtrl.text) ?? 0;
                        final profit = sale - purchase;
                        final margin =
                            purchase > 0 ? (profit / purchase * 100) : 0.0;
                        final isPositive = profit >= 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (isPositive
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الربح: ${profit.toStringAsFixed(2)} ر.س',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isPositive
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                              Text(
                                'الهامش: ${margin.toStringAsFixed(1)}%',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: isPositive
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Supplier & warranty ───────────────────────────────────────
              _FormSection(
                title: 'المورد والضمان',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _supplierId,
                      decoration: InputDecoration(
                        labelText: 'المورد',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.local_shipping_rounded),
                      ),
                      hint: Text('اختر مورداً', style: GoogleFonts.cairo()),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('بدون مورد', style: GoogleFonts.cairo()),
                        ),
                        ..._suppliers.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, style: GoogleFonts.cairo()),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _supplierId = v),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _warrantyDaysCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'ضمان المنتج (أيام)',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.verified_user_rounded),
                        suffixText: 'يوم',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CatDef {
  final String key;
  final String label;
  const _CatDef(this.key, this.label);
}
