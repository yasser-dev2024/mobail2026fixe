import 'package:flutter/material.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _faults = [];
  List<Map<String, dynamic>> _deviceModels = [];
  List<Map<String, dynamic>> _deviceBrands = [];
  List<Map<String, dynamic>> _lowStock = [];
  List<Map<String, dynamic>> _repeatCustomers = [];
  List<Map<String, dynamic>> _technicians = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shopId = await _db.getCurrentShopId();
    final faults = await _db.rawQuery('''
      SELECT TRIM(fault_description) AS fault_description, COUNT(*) AS count
      FROM maintenance
      WHERE shop_id = ?
        AND deleted_at IS NULL
        AND TRIM(IFNULL(fault_description, '')) != ''
      GROUP BY LOWER(TRIM(fault_description))
      ORDER BY count DESC
      LIMIT 10
    ''', [shopId]);
    final deviceModels = await _db.rawQuery('''
      SELECT TRIM(brand) AS brand, TRIM(model) AS model, COUNT(*) AS count
      FROM maintenance
      WHERE shop_id = ?
        AND deleted_at IS NULL
        AND TRIM(IFNULL(brand, '')) != ''
        AND TRIM(IFNULL(model, '')) != ''
      GROUP BY LOWER(TRIM(brand)), LOWER(TRIM(model))
      ORDER BY count DESC
      LIMIT 10
    ''', [shopId]);
    final deviceBrands = await _db.rawQuery('''
      SELECT TRIM(brand) AS brand, COUNT(*) AS count
      FROM maintenance
      WHERE shop_id = ?
        AND deleted_at IS NULL
        AND TRIM(IFNULL(brand, '')) != ''
      GROUP BY LOWER(TRIM(brand))
      ORDER BY count DESC
      LIMIT 10
    ''', [shopId]);
    final lowStock = await _db.rawQuery('''
      SELECT name, quantity, low_stock_threshold
      FROM products
      WHERE deleted_at IS NULL
        AND is_active = 1
        AND is_service = 0
        AND quantity <= low_stock_threshold
      ORDER BY quantity ASC
      LIMIT 10
    ''');
    final repeatCustomers = await _db.rawQuery('''
      SELECT name, phone, visit_count, total_spent
      FROM customers
      WHERE shop_id = ? AND deleted_at IS NULL AND visit_count > 1
      ORDER BY visit_count DESC, total_spent DESC
      LIMIT 10
    ''', [shopId]);
    final technicians = await _db.rawQuery('''
      SELECT u.name, COUNT(m.id) AS ticket_count,
             SUM(CASE WHEN m.status = 'delivered' THEN 1 ELSE 0 END) AS delivered_count
      FROM users u
      LEFT JOIN maintenance m ON m.technician_id = u.id AND m.shop_id = ? AND m.deleted_at IS NULL
      WHERE u.deleted_at IS NULL AND u.role = 'technician'
      GROUP BY u.id, u.name
      ORDER BY ticket_count DESC
      LIMIT 10
    ''', [shopId]);
    if (!mounted) return;
    setState(() {
      _faults = faults;
      _deviceModels = deviceModels;
      _deviceBrands = deviceBrands;
      _lowStock = lowStock;
      _repeatCustomers = repeatCustomers;
      _technicians = technicians;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(
                    height: 158,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'أكثر عطل',
                            value: _faults.isEmpty
                                ? '0'
                                : '${_faults.first['count'] ?? 0}',
                            icon: Icons.psychology_rounded,
                            gradient: AppColors.primaryGradient,
                            subtitle: _faults.isEmpty
                                ? 'لا توجد بيانات'
                                : _faults.first['fault_description'] as String?,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'أكثر شركة',
                            value: _deviceBrands.isEmpty
                                ? '0'
                                : '${_deviceBrands.first['count'] ?? 0}',
                            icon: Icons.business_rounded,
                            gradient: AppColors.tealGradient,
                            subtitle: _deviceBrands.isEmpty
                                ? 'لا توجد بيانات'
                                : _deviceBrands.first['brand'] as String?,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'أكثر موديل',
                            value: _deviceModels.isEmpty
                                ? '0'
                                : '${_deviceModels.first['count'] ?? 0}',
                            icon: Icons.phone_android_rounded,
                            gradient: AppColors.infoGradient,
                            subtitle: _deviceModels.isEmpty
                                ? 'لا توجد بيانات'
                                : '${_deviceModels.first['brand'] ?? ''} ${_deviceModels.first['model'] ?? ''}'
                                    .trim(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'قطع حرجة',
                            value: '${_lowStock.length}',
                            icon: Icons.warning_rounded,
                            gradient: AppColors.warningGradient,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InsightCard(
                          title: 'الأعطال المتكررة',
                          empty: 'لا توجد أعطال متكررة حالياً',
                          rows: _faults
                              .map((row) => _InsightRow(
                                    title:
                                        row['fault_description'] as String? ??
                                            '',
                                    value: '${row['count'] ?? 0} مرات',
                                    icon: Icons.build_rounded,
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InsightCard(
                          title: 'المخزون المتوقع نفاده',
                          empty: 'المخزون بحالة جيدة',
                          rows: _lowStock
                              .map((row) => _InsightRow(
                                    title: row['name'] as String? ?? '',
                                    value: '${row['quantity'] ?? 0} متبقي',
                                    icon: Icons.inventory_2_rounded,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InsightCard(
                          title: 'أكثر الأجهزة صيانة',
                          empty: 'لا توجد بيانات أجهزة كافية',
                          rows: _deviceModels
                              .map((row) => _InsightRow(
                                    title:
                                        '${row['brand'] ?? ''} ${row['model'] ?? ''}'
                                            .trim(),
                                    value: '${row['count'] ?? 0} مرات',
                                    icon: Icons.phone_android_rounded,
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InsightCard(
                          title: 'أكثر الشركات صيانة',
                          empty: 'لا توجد بيانات شركات كافية',
                          rows: _deviceBrands
                              .map((row) => _InsightRow(
                                    title: row['brand'] as String? ?? '',
                                    value: '${row['count'] ?? 0} مرات',
                                    icon: Icons.business_rounded,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InsightCard(
                          title: 'العملاء المتكررون',
                          empty: 'لا توجد زيارات متكررة بعد',
                          rows: _repeatCustomers
                              .map((row) => _InsightRow(
                                    title: row['name'] as String? ?? '',
                                    value: '${row['visit_count'] ?? 0} زيارات',
                                    icon: Icons.person_rounded,
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InsightCard(
                          title: 'أداء الفنيين',
                          empty: 'لا توجد بيانات فنيين',
                          rows: _technicians
                              .map((row) => _InsightRow(
                                    title: row['name'] as String? ?? '',
                                    value:
                                        '${row['delivered_count'] ?? 0}/${row['ticket_count'] ?? 0} منجزة',
                                    icon: Icons.engineering_rounded,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String empty;
  final List<_InsightRow> rows;

  const _InsightCard({
    required this.title,
    required this.empty,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            EmptyState(message: empty, icon: Icons.insights_rounded)
          else
            ...rows.map(
              (row) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: Icon(row.icon, color: AppColors.primary),
                ),
                title: Text(row.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(row.value,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightRow {
  final String title;
  final String value;
  final IconData icon;

  const _InsightRow({
    required this.title,
    required this.value,
    required this.icon,
  });
}
