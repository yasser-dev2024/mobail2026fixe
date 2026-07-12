import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/sale_model.dart';
import '../cubit/sales_cubit.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final SalesCubit _cubit;
  DateTime? _from;
  DateTime? _to;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = SalesCubit()..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<SalesCubit, SalesState>(
        listener: (context, state) {
          if (state is SalesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          final sales = state is SalesLoaded ? state.sales : <SaleModel>[];
          final stats =
              state is SalesLoaded ? state.stats : <String, dynamic>{};
          return Scaffold(
            backgroundColor: context.appColors.background,
            body: Column(
              children: [
                _buildStats(context, stats),
                _buildFilters(context),
                Expanded(
                  child: state is SalesLoading
                      ? const Center(child: CircularProgressIndicator())
                      : sales.isEmpty
                          ? _buildEmpty()
                          : _buildList(context, sales),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.go('/sales/new'),
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

  Widget _buildStats(BuildContext context, Map<String, dynamic> stats) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    final revenue = (stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final profit = (stats['totalProfit'] as num?)?.toDouble() ?? 0.0;
    final count = (stats['count'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.tealGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('المبيعات',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('إحصائيات اليوم',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _statCard(context, 'مبيعات اليوم', '$count طلب',
                    AppColors.primary, Icons.shopping_bag_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard(
                    context,
                    'إيرادات اليوم',
                    '${fmt.format(revenue)} ر.س',
                    AppColors.secondary,
                    Icons.paid_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard(
                    context,
                    'أرباح اليوم',
                    '${fmt.format(profit)} ر.س',
                    AppColors.success,
                    Icons.trending_up_rounded)),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
        ]),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12, color: context.appColors.textSecondary)),
      ]),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
                _from != null ? 'من: ${fmt.format(_from!)}' : 'من تاريخ',
                style: GoogleFonts.cairo(fontSize: 13)),
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
            label: Text(_to != null ? 'إلى: ${fmt.format(_to!)}' : 'إلى تاريخ',
                style: GoogleFonts.cairo(fontSize: 13)),
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
      ]),
    );
  }

  Widget _buildList(BuildContext context, List<SaleModel> sales) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: sales.length,
      itemBuilder: (context, i) => _SaleCard(sale: sales[i]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined,
            size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('لا توجد مبيعات',
            style: GoogleFonts.cairo(
                fontSize: 18, color: AppColors.primary.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Text('اضغط على الزر أدناه لإضافة فاتورة',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey)),
      ]),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final SaleModel sale;
  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fmt = NumberFormat('#,##0.00', 'ar');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    final date = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);

    Color methodColor;
    String methodLabel;
    switch (sale.paymentMethod) {
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
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sale.invoiceNumber,
                  style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 2),
              Text(sale.customerName ?? 'عميل نقدي',
                  style: GoogleFonts.cairo(
                      fontSize: 13, color: colors.textSecondary)),
              const SizedBox(height: 2),
              Text(dateFmt.format(date),
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: colors.textSecondary)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmt.format(sale.total)} ر.س',
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
        ]),
      ),
    );
  }
}
