import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/purchase_model.dart';
import '../cubit/purchases_cubit.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late final PurchasesCubit _cubit;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _cubit = PurchasesCubit()..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<PurchasesCubit, PurchasesState>(
        listener: (context, state) {
          if (state is PurchasesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          final purchases =
              state is PurchasesLoaded ? state.purchases : <PurchaseModel>[];
          final stats =
              state is PurchasesLoaded ? state.stats : <String, dynamic>{};
          return Scaffold(
            backgroundColor: context.appColors.background,
            body: Column(
              children: [
                _buildHeader(context, stats),
                _buildFilters(context),
                Expanded(
                  child: state is PurchasesLoading
                      ? const Center(child: CircularProgressIndicator())
                      : purchases.isEmpty
                          ? _buildEmpty()
                          : _buildList(context, purchases),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.go('/purchases/new'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('فاتورة جديدة',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> stats) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    final total = (stats['total'] as num?)?.toDouble() ?? 0.0;
    final count = (stats['count'] as int?) ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_cart_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المشتريات',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text('إجمالي الشهر الحالي',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(context, 'إجمالي المشتريات',
                    '${fmt.format(total)} ر.س', Icons.paid_rounded),
                _statItem(context, 'عدد الفواتير', '$count فاتورة',
                    Icons.receipt_long_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      BuildContext context, String label, String value, IconData icon) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 20),
      const SizedBox(height: 4),
      Text(value,
          style: GoogleFonts.cairo(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label,
          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
    ]);
  }

  Widget _buildFilters(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: Text(
                _from != null ? 'من: ${fmt.format(_from!)}' : 'من تاريخ',
                style: GoogleFonts.cairo(fontSize: 13),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _from ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() => _from = d);
                  _cubit.load(from: _from, to: _to);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: Text(
                _to != null ? 'إلى: ${fmt.format(_to!)}' : 'إلى تاريخ',
                style: GoogleFonts.cairo(fontSize: 13),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _to ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() => _to = d);
                  _cubit.load(from: _from, to: _to);
                }
              },
            ),
          ),
          if (_from != null || _to != null)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.error),
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                _cubit.load();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<PurchaseModel> purchases) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: purchases.length,
      itemBuilder: (context, i) => _PurchaseCard(purchase: purchases[i]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shopping_cart_outlined,
            size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('لا توجد فواتير مشتريات',
            style: GoogleFonts.cairo(
                fontSize: 18, color: AppColors.primary.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Text('اضغط على الزر أدناه لإضافة فاتورة جديدة',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey)),
      ]),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseModel purchase;
  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fmt = NumberFormat('#,##0.00', 'ar');
    final dateFmt = DateFormat('dd/MM/yyyy', 'ar');
    final date = DateTime.fromMillisecondsSinceEpoch(purchase.createdAt);

    Color methodColor;
    String methodLabel;
    switch (purchase.paymentMethod) {
      case 'card':
        methodColor = AppColors.info;
        methodLabel = 'شبكة';
        break;
      case 'transfer':
        methodColor = AppColors.secondary;
        methodLabel = 'تحويل';
        break;
      case 'credit':
        methodColor = AppColors.warning;
        methodLabel = 'آجل';
        break;
      default:
        methodColor = AppColors.success;
        methodLabel = 'نقدي';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(purchase.invoiceNumber,
                        style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(purchase.supplierName ?? 'بدون مورد',
                        style: GoogleFonts.cairo(
                            fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(dateFmt.format(date),
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: colors.textSecondary)),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${fmt.format(purchase.total)} ر.س',
                  style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(methodLabel,
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: methodColor)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
