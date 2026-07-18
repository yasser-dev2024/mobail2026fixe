import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/maintenance_model.dart';
import '../cubit/maintenance_cubit.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _tabs = [
    _TabDef('الكل', null),
    _TabDef('بانتظار الصيانة', AppConstants.waitingMaintenanceStatuses),
    _TabDef('جاهز للتسليم', AppConstants.readyForCustomerStatuses),
    _TabDef('تم التسليم', AppConstants.deliveredMaintenanceStatuses),
    _TabDef('عائد ضمن الضمان', AppConstants.warrantyReturnStatuses),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    context.read<MaintenanceCubit>().loadAll();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final statuses = _tabs[_tabController.index].statuses;
    context.read<MaintenanceCubit>().loadAll(
          statuses: statuses,
          search: _searchQuery.isEmpty ? null : _searchQuery,
        );
  }

  void _onSearch(String value) {
    setState(() => _searchQuery = value);
    final statuses = _tabs[_tabController.index].statuses;
    context.read<MaintenanceCubit>().loadAll(
          statuses: statuses,
          search: value.isEmpty ? null : value,
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'بحث برقم التذكرة، العميل، الجهاز...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Tabs ────────────────────────────────────────────────────────────
          Container(
            color: colors.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle:
                  GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<MaintenanceCubit, MaintenanceState>(
              builder: (context, state) {
                if (state is MaintenanceLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is MaintenanceError) {
                  return _ErrorView(
                    message: state.message,
                    onRetry: () => context.read<MaintenanceCubit>().loadAll(),
                  );
                }
                if (state is MaintenanceLoaded) {
                  if (state.items.isEmpty) {
                    return _EmptyView(
                        onAdd: () => context.go('/maintenance/new'));
                  }
                  return _MaintenanceList(items: state.items);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/maintenance/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('استلام جهاز جديد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List
// ─────────────────────────────────────────────────────────────────────────────

class _MaintenanceList extends StatelessWidget {
  final List<MaintenanceModel> items;
  const _MaintenanceList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (context, index) => _MaintenanceCard(item: items[index]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceModel item;
  const _MaintenanceCard({required this.item});

  Color _statusColor(String status) {
    return AppColors.maintenanceStatus(status);
  }

  String _elapsedLabel(int sinceMs) {
    final since = DateTime.fromMillisecondsSinceEpoch(sinceMs);
    final diff = DateTime.now().difference(since);
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inMinutes.clamp(0, 59)} دقيقة';
  }

  // Returns the alert color + tooltip when a card needs attention.
  // Priority: device stayed 2+ days (red) > warranty expiring (orange) > waiting part (purple)
  ({Color color, String tooltip})? get _alert {
    if (item.status != AppConstants.statusDelivered &&
        item.status != AppConstants.statusCancelled) {
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(item.receivedAt))
          .inDays;
      if (days >= 2) {
        return (
          color: AppColors.error,
          tooltip: 'الجوال في المحل منذ $days يوم'
        );
      }
    }
    if (item.warrantyEnd != null &&
        item.warrantyType != null &&
        item.warrantyType != 'none') {
      final end = DateTime.fromMillisecondsSinceEpoch(item.warrantyEnd!);
      final daysLeft = _calendarDaysUntil(end);
      if (daysLeft == 1 || daysLeft == 2) {
        final msg = daysLeft == 1 ? 'الضمان ينتهي غداً' : 'الضمان ينتهي بعد غد';
        return (color: AppColors.warning, tooltip: msg);
      }
    }
    if (item.status == AppConstants.statusWaitingPart) {
      return (color: Colors.purple, tooltip: 'بانتظار قطعة غيار');
    }
    return null;
  }

  int _calendarDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  String _dateLabel(int? ms) {
    if (ms == null) return 'غير محدد';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _statusColor(item.status);
    final stageLabel = AppConstants.maintenanceStageLabel(item.status);
    final receivedDate = DateTime.fromMillisecondsSinceEpoch(item.receivedAt);
    final dateStr =
        '${receivedDate.day}/${receivedDate.month}/${receivedDate.year}';
    final alert = _alert;
    // Alert overrides the dot color; otherwise use status color
    final dotColor = alert?.color ?? statusColor;
    final dotTooltip = alert?.tooltip ?? item.statusLabel;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go('/maintenance/${item.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Animated status bar – pulses on every card
                  _PulsingBar(color: statusColor),
                  const SizedBox(width: 14),

                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.ticketNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 0,
                              child: _StatusBadge(
                                  label: stageLabel, color: statusColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.customerName ?? 'عميل غير محدد',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.brand} ${item.model}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                        if ((item.customerPhone ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.customerPhone!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          item.faultDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 13, color: colors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                dateStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                    fontSize: 12, color: colors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _elapsedLabel(
                                    item.status == AppConstants.statusReady
                                        ? item.updatedAt
                                        : item.receivedAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                    fontSize: 12, color: colors.textSecondary),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${item.totalCost.toStringAsFixed(0)} ر.س',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (item.isOverdue) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 13, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text(
                                'متأخر عن الموعد',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.warrantyExpiryApproved) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.gpp_bad_rounded,
                                    size: 16, color: AppColors.error),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'انتهى الضمان - النهاية: ${_dateLabel(item.warrantyEnd)} - الاعتماد: ${_dateLabel(item.warrantyExpiryApprovedAt)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  // Pulsing dot – visible on EVERY card
                  _PulsingDot(color: dotColor, tooltip: dotTooltip),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        // Extra large blinking badge for critical alerts only
        if (alert != null)
          Positioned(
            top: -6,
            left: -6,
            child: _AlertBadge(color: alert.color, tooltip: alert.tooltip),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated status bar (left side) – visible on every card
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingBar extends StatelessWidget {
  final Color color;
  const _PulsingBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 72,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.35, end: 1.0, duration: 900.ms, curve: Curves.easeInOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot – always visible on every card (status color)
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatelessWidget {
  final Color color;
  final String tooltip;
  const _PulsingDot({required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 0.6, end: 1.4, duration: 800.ms, curve: Curves.easeInOut)
          .fade(begin: 0.4, end: 1.0, duration: 800.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert badge – extra large, shown only for critical alert conditions
// ─────────────────────────────────────────────────────────────────────────────

class _AlertBadge extends StatelessWidget {
  final Color color;
  final String tooltip;
  const _AlertBadge({required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.8),
              blurRadius: 10,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.priority_high_rounded,
            size: 12, color: Colors.white),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 0.7, end: 1.3, duration: 500.ms, curve: Curves.easeInOut)
          .fade(begin: 0.6, end: 1.0, duration: 500.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined,
              size: 72,
              color: context.appColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'لا توجد سجلات صيانة',
            style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط + لإضافة صيانة جديدة',
            style: GoogleFonts.cairo(
                fontSize: 14, color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text('إضافة صيانة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ',
            style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(message,
              style: GoogleFonts.cairo(fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab definition helper
// ─────────────────────────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final List<String>? statuses;
  const _TabDef(this.label, this.statuses);
}
