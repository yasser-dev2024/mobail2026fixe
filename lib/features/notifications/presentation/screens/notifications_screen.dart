import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/alert_sound_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../warranty/presentation/widgets/warranty_alert_action_dialog.dart';
import '../../data/notification_model.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';
import '../widgets/recurring_alert_dialog.dart';

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
    AlertSoundService().stop();
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
              _buildFilterBar(context, state, colors),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الإشعارات',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (unreadCount > 0)
                Text(
                  '$unreadCount إشعار غير مقروء',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
            ],
          );
          final refresh = IconButton(
            onPressed: () =>
                context.read<NotificationsCubit>().generateSmartNotifications(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الإشعارات',
            color: colors.textSecondary,
          );
          final markAll = OutlinedButton.icon(
            onPressed: () => context.read<NotificationsCubit>().markAllAsRead(),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(
              'تعليم الكل كمقروء',
              style: GoogleFonts.cairo(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: title),
                    refresh,
                  ],
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: markAll,
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              title,
              const Spacer(),
              if (unreadCount > 0) markAll,
              const SizedBox(width: 12),
              refresh,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    NotificationsState state,
    AppColorsExtension colors,
  ) {
    final activeNotifications = state is NotificationsLoaded
        ? state.notifications
            .where((notification) => notification.isAlertActiveNow)
            .toList()
        : const <NotificationModel>[];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: colors.surface,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
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
          if (activeNotifications.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _snoozeNotifications(
                context,
                activeNotifications,
              ),
              icon: const Icon(Icons.snooze_rounded, size: 18),
              label: Text(
                'تأجيل الكل (${activeNotifications.length})',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
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
            onSnooze: () => _snoozeNotification(context, notif),
            onResume: () => _resumeNotification(context, notif),
            onStop: () => _stopNotification(context, notif),
            onTap: () => _handleTap(context, notif),
            onOpenReference: () => _handleReferenceTap(context, notif),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _snoozeNotifications(
    BuildContext context,
    List<NotificationModel> notifications,
  ) async {
    final duration = await showAlertSnoozePicker(context);
    if (duration == null || !context.mounted) return;
    await AlertSoundService().stop();
    if (!context.mounted) return;
    await context.read<NotificationsCubit>().snoozeMany(
          notifications.map((notification) => notification.id),
          until: DateTime.now().add(duration).millisecondsSinceEpoch,
          unreadOnly: _unreadOnly ? true : false,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تأجيل ${notifications.length} تنبيهات',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _snoozeNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final duration = await showAlertSnoozePicker(context);
    if (duration == null || !context.mounted) return;
    await AlertSoundService().stop();
    if (!context.mounted) return;
    await context.read<NotificationsCubit>().snooze(
          notification.id,
          until: DateTime.now().add(duration).millisecondsSinceEpoch,
          unreadOnly: _unreadOnly ? true : false,
        );
  }

  Future<void> _resumeNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    await AlertSoundService().stop();
    if (!context.mounted) return;
    await context.read<NotificationsCubit>().resumeAlert(
          notification.id,
          unreadOnly: _unreadOnly ? true : false,
        );
  }

  Future<void> _stopNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'إيقاف هذا التنبيه؟',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'يمكنك استئناف التنبيه لاحقاً من هذه الشاشة.',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('إيقاف', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AlertSoundService().stop();
    if (!context.mounted) return;
    await context.read<NotificationsCubit>().stopAlert(
          notification.id,
          unreadOnly: _unreadOnly ? true : false,
        );
  }

  Future<void> _handleTap(BuildContext context, NotificationModel notif) async {
    await AlertSoundService().stop();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => RecurringAlertDialog(notification: notif),
    );
    if (!context.mounted) return;
    await context.read<NotificationsCubit>().loadNotifications(
          unreadOnly: _unreadOnly ? true : false,
        );
  }

  Future<void> _handleReferenceTap(
    BuildContext context,
    NotificationModel notif,
  ) async {
    final notificationsCubit = context.read<NotificationsCubit>();
    await notificationsCubit.markAsRead(notif.id);
    if (!context.mounted) return;
    if (_isWarrantyAlert(notif) && notif.referenceId != null) {
      final changed = await showWarrantyAlertActionDialog(
        context,
        warrantyId: notif.referenceId!,
      );
      if (!context.mounted) return;
      if (changed == true) {
        await notificationsCubit.generateSmartNotifications();
      } else {
        await notificationsCubit.loadNotifications();
      }
      return;
    }
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

  bool _isWarrantyAlert(NotificationModel notif) {
    return notif.referenceType == 'warranty' ||
        notif.type.startsWith('warranty_');
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
    );
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

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onRead;
  final VoidCallback onDelete;
  final VoidCallback onSnooze;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onTap;
  final VoidCallback onOpenReference;

  const _NotificationCard({
    required this.notification,
    required this.onRead,
    required this.onDelete,
    required this.onSnooze,
    required this.onResume,
    required this.onStop,
    required this.onTap,
    required this.onOpenReference,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final colors = context.appColors;
    final priorityColor = n.priorityColor;
    final isCritical = n.priority == 'critical';
    final isWarranty =
        n.referenceType == 'warranty' || n.type.startsWith('warranty_');

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
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
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
                // Fixed priority icon: no repeating scale/pulse animation.
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
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.error,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
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
                        if (n.alertStopped || n.isSnoozedNow) ...[
                          const SizedBox(height: 6),
                          _AlertStateBadge(notification: n),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            if (n.alertStopped || n.isSnoozedNow)
                              TextButton.icon(
                                onPressed: onResume,
                                icon: const Icon(
                                  Icons.notifications_active_rounded,
                                  size: 17,
                                ),
                                label: Text(
                                  'استئناف الآن',
                                  style: GoogleFonts.cairo(fontSize: 11),
                                ),
                              )
                            else ...[
                              TextButton.icon(
                                onPressed: onSnooze,
                                icon:
                                    const Icon(Icons.snooze_rounded, size: 17),
                                label: Text(
                                  'تأجيل',
                                  style: GoogleFonts.cairo(fontSize: 11),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: onStop,
                                icon: const Icon(
                                  Icons.notifications_off_rounded,
                                  size: 17,
                                ),
                                label: Text(
                                  'إيقاف',
                                  style: GoogleFonts.cairo(fontSize: 11),
                                ),
                              ),
                            ],
                            if (isWarranty)
                              TextButton.icon(
                                onPressed: onOpenReference,
                                icon:
                                    const Icon(Icons.update_rounded, size: 17),
                                label: Text(
                                  'إدارة وتجديد الضمان',
                                  style: GoogleFonts.cairo(fontSize: 11),
                                ),
                              ),
                          ],
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
                        onPressed: onRead,
                        icon:
                            const Icon(Icons.mark_email_read_rounded, size: 18),
                        tooltip: 'تعليم كمقروء',
                        color: AppColors.primary,
                      ),
                    IconButton(
                      onPressed: onDelete,
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

class _AlertStateBadge extends StatelessWidget {
  final NotificationModel notification;

  const _AlertStateBadge({required this.notification});

  @override
  Widget build(BuildContext context) {
    final stopped = notification.alertStopped;
    final color = stopped ? AppColors.error : AppColors.warning;
    final text = stopped
        ? 'التنبيه متوقف'
        : 'مؤجل حتى ${_dateTimeLabel(notification.snoozedUntil!)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _dateTimeLabel(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month} ${date.hour}:$minute';
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
