import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/alert_sound_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/notification_model.dart';
import '../../data/notifications_repository.dart';

/// Shows the recurring alert popup for [notification] on top of whichever
/// screen is currently visible, using the app's root navigator instead of a
/// screen-supplied [BuildContext] — this is what lets [AlertMonitorService]
/// invoke it from a background timer with no widget of its own.
Future<void> showRecurringAlertDialog(NotificationModel notification) async {
  final context = AppRouter.rootNavigatorKey.currentContext;
  if (context == null) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecurringAlertDialog(notification: notification),
  );
}

/// Shows one popup for a group of due alerts instead of opening every alert
/// one after another.
Future<void> showRecurringAlertsDialog(
  List<NotificationModel> notifications,
) async {
  if (notifications.isEmpty) return;
  if (notifications.length == 1) {
    return showRecurringAlertDialog(notifications.first);
  }
  final context = AppRouter.rootNavigatorKey.currentContext;
  if (context == null) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecurringAlertsDialog(notifications: notifications),
  );
}

enum _SnoozeChoice { oneHour, threeHours, tomorrow, custom }

/// Shared snooze picker used by the popup and the notifications screen.
Future<Duration?> showAlertSnoozePicker(BuildContext context) async {
  final choice = await showModalBottomSheet<_SnoozeChoice>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.snooze_rounded),
              title: Text('ساعة واحدة', style: GoogleFonts.cairo()),
              onTap: () => Navigator.pop(ctx, _SnoozeChoice.oneHour),
            ),
            ListTile(
              leading: const Icon(Icons.more_time_rounded),
              title: Text('ثلاث ساعات', style: GoogleFonts.cairo()),
              onTap: () => Navigator.pop(ctx, _SnoozeChoice.threeHours),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title:
                  Text('حتى الغد الساعة 9 صباحاً', style: GoogleFonts.cairo()),
              onTap: () => Navigator.pop(ctx, _SnoozeChoice.tomorrow),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_rounded),
              title: Text('مدة مخصصة (بالساعات)', style: GoogleFonts.cairo()),
              onTap: () => Navigator.pop(ctx, _SnoozeChoice.custom),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  switch (choice) {
    case _SnoozeChoice.oneHour:
      return const Duration(hours: 1);
    case _SnoozeChoice.threeHours:
      return const Duration(hours: 3);
    case _SnoozeChoice.tomorrow:
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + 1, 9).difference(now);
    case _SnoozeChoice.custom:
      final hours = await _askCustomSnoozeHours(context);
      return hours == null ? null : Duration(hours: hours);
  }
}

Future<int?> _askCustomSnoozeHours(BuildContext context) async {
  final controller = TextEditingController(text: '2');
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('تأجيل لعدد ساعات', style: GoogleFonts.cairo()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الساعات'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = int.tryParse(controller.text.trim()) ?? 0;
              if (hours > 0) Navigator.pop(ctx, hours);
            },
            child: Text('تأجيل', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

class RecurringAlertsDialog extends StatefulWidget {
  final List<NotificationModel> notifications;

  const RecurringAlertsDialog({
    super.key,
    required this.notifications,
  });

  @override
  State<RecurringAlertsDialog> createState() => _RecurringAlertsDialogState();
}

class _RecurringAlertsDialogState extends State<RecurringAlertsDialog> {
  final _repo = NotificationsRepository();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final visible = widget.notifications.take(7).toList();
    final remaining = widget.notifications.length - visible.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.notifications.length} تنبيهات تحتاج مراجعة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يمكنك تأجيلها كلها مؤقتاً أو الدخول إلى شاشة التنبيهات لإدارة كل تنبيه وتجديد الضمانات عند الحاجة.',
                  style: GoogleFonts.cairo(height: 1.55),
                ),
                const SizedBox(height: 12),
                ...visible.map(
                  (notification) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notification.priorityColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color:
                            notification.priorityColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          notification.priorityIcon,
                          color: notification.priorityColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                notification.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (remaining > 0)
                  Text(
                    'ويوجد $remaining تنبيه إضافي داخل شاشة التنبيهات.',
                    style: GoogleFonts.cairo(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _openNotifications,
            icon: const Icon(Icons.list_alt_rounded),
            label: Text('إدارة التنبيهات', style: GoogleFonts.cairo()),
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : _snoozeAll,
            icon: const Icon(Icons.snooze_rounded),
            label: Text(
              'تأجيل الكل (${widget.notifications.length})',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _openNotifications() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/notifications');
  }

  Future<void> _snoozeAll() async {
    final duration = await showAlertSnoozePicker(context);
    if (duration == null || !mounted) return;
    setState(() => _busy = true);
    await _repo.snoozeMany(
      widget.notifications.map((notification) => notification.id),
      until: DateTime.now().add(duration).millisecondsSinceEpoch,
    );
    await AlertSoundService().stop();
    if (!mounted) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/notifications');
  }
}

class RecurringAlertDialog extends StatefulWidget {
  final NotificationModel notification;
  const RecurringAlertDialog({super.key, required this.notification});

  @override
  State<RecurringAlertDialog> createState() => _RecurringAlertDialogState();
}

class _RecurringAlertDialogState extends State<RecurringAlertDialog> {
  final _repo = NotificationsRepository();
  late Future<AlertPopupDetails?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getAlertDetails(widget.notification.id);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.notification.title,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: FutureBuilder<AlertPopupDetails?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final details = snapshot.data;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.notification.message,
                        style: GoogleFonts.cairo()),
                    if (details?.customerName != null) ...[
                      const SizedBox(height: 10),
                      _row('العميل', details!.customerName!),
                    ],
                    if (details?.customerPhone != null &&
                        details!.customerPhone!.isNotEmpty)
                      _row('الجوال', details.customerPhone!),
                    if (details?.deviceName != null &&
                        details!.deviceName!.isNotEmpty)
                      _row('الجهاز', details.deviceName!),
                    if (details?.ticketNumber != null &&
                        details!.ticketNumber!.isNotEmpty)
                      _row('رقم الصيانة', details.ticketNumber!),
                  ],
                ),
              );
            },
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Row(
            children: [
              if (widget.notification.alertStopped ||
                  widget.notification.isSnoozedNow ||
                  widget.notification.isRead)
                TextButton.icon(
                  onPressed: _busy ? null : _resumeAlert,
                  icon: const Icon(
                    Icons.notifications_active_rounded,
                    size: 18,
                  ),
                  label: Text('استئناف التنبيه', style: GoogleFonts.cairo()),
                )
              else ...[
                TextButton.icon(
                  onPressed: _busy ? null : _showSnoozeMenu,
                  icon: const Icon(Icons.snooze_rounded, size: 18),
                  label: Text('تأجيل', style: GoogleFonts.cairo()),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _stopAlert,
                  icon: const Icon(
                    Icons.notifications_off_rounded,
                    size: 18,
                  ),
                  label: Text(
                    'إيقاف هذا التنبيه',
                    style: GoogleFonts.cairo(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
          FutureBuilder<AlertPopupDetails?>(
            future: _future,
            builder: (context, snapshot) {
              final maintenanceId = snapshot.data?.maintenanceId ??
                  (widget.notification.referenceType == 'maintenance'
                      ? widget.notification.referenceId
                      : null);
              final destination = _destinationFor(maintenanceId);
              return ElevatedButton.icon(
                onPressed: destination == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        context.go(destination.$1);
                      },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(destination?.$2 ?? 'فتح التفاصيل',
                    style: GoogleFonts.cairo()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, style: GoogleFonts.cairo())),
        ],
      ),
    );
  }

  Future<void> _showSnoozeMenu() async {
    final snoozeDuration = await showAlertSnoozePicker(context);
    if (snoozeDuration == null || !mounted) return;

    setState(() => _busy = true);
    await _repo.snooze(
      widget.notification.id,
      until: DateTime.now().add(snoozeDuration).millisecondsSinceEpoch,
    );
    await AlertSoundService().stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _resumeAlert() async {
    setState(() => _busy = true);
    await AlertSoundService().stop();
    await _repo.resumeAlert(widget.notification.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stopAlert() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إيقاف هذا التنبيه؟', style: GoogleFonts.cairo()),
          content: Text(
            'لن يظهر هذا التنبيه مرة أخرى إلا إذا تحققت حالة جديدة.',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('إيقاف', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await AlertSoundService().stop();
    await _repo.stopAlert(widget.notification.id);
    if (mounted) Navigator.of(context).pop();
  }

  (String, String)? _destinationFor(String? maintenanceId) {
    final referenceId = widget.notification.referenceId;
    switch (widget.notification.referenceType) {
      case 'maintenance':
        final id = maintenanceId ?? referenceId;
        return id == null ? null : ('/maintenance/$id', 'فتح أمر الصيانة');
      case 'warranty':
        return ('/warranty', 'فتح الضمانات');
      case 'product':
        return ('/inventory', 'فتح المخزون');
      case 'customer':
        return referenceId == null
            ? null
            : ('/customers/$referenceId', 'فتح العميل');
      case 'device':
        return referenceId == null
            ? null
            : ('/devices/$referenceId', 'فتح الجهاز');
      default:
        return null;
    }
  }
}
