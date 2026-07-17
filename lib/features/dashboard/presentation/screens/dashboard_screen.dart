import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../maintenance/data/maintenance_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  final _maintenanceRepo = MaintenanceRepository();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentMaintenance = [];
  List<FlSpot> _revenueSpots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await _maintenanceRepo.syncAllFinancials();
      final shopId = await _db.getCurrentShopId();
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      // Today's financial income includes sales and maintenance.
      final todayFinancial = await _db.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total,
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) as profit
        FROM transactions
        WHERE transaction_date >= ? AND deleted_at IS NULL
      ''', [todayStart]);

      // Maintenance stats
      final mainStats = await _db.rawQuery('''
        SELECT
          SUM(CASE WHEN status NOT IN ('delivered','cancelled','abandoned') AND deleted_at IS NULL THEN 1 ELSE 0 END) as active,
          SUM(CASE WHEN status = 'ready' AND deleted_at IS NULL THEN 1 ELSE 0 END) as ready,
          SUM(CASE WHEN status = 'delivered' AND delivered_at >= ? AND deleted_at IS NULL THEN 1 ELSE 0 END) as today_delivered
        FROM maintenance
        WHERE shop_id = ?
      ''', [todayStart, shopId]);

      // Warranty stats
      final warrantyStats = await _db.rawQuery('''
        SELECT
          SUM(CASE WHEN end_date >= ? AND is_void=0 THEN 1 ELSE 0 END) as active,
          SUM(CASE WHEN end_date < ? AND is_void=0 THEN 1 ELSE 0 END) as expired
        FROM warranties
        WHERE shop_id = ?
      ''', [now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, shopId]);

      // Low stock
      final lowStock = await _db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE quantity > 0 AND quantity <= low_stock_threshold AND deleted_at IS NULL AND is_active = 1',
      );

      // VIP customers
      final vipCount = await _db.rawQuery(
        "SELECT COUNT(*) as cnt FROM customers WHERE shop_id = ? AND (total_spent > 5000 OR visit_count > 10) AND deleted_at IS NULL",
        [shopId],
      );

      // Unread notifications
      final unread = await _db.rawQuery(
        'SELECT COUNT(*) as cnt FROM notifications WHERE shop_id = ? AND is_read = 0',
        [shopId],
      );

      // Revenue last 7 days
      final spots = <FlSpot>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayStart =
            DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
        final dayEnd = dayStart + 86400000;
        final rev = await _db.rawQuery(
          '''
          SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as v
          FROM transactions
          WHERE transaction_date >= ?
            AND transaction_date < ?
            AND deleted_at IS NULL
          ''',
          [dayStart, dayEnd],
        );
        spots.add(
            FlSpot((6 - i).toDouble(), (rev.first['v'] as num).toDouble()));
      }

      // Recent maintenance (last 8)
      final recent = await _db.rawQuery('''
        SELECT m.id, m.ticket_number, m.brand, m.model, m.status, m.total_cost,
               c.name as customer_name, m.created_at
        FROM maintenance m
        LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
        WHERE m.shop_id = ? AND m.deleted_at IS NULL
        ORDER BY m.created_at DESC LIMIT 8
      ''', [shopId]);

      setState(() {
        _stats = {
          'todaySales':
              (todayFinancial.first['total'] as num?)?.toDouble() ?? 0.0,
          'todayProfit':
              (todayFinancial.first['profit'] as num?)?.toDouble() ?? 0.0,
          'activeRepairs': mainStats.first['active'] ?? 0,
          'readyForDelivery': mainStats.first['ready'] ?? 0,
          'todayDelivered': mainStats.first['today_delivered'] ?? 0,
          'warrantyActive': warrantyStats.first['active'] ?? 0,
          'warrantyExpired': warrantyStats.first['expired'] ?? 0,
          'lowStock': lowStock.first['cnt'] ?? 0,
          'vipCustomers': vipCount.first['cnt'] ?? 0,
          'unreadNotifications': unread.first['cnt'] ?? 0,
        };
        _recentMaintenance = recent;
        _revenueSpots = spots;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const currency = 'ر.س';

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة التحكم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      AppFormatters.date(DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                  ],
                );
                final refresh = ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('تحديث', style: GoogleFonts.cairo()),
                );

                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: refresh,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    refresh,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Top stats row
            _ResponsiveStatsGrid(
              children: [
                StatCard(
                  title: 'مبيعات اليوم',
                  value: AppFormatters.currency(_stats['todaySales'] ?? 0,
                      symbol: currency),
                  icon: Icons.trending_up_rounded,
                  gradient: AppColors.primaryGradient,
                  onTap: () => context.go('/sales'),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                StatCard(
                  title: 'أرباح اليوم',
                  value: AppFormatters.currency(_stats['todayProfit'] ?? 0,
                      symbol: currency),
                  icon: Icons.account_balance_wallet_rounded,
                  gradient: AppColors.successGradient,
                  onTap: () => context.go('/accounting'),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 80.ms)
                    .slideY(begin: 0.2),
                StatCard(
                  title: 'تحت الصيانة',
                  value: '${_stats['activeRepairs'] ?? 0}',
                  icon: Icons.build_rounded,
                  gradient: AppColors.warningGradient,
                  onTap: () => context.go('/maintenance'),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 160.ms)
                    .slideY(begin: 0.2),
                StatCard(
                  title: 'جاهزة للتسليم',
                  value: '${_stats['readyForDelivery'] ?? 0}',
                  icon: Icons.check_circle_rounded,
                  gradient: AppColors.tealGradient,
                  onTap: () => context.go('/maintenance'),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 240.ms)
                    .slideY(begin: 0.2),
              ],
            ),
            const SizedBox(height: 16),
            _ResponsiveStatsGrid(
              children: [
                StatCard(
                  title: 'ضمانات سارية',
                  value: '${_stats['warrantyActive'] ?? 0}',
                  icon: Icons.verified_user_rounded,
                  gradient: AppColors.infoGradient,
                  onTap: () => context.go('/warranty'),
                ).animate().fadeIn(duration: 400.ms, delay: 320.ms),
                StatCard(
                  title: 'ضمانات منتهية',
                  value: '${_stats['warrantyExpired'] ?? 0}',
                  icon: Icons.gpp_bad_rounded,
                  gradient: AppColors.errorGradient,
                  onTap: () => context.go('/warranty'),
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                StatCard(
                  title: 'مخزون منخفض',
                  value: '${_stats['lowStock'] ?? 0}',
                  icon: Icons.inventory_2_rounded,
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange, Colors.orange.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.go('/inventory'),
                ).animate().fadeIn(duration: 400.ms, delay: 480.ms),
                StatCard(
                  title: 'عملاء VIP',
                  value: '${_stats['vipCustomers'] ?? 0}',
                  icon: Icons.star_rounded,
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.yellow.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.go('/customers'),
                ).animate().fadeIn(duration: 400.ms, delay: 560.ms),
              ],
            ),
            const SizedBox(height: 24),

            // Content row
            LayoutBuilder(
              builder: (context, constraints) {
                final revenueCard = AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'الإيرادات - آخر 7 أيام'),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _RevenueChart(spots: _revenueSpots),
                      ),
                    ],
                  ),
                );
                final quickActions = AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجراءات سريعة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _QuickActionButton(
                        icon: Icons.build_rounded,
                        label: 'صيانة جديدة',
                        color: AppColors.warning,
                        onTap: () => context.go('/maintenance/new'),
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        icon: Icons.person_add_rounded,
                        label: 'عميل جديد',
                        color: AppColors.primary,
                        onTap: () => context.go('/customers/new'),
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        icon: Icons.receipt_rounded,
                        label: 'فاتورة بيع',
                        color: AppColors.success,
                        onTap: () => context.go('/sales/new'),
                      ),
                      const SizedBox(height: 10),
                      _QuickActionButton(
                        icon: Icons.search_rounded,
                        label: 'بحث شامل',
                        color: AppColors.info,
                        onTap: () => context.go('/search'),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      revenueCard,
                      const SizedBox(height: 16),
                      quickActions,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: revenueCard),
                    const SizedBox(width: 16),
                    SizedBox(width: 220, child: quickActions),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Recent maintenance
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: SectionHeader(title: 'آخر عمليات الصيانة'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.go('/maintenance'),
                        child: Text('عرض الكل',
                            style: GoogleFonts.cairo(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_recentMaintenance.isEmpty)
                    const EmptyState(
                      message: 'لا توجد عمليات صيانة',
                      icon: Icons.build_rounded,
                    )
                  else
                    ...(_recentMaintenance
                        .map((m) => _MaintenanceRow(data: m))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveStatsGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveStatsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 520
            ? 1
            : width < 820
                ? 2
                : width < 1120
                    ? 3
                    : 4;
        final aspectRatio = columns == 1
            ? 1.9
            : columns == 2
                ? 1.45
                : columns == 3
                    ? 1.5
                    : 1.6;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<FlSpot> spots;
  const _RevenueChart({required this.spots});

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const SizedBox();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final colors = context.appColors;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final day =
                    DateTime.now().subtract(Duration(days: 6 - val.toInt()));
                return Text(
                  '${day.day}/${day.month}',
                  style: GoogleFonts.cairo(
                      fontSize: 10, color: colors.textSecondary),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY > 0 ? maxY * 1.2 : 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: AppColors.primaryGradient,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(60),
                  AppColors.primary.withAlpha(0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MaintenanceRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = data['status'] as String? ?? '';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return InkWell(
      onTap: () => context.go('/maintenance/${data['id']}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['customer_name'] ?? 'عميل غير معروف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '${data['brand']} ${data['model']} - ${data['ticket_number']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: StatusBadge(label: statusLabel, color: statusColor),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 0,
              child: Text(
                AppFormatters.currency(
                    (data['total_cost'] as num?)?.toDouble() ?? 0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    return AppColors.maintenanceStatus(s);
  }

  String _statusLabel(String s) {
    return AppConstants.maintenanceStatusLabel(s);
  }
}
