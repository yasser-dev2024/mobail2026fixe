import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../data/warranty_model.dart';
import '../cubit/warranty_cubit.dart';

class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key});

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final WarrantyCubit _cubit;
  _DurationFilter _durationFilter = _DurationFilter.all;

  static const _tabs = [
    _TabDef('الكل', null),
    _TabDef('ساري', 'active'),
    _TabDef('ينتهي قريباً', 'expiring'),
    _TabDef('منتهي', 'expired'),
  ];

  @override
  void initState() {
    super.initState();
    _cubit = WarrantyCubit()..loadAll();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _cubit.loadAll(status: _tabs[_tabController.index].status);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: colors.background,
        body: BlocBuilder<WarrantyCubit, WarrantyState>(
          builder: (context, state) {
            final stats =
                state is WarrantyLoaded ? state.stats : <String, dynamic>{};

            return Column(
              children: [
                // ── Stats cards ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(
                        label: 'ساري',
                        value: '${stats['active'] ?? 0}',
                        color: AppColors.warrantyActive,
                        icon: Icons.verified_user_rounded,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'ينتهي قريباً',
                        value: '${stats['expiringSoon'] ?? 0}',
                        color: AppColors.warrantyExpiringSoon,
                        icon: Icons.timer_rounded,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'منتهي',
                        value: '${stats['expired'] ?? 0}',
                        color: AppColors.warrantyExpired,
                        icon: Icons.cancel_rounded,
                      ),
                    ],
                  ),
                ),

                // ── Tabs ───────────────────────────────────────────────────────
                Container(
                  color: colors.surface,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: GoogleFonts.cairo(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
                    tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
                  ),
                ),

                // ── List ───────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<_DurationFilter>(
                      segments: const [
                        ButtonSegment(
                          value: _DurationFilter.all,
                          icon: Icon(Icons.verified_user_rounded),
                          label: Text('كل الضمانات'),
                        ),
                        ButtonSegment(
                          value: _DurationFilter.short,
                          icon: Icon(Icons.bolt_rounded),
                          label: Text('الضمانات القصيرة'),
                        ),
                        ButtonSegment(
                          value: _DurationFilter.long,
                          icon: Icon(Icons.calendar_month_rounded),
                          label: Text('الضمانات الطويلة'),
                        ),
                      ],
                      selected: {_durationFilter},
                      onSelectionChanged: (selection) {
                        setState(() => _durationFilter = selection.first);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _buildContent(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WarrantyState state) {
    if (state is WarrantyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is WarrantyError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(state.message,
                style: GoogleFonts.cairo(fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<WarrantyCubit>().loadAll(),
              child: Text('إعادة المحاولة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    if (state is WarrantyLoaded) {
      final items = _filterByDuration(state.items);
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 72,
                  color:
                      context.appColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('لا توجد ضمانات',
                  style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textSecondary)),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        itemBuilder: (context, index) => _WarrantyCard(warranty: items[index]),
      );
    }
    return const SizedBox.shrink();
  }

  List<WarrantyModel> _filterByDuration(List<WarrantyModel> items) {
    switch (_durationFilter) {
      case _DurationFilter.short:
        return items
            .where((item) =>
                item.warrantyDays <= AppConstants.longWarrantyThresholdDays)
            .toList();
      case _DurationFilter.long:
        return items.where((item) => item.isLongWarranty).toList();
      case _DurationFilter.all:
        return items;
    }
  }
}

enum _DurationFilter { all, short, long }

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Warranty card
// ─────────────────────────────────────────────────────────────────────────────

class _WarrantyCard extends StatelessWidget {
  final WarrantyModel warranty;
  const _WarrantyCard({required this.warranty});

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return AppColors.warrantyActive;
      case 'expiring':
        return AppColors.warrantyExpiringSoon;
      default:
        return AppColors.warrantyExpired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _statusColor(warranty.status);
    final startDate = DateTime.fromMillisecondsSinceEpoch(warranty.startDate);
    final endDate = DateTime.fromMillisecondsSinceEpoch(warranty.endDate);
    final remainingLabel = _remainingLabel(endDate, warranty.isVoid);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to the maintenance detail
          context.go('/maintenance/${warranty.maintenanceId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  if (warranty.ticketNumber != null)
                    Text(
                      warranty.ticketNumber!,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      warranty.statusLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Customer name
              Text(
                warranty.customerName ?? 'عميل غير محدد',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // Device info
              Text(
                warranty.deviceInfo,
                style: GoogleFonts.cairo(
                    fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),
              if (warranty.expiryApproved) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'انتهى الضمان - تاريخ الانتهاء: ${_dualDate(endDate)} - تاريخ الاعتماد: ${warranty.expiryApprovedAt == null ? 'غير محدد' : _dualDate(DateTime.fromMillisecondsSinceEpoch(warranty.expiryApprovedAt!))}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DatePill(
                    icon: Icons.play_arrow_rounded,
                    label: 'البداية',
                    value: _dualDate(startDate),
                  ),
                  _DatePill(
                    icon: Icons.flag_rounded,
                    label: 'النهاية',
                    value: _dualDate(endDate),
                  ),
                  _DatePill(
                    icon: Icons.verified_user_rounded,
                    label: 'المدة',
                    value: '${warranty.warrantyDays} يوم',
                  ),
                  _DatePill(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'المتبقي',
                    value: remainingLabel,
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dualDate(DateTime date) {
    final gregorian = DateFormat('yyyy/MM/dd', 'ar').format(date);
    final hijri = HijriDate.fromGregorian(date).format();
    return 'م $gregorian | هـ $hijri';
  }

  String _remainingLabel(DateTime endDate, bool isVoid) {
    if (isVoid) return 'ملغي';
    final today = DateTime.now();
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = endDay.difference(todayDay).inDays;
    if (days > 0) return '$days يوم';
    if (days == 0) return 'ينتهي اليوم';
    return 'منتهي منذ ${days.abs()} يوم';
  }
}

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _DatePill({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final String? status;
  const _TabDef(this.label, this.status);
}
