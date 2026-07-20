import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
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
              TextButton.icon(
                onPressed: _busy ? null : _showSnoozeMenu,
                icon: const Icon(Icons.snooze_rounded, size: 18),
                label: Text('تأجيل', style: GoogleFonts.cairo()),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _stopAlert,
                icon: const Icon(Icons.notifications_off_rounded, size: 18),
                label: Text('إيقاف هذا التنبيه',
                    style: GoogleFonts.cairo(color: AppColors.error)),
              ),
            ],
          ),
          FutureBuilder<AlertPopupDetails?>(
            future: _future,
            builder: (context, snapshot) {
              final maintenanceId = snapshot.data?.maintenanceId ??
                  (widget.notification.referenceType == 'maintenance'
                      ? widget.notification.referenceId
                      : null);
              return ElevatedButton.icon(
                onPressed: maintenanceId == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        context.go('/maintenance/$maintenanceId');
                      },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('فتح أمر الصيانة', style: GoogleFonts.cairo()),
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
          Text('$label: ', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, style: GoogleFonts.cairo())),
        ],
      ),
    );
  }

  Future<void> _showSnoozeMenu() async {
    final now = DateTime.now();
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('ساعة واحدة', style: GoogleFonts.cairo()),
                onTap: () => Navigator.pop(ctx, const Duration(hours: 1)),
              ),
              ListTile(
                title: Text('ثلاث ساعات', style: GoogleFonts.cairo()),
                onTap: () => Navigator.pop(ctx, const Duration(hours: 3)),
              ),
              ListTile(
                title: Text('حتى الغد', style: GoogleFonts.cairo()),
                onTap: () => Navigator.pop(
                  ctx,
                  DateTime(now.year, now.month, now.day + 1, 9)
                      .difference(now),
                ),
              ),
              ListTile(
                title: Text('مدة مخصصة (بالساعات)', style: GoogleFonts.cairo()),
                onTap: () => Navigator.pop(ctx, null),
                trailing: const Icon(Icons.edit_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );

    Duration? snoozeDuration = choice;
    if (snoozeDuration == null && mounted) {
      final custom = await _askCustomHours();
      if (custom == null) return;
      snoozeDuration = Duration(hours: custom);
    }
    if (snoozeDuration == null || !mounted) return;

    setState(() => _busy = true);
    await _repo.snooze(
      widget.notification.id,
      until: DateTime.now().add(snoozeDuration).millisecondsSinceEpoch,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<int?> _askCustomHours() async {
    final ctrl = TextEditingController(text: '2');
    return showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تأجيل لعدد ساعات', style: GoogleFonts.cairo()),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد الساعات'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 1),
              child: Text('تأجيل', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
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
    await _repo.stopAlert(widget.notification.id);
    if (mounted) Navigator.of(context).pop();
  }
}
