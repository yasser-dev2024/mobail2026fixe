import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../accounting/data/accounting_repository.dart';
import '../../../customers/data/customer_model.dart';
import '../../../customers/data/customers_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../maintenance/data/maintenance_repository.dart';
import '../../../sales/data/sales_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _accountingRepo = AccountingRepository();
  final _salesRepo = SalesRepository();
  final _inventoryRepo = InventoryRepository();
  final _customersRepo = CustomersRepository();
  final _maintenanceRepo = MaintenanceRepository();

  Map<String, dynamic> _financial = {};
  Map<String, dynamic> _todayFinancial = {};
  Map<String, dynamic> _todaySales = {};
  Map<String, dynamic> _inventory = {};
  Map<String, dynamic> _customers = {};
  List<CustomerModel> _topCustomers = [];
  List<Map<String, dynamic>> _monthly = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    await _maintenanceRepo.syncAllFinancials();
    final results = await Future.wait([
      _accountingRepo.getSummary(from: monthStart, to: now),
      _accountingRepo.getDailySummary(now),
      _salesRepo.getTodayStats(),
      _inventoryRepo.getStats(),
      _customersRepo.getStats(),
      _customersRepo.getTopCustomers(5),
      _accountingRepo.getMonthlyReport(now.year, now.month),
    ]);
    if (!mounted) return;
    setState(() {
      _financial = results[0] as Map<String, dynamic>;
      _todayFinancial = results[1] as Map<String, dynamic>;
      _todaySales = results[2] as Map<String, dynamic>;
      _inventory = results[3] as Map<String, dynamic>;
      _customers = results[4] as Map<String, dynamic>;
      _topCustomers = results[5] as List<CustomerModel>;
      _monthly = results[6] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final money = NumberFormat('#,##0.00', 'ar');
    return Scaffold(
      backgroundColor: colors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'إيرادات الشهر',
                          value:
                              '${money.format(_num(_financial['total_income']))} ر.س',
                          icon: Icons.payments_rounded,
                          gradient: AppColors.successGradient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'أرباح اليوم',
                          value:
                              '${money.format(_num(_todayFinancial['net_profit']))} ر.س',
                          icon: Icons.trending_up_rounded,
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'قيمة المخزون',
                          value:
                              '${money.format(_num(_inventory['totalValue']))} ر.س',
                          icon: Icons.inventory_2_rounded,
                          gradient: AppColors.tealGradient,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSummaryCard(money)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTopCustomers(money)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMonthlyTable(money),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(NumberFormat money) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ملخص سريع'),
          const SizedBox(height: 12),
          InfoRow(
              label: 'مبيعات اليوم',
              value: '${_todaySales['totalSales'] ?? 0} فاتورة'),
          InfoRow(
              label: 'إيرادات اليوم',
              value:
                  '${money.format(_num(_todayFinancial['total_income']))} ر.س'),
          InfoRow(
              label: 'إجمالي المنتجات',
              value: '${_inventory['totalProducts'] ?? 0}'),
          InfoRow(
              label: 'منخفض المخزون', value: '${_inventory['lowStock'] ?? 0}'),
          InfoRow(
              label: 'نفد المخزون', value: '${_inventory['outOfStock'] ?? 0}'),
          InfoRow(
              label: 'إجمالي العملاء', value: '${_customers['total'] ?? 0}'),
          InfoRow(label: 'عملاء VIP', value: '${_customers['vip'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildTopCustomers(NumberFormat money) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'أفضل العملاء'),
          const SizedBox(height: 12),
          if (_topCustomers.isEmpty)
            const EmptyState(
                message: 'لا توجد بيانات عملاء',
                icon: Icons.people_outline_rounded)
          else
            ..._topCustomers.map(
              (customer) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary),
                ),
                title: Text(customer.name),
                subtitle: Text(customer.phone),
                trailing: Text('${money.format(customer.totalSpent)} ر.س'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTable(NumberFormat money) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'تقرير الشهر اليومي'),
          const SizedBox(height: 12),
          if (_monthly.isEmpty)
            const EmptyState(
                message: 'لا توجد عمليات مالية هذا الشهر',
                icon: Icons.bar_chart_rounded)
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.4),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FlexColumnWidth(),
              },
              border: TableBorder(
                  horizontalInside:
                      BorderSide(color: context.appColors.border)),
              children: [
                _row(['التاريخ', 'الدخل', 'المصروف', 'الصافي'], header: true),
                ..._monthly.map(
                  (day) => _row([
                    '${day['date']}',
                    '${money.format(_num(day['income']))} ر.س',
                    '${money.format(_num(day['expense']))} ر.س',
                    '${money.format(_num(day['net']))} ر.س',
                  ]),
                ),
              ],
            ),
        ],
      ),
    );
  }

  TableRow _row(List<String> cells, {bool header = false}) {
    return TableRow(
      children: cells
          .map(
            (cell) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(
                cell,
                style: TextStyle(
                    fontWeight: header ? FontWeight.w800 : FontWeight.w500),
              ),
            ),
          )
          .toList(),
    );
  }

  double _num(Object? value) => (value as num?)?.toDouble() ?? 0;
}
