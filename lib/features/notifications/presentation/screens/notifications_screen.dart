import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/notification_model.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          return Column(
            children: [
              _buildHeader(context, state, colors),
              _buildFilterBar(context, colors),
              Expanded(child: _buildBody(context, state, colors)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotificationsState state,
      AppColorsExtension colors) {
    final unreadCount = state is NotificationsLoaded ? state.unreadCount : 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الإشعارات',
                style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary),
              ),
              if (unreadCount > 0)
                Text(
                  '$unreadCount إشعار غير مقروء',
                  style:
                      GoogleFonts.cairo(fontSize: 13, color: AppColors.primary),
                ),
            ],
          ),
          const Spacer(),
          if (unreadCount > 0)
            OutlinedButton.icon(
              onPressed: () =>
                  context.read<NotificationsCubit>().markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text('تعليم الكل كمقروء',
                  style: GoogleFonts.cairo(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () =>
                context.read<NotificationsCubit>().generateSmartNotifications(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الإشعارات',
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: colors.surface,
      child: Row(
        children: [
          _FilterChip(
            label: 'الكل',
            selected: !_unreadOnly,
            onTap: () {
              setState(() => _unreadOnly = false);
              context
                  .read<NotificationsCubit>()
                  .loadNotifications(unreadOnly: false);
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'غير مقروءة',
            selected: _unreadOnly,
            onTap: () {
              setState(() => _unreadOnly = true);
              context
                  .read<NotificationsCubit>()
                  .loadNotifications(unreadOnly: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsState state,
      AppColorsExtension colors) {
    if (state is NotificationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is NotificationsError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(state.message,
                style: GoogleFonts.cairo(color: colors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  context.read<NotificationsCubit>().loadNotifications(),
              child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      );
    }
    if (state is NotificationsLoaded) {
      if (state.notifications.isEmpty) {
        return _buildEmptyState(colors);
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.notifications.length,
        itemBuilder: (context, i) {
          final notif = state.notifications[i];
          return _NotificationCard(
            notification: notif,
            onRead: () =>
                context.read<NotificationsCubit>().markAsRead(notif.id),
            onDelete: () => context.read<NotificationsCubit>().delete(notif.id),
            onTap: () => _handleTap(context, notif),
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: i * 50))
              .slideX(begin: 0.1);
        },
      );
    }
    return const SizedBox.shrink();
  }

  void _handleTap(BuildContext context, NotificationModel notif) {
    context.read<NotificationsCubit>().markAsRead(notif.id);
    if (notif.referenceId != null) {
      switch (notif.referenceType) {
        case 'maintenance':
          if (notif.type.startsWith('maintenance_status_') ||
              notif.type == 'maintenance_ready') {
            context.go('/whatsapp?maintenanceId=${notif.referenceId}');
          } else {
            context.go('/maintenance/${notif.referenceId}');
          }
          break;
        case 'product':
          context.go('/inventory');
          break;
        case 'warranty':
          context.go('/warranty');
          break;
        case 'customer':
          context.go('/customers/${notif.referenceId}');
          break;
        case 'device':
          context.go('/devices/${notif.referenceId}');
          break;
      }
    }
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد إشعارات',
            style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا إشعاراتك عند توفرها',
            style: GoogleFonts.cairo(fontSize: 14, color: colors.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onRead;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onRead,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final colors = context.appColors;
    final priorityColor = n.priorityColor;
    final isCritical = n.priority == 'critical';

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
                n.isRead ? colors.card : priorityColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: n.isRead
                  ? colors.border
                  : priorityColor.withValues(alpha: 0.3),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Priority color bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Icon with pulse dot for critical
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(n.priorityIcon,
                            color: priorityColor, size: 22),
                      ),
                      if (isCritical)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Opacity(
                              opacity: _pulseAnim.value,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: n.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            _PriorityBadge(priority: n.priority),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.message,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: colors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.timeAgo,
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!n.isRead)
                      IconButton(
                        onPressed: widget.onRead,
                        icon:
                            const Icon(Icons.mark_email_read_rounded, size: 18),
                        tooltip: 'تعليم كمقروء',
                        color: AppColors.primary,
                      ),
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      tooltip: 'حذف',
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      'critical' => ('حرج', AppColors.error),
      'high' => ('عالي', AppColors.warning),
      'medium' => ('متوسط', AppColors.primary),
      _ => ('منخفض', AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
