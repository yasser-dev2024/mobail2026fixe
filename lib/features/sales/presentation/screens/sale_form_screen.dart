import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../customers/data/customer_model.dart';
import '../../../customers/data/customers_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/product_model.dart';
import '../../data/sale_item_model.dart';
import '../../data/sale_model.dart';
import '../../data/sales_repository.dart';

class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _salesRepo = SalesRepository();
  final _customersRepo = CustomersRepository();
  final _inventoryRepo = InventoryRepository();
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  List<CustomerModel> _customers = [];
  List<ProductModel> _products = [];
  final List<_SaleLine> _lines = [];
  CustomerModel? _selectedCustomer;
  ProductModel? _selectedProduct;
  String _invoiceNumber = '';
  String _paymentMethod = 'cash';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _discountCtrl.addListener(() => setState(() {}));
    _taxCtrl.addListener(() => setState(() {}));
    _paidCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final invoice = await _salesRepo.generateInvoiceNumber();
    final customers = await _customersRepo.getAll();
    final products = await _inventoryRepo.getAll();
    if (!mounted) return;
    setState(() {
      _invoiceNumber = invoice;
      _customers = customers;
      _products = products;
      _selectedProduct = products.isEmpty ? null : products.first;
      _loading = false;
    });
  }

  double get _subtotal => _lines.fold(0, (sum, line) => sum + line.total);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _tax => double.tryParse(_taxCtrl.text) ?? 0;
  double get _total => math.max(0, _subtotal - _discount + _tax);
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _change => math.max(0, _paid - _total);

  void _addLine() {
    final product = _selectedProduct;
    if (product == null) return;
    final qty = math.max(1, int.tryParse(_qtyCtrl.text) ?? 1);
    if (!product.isService && qty > product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('الكمية المتاحة من ${product.name}: ${product.quantity}'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final currentIndex =
        _lines.indexWhere((line) => line.product.id == product.id);
    setState(() {
      if (currentIndex >= 0) {
        final current = _lines[currentIndex];
        _lines[currentIndex] =
            current.copyWith(quantity: current.quantity + qty);
      } else {
        _lines.add(_SaleLine(product: product, quantity: qty));
      }
      _paidCtrl.text = _total.toStringAsFixed(2);
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجاً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final sale = SaleModel.create(
        invoiceNumber: _invoiceNumber,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        amountPaid: _paid,
        changeAmount: _change,
        paymentMethod: _paymentMethod,
        isCredit: _paymentMethod == 'credit' || _paid < _total,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdBy: 'admin',
      );
      final items = _lines
          .map(
            (line) => SaleItemModel.create(
              saleId: sale.id,
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.salePrice,
              totalPrice: line.total,
            ),
          )
          .toList();

      await _salesRepo.create(sale, items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الفاتورة بنجاح')),
      );
      context.go('/sales');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ الفاتورة: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final money = NumberFormat('#,##0.00', 'ar');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('فاتورة بيع $_invoiceNumber'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/sales'),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildInvoiceForm(money)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTotals(money)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildItemsTable(money),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('حفظ الفاتورة'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _saving ? null : () => context.go('/sales'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInvoiceForm(NumberFormat money) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'بيانات الفاتورة',
            trailing: Text(_invoiceNumber,
                style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<CustomerModel?>(
            value: _selectedCustomer,
            decoration: const InputDecoration(labelText: 'العميل'),
            items: [
              const DropdownMenuItem<CustomerModel?>(
                value: null,
                child: Text('عميل نقدي'),
              ),
              ..._customers.map(
                (customer) => DropdownMenuItem<CustomerModel?>(
                  value: customer,
                  child: Text('${customer.name} - ${customer.phone}'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedCustomer = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ProductModel>(
                  value: _selectedProduct,
                  decoration: const InputDecoration(labelText: 'المنتج'),
                  items: _products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product,
                          child: Text(
                            '${product.name} - ${money.format(product.salePrice)} ر.س',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedProduct = value),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _products.isEmpty ? null : _addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الخصم'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الضريبة'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _paidCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المدفوع'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(labelText: 'طريقة الدفع'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقدي')),
              DropdownMenuItem(value: 'card', child: Text('شبكة')),
              DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
              DropdownMenuItem(value: 'credit', child: Text('آجل')),
            ],
            onChanged: (value) =>
                setState(() => _paymentMethod = value ?? 'cash'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(NumberFormat money) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ملخص الدفع'),
          const SizedBox(height: 16),
          InfoRow(
              label: 'الإجمالي الفرعي',
              value: '${money.format(_subtotal)} ر.س'),
          InfoRow(label: 'الخصم', value: '${money.format(_discount)} ر.س'),
          InfoRow(label: 'الضريبة', value: '${money.format(_tax)} ر.س'),
          const Divider(),
          InfoRow(
            label: 'الإجمالي',
            value: '${money.format(_total)} ر.س',
            valueColor: AppColors.primary,
          ),
          InfoRow(label: 'المدفوع', value: '${money.format(_paid)} ر.س'),
          InfoRow(
            label: 'الباقي/المرتجع',
            value:
                '${money.format(_paymentMethod == 'credit' ? _total - _paid : _change)} ر.س',
            valueColor: _paymentMethod == 'credit' || _paid < _total
                ? AppColors.warning
                : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(NumberFormat money) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الأصناف'),
          const SizedBox(height: 12),
          if (_lines.isEmpty)
            const EmptyState(
              message: 'لم تتم إضافة أصناف بعد',
              icon: Icons.receipt_long_outlined,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final line = _lines[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary),
                  title: Text(line.product.name),
                  subtitle: Text(
                    'الكمية: ${line.quantity} | سعر الوحدة: ${money.format(line.product.salePrice)} ر.س',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${money.format(line.total)} ر.س',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _lines.removeAt(index)),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SaleLine {
  final ProductModel product;
  final int quantity;

  const _SaleLine({required this.product, required this.quantity});

  double get total => product.salePrice * quantity;

  _SaleLine copyWith({int? quantity}) {
    return _SaleLine(product: product, quantity: quantity ?? this.quantity);
  }
}
