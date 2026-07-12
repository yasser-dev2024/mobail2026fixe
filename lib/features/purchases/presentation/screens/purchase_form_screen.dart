import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/product_model.dart';
import '../../../suppliers/data/supplier_model.dart';
import '../../../suppliers/data/suppliers_repository.dart';
import '../../data/purchase_item_model.dart';
import '../../data/purchase_model.dart';
import '../../data/purchases_repository.dart';

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController(text: '0');

  final SuppliersRepository _suppliersRepo = SuppliersRepository();
  final InventoryRepository _inventoryRepo = InventoryRepository();
  final PurchasesRepository _purchasesRepo = PurchasesRepository();

  List<SupplierModel> _suppliers = [];
  List<ProductModel> _products = [];
  SupplierModel? _selectedSupplier;
  String _paymentMethod = 'cash';
  bool _loading = false;

  final List<_ItemRow> _items = [];
  String _invoiceNumber = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final suppliers = await _suppliersRepo.getAll();
    final products = await _inventoryRepo.getAll();
    final inv = await _purchasesRepo.generateInvoiceNumber();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _products = products;
        _invoiceNumber = inv;
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _shippingCtrl.dispose();
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, r) => s + (r.qty * r.unitPrice));
  double get _tax => double.tryParse(_taxCtrl.text) ?? 0;
  double get _shipping => double.tryParse(_shippingCtrl.text) ?? 0;
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => _subtotal + _tax + _shipping - _discount;
  double get _amountPaid => double.tryParse(_amountPaidCtrl.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fmt = NumberFormat('#,##0.00', 'ar');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('فاتورة شراء جديدة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/purchases'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text('حفظ',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left panel — items
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Invoice number
                  _sectionCard(
                    context,
                    'بيانات الفاتورة',
                    Column(children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _invoiceNumber,
                            readOnly: true,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                                labelText: 'رقم الفاتورة'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<SupplierModel>(
                            value: _selectedSupplier,
                            decoration:
                                const InputDecoration(labelText: 'المورد'),
                            items: _suppliers
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name,
                                          style: GoogleFonts.cairo()),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSupplier = v),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Product search
                  _sectionCard(
                    context,
                    'إضافة منتج',
                    _ProductSearchRow(
                      products: _products,
                      onAdd: (product, qty, price) {
                        setState(() {
                          final existing = _items
                              .indexWhere((r) => r.productId == product.id);
                          if (existing >= 0) {
                            _items[existing].qty += qty;
                          } else {
                            _items.add(_ItemRow(
                              productId: product.id,
                              productName: product.name,
                              qty: qty,
                              unitPrice: price,
                            ));
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Items list
                  if (_items.isNotEmpty)
                    _sectionCard(
                      context,
                      'المنتجات (${_items.length})',
                      Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Expanded(
                                  flex: 3,
                                  child: Text('المنتج',
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      textAlign: TextAlign.right)),
                              Expanded(
                                  child: Text('الكمية',
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      textAlign: TextAlign.center)),
                              Expanded(
                                  child: Text('السعر',
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      textAlign: TextAlign.center)),
                              Expanded(
                                  child: Text('الإجمالي',
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      textAlign: TextAlign.center)),
                              const SizedBox(width: 32),
                            ]),
                          ),
                          const Divider(height: 1),
                          ..._items.asMap().entries.map((e) => _ItemRowWidget(
                                row: e.value,
                                onRemove: () =>
                                    setState(() => _items.removeAt(e.key)),
                                onChanged: () => setState(() {}),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Right panel — totals + payment
            SizedBox(
              width: 300,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _sectionCard(
                    context,
                    'الملخص',
                    Column(children: [
                      _summaryRow(
                          'المجموع الفرعي', '${fmt.format(_subtotal)} ر.س'),
                      const SizedBox(height: 12),
                      _numField(_shippingCtrl, 'الشحن'),
                      const SizedBox(height: 8),
                      _numField(_discountCtrl, 'الخصم'),
                      const SizedBox(height: 8),
                      _numField(_taxCtrl, 'الضريبة'),
                      const Divider(height: 24),
                      _summaryRow(
                        'الإجمالي',
                        '${fmt.format(_total)} ر.س',
                        bold: true,
                        color: AppColors.primary,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    'طريقة الدفع',
                    Column(children: [
                      _paymentButton('cash', 'نقدي', Icons.payments_rounded),
                      const SizedBox(height: 8),
                      _paymentButton('card', 'شبكة', Icons.credit_card_rounded),
                      const SizedBox(height: 8),
                      _paymentButton(
                          'transfer', 'تحويل', Icons.account_balance_rounded),
                      const SizedBox(height: 8),
                      _paymentButton('credit', 'آجل', Icons.schedule_rounded),
                      const SizedBox(height: 12),
                      _numField(_amountPaidCtrl, 'المبلغ المدفوع'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    'ملاحظات',
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                          hintText: 'ملاحظات اختيارية...'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style:
                  GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
              textAlign: TextAlign.right),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color)),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      ]),
    );
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _paymentButton(String method, String label, IconData icon) {
    final selected = _paymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = method),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : context.appColors.border,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color: selected ? Colors.white : context.appColors.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : context.appColors.textSecondary,
              )),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('أضف منتجاً واحداً على الأقل'),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final purchase = PurchaseModel.create(
        invoiceNumber: _invoiceNumber,
        supplierId: _selectedSupplier?.id,
        supplierName: _selectedSupplier?.name,
        subtotal: _subtotal,
        tax: _tax,
        shipping: _shipping,
        discount: _discount,
        total: _total,
        amountPaid: _amountPaid,
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      final items = _items
          .map((r) => PurchaseItemModel.create(
                purchaseId: purchase.id,
                productId: r.productId,
                productName: r.productName,
                quantity: r.qty,
                unitPrice: r.unitPrice,
                totalPrice: r.qty * r.unitPrice,
              ))
          .toList();

      await _purchasesRepo.create(purchase, items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الفاتورة بنجاح'),
              backgroundColor: AppColors.success),
        );
        context.go('/purchases');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Product search row widget
// ---------------------------------------------------------------------------

class _ProductSearchRow extends StatefulWidget {
  final List<ProductModel> products;
  final void Function(ProductModel, int, double) onAdd;

  const _ProductSearchRow({required this.products, required this.onAdd});

  @override
  State<_ProductSearchRow> createState() => _ProductSearchRowState();
}

class _ProductSearchRowState extends State<_ProductSearchRow> {
  final _productCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  ProductModel? _selected;

  @override
  void dispose() {
    _productCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Autocomplete<ProductModel>(
        optionsBuilder: (v) {
          if (v.text.isEmpty) return const [];
          return widget.products.where(
            (p) =>
                p.name.toLowerCase().contains(v.text.toLowerCase()) ||
                (p.barcode?.contains(v.text) ?? false),
          );
        },
        displayStringForOption: (p) => p.name,
        onSelected: (p) {
          setState(() {
            _selected = p;
            _priceCtrl.text = p.purchasePrice.toString();
          });
        },
        fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
          return TextFormField(
            controller: ctrl,
            focusNode: fn,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'ابحث عن منتج...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          );
        },
        optionsViewBuilder: (ctx, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 300,
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: options
                      .map((p) => ListTile(
                            title: Text(p.name, style: GoogleFonts.cairo()),
                            subtitle: Text(
                                '${p.purchasePrice} ر.س | مخزون: ${p.quantity}',
                                style: GoogleFonts.cairo(fontSize: 12)),
                            onTap: () => onSelected(p),
                          ))
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'الكمية'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'سعر الشراء'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            if (_selected == null) return;
            final qty = int.tryParse(_qtyCtrl.text) ?? 1;
            final price = double.tryParse(_priceCtrl.text) ?? 0;
            widget.onAdd(_selected!, qty, price);
            _productCtrl.clear();
            _qtyCtrl.text = '1';
            _priceCtrl.clear();
            setState(() => _selected = null);
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('إضافة', style: GoogleFonts.cairo(color: Colors.white)),
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Item row data + widget
// ---------------------------------------------------------------------------

class _ItemRow {
  final String? productId;
  final String productName;
  int qty;
  double unitPrice;

  _ItemRow({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
  });
}

class _ItemRowWidget extends StatefulWidget {
  final _ItemRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRowWidget(
      {required this.row, required this.onRemove, required this.onChanged});

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.row.qty.toString());
    _priceCtrl = TextEditingController(text: widget.row.unitPrice.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(widget.row.productName,
              style: GoogleFonts.cairo(fontSize: 13),
              textAlign: TextAlign.right),
        ),
        Expanded(
          child: TextFormField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              widget.row.qty = int.tryParse(v) ?? 1;
              widget.onChanged();
            },
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            onChanged: (v) {
              widget.row.unitPrice = double.tryParse(v) ?? 0;
              widget.onChanged();
            },
          ),
        ),
        Expanded(
          child: Text(
            fmt.format(widget.row.qty * widget.row.unitPrice),
            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_rounded,
              color: AppColors.error, size: 18),
          onPressed: widget.onRemove,
        ),
      ]),
    );
  }
}
