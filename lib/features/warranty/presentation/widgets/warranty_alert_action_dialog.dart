import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/warranty_action_model.dart';
import '../../data/warranty_repository.dart';

Future<bool?> showWarrantyAlertActionDialog(
  BuildContext context, {
  required String warrantyId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => WarrantyAlertActionDialog(warrantyId: warrantyId),
  );
}

class WarrantyAlertActionDialog extends StatefulWidget {
  final String warrantyId;
  const WarrantyAlertActionDialog({super.key, required this.warrantyId});

  @override
  State<WarrantyAlertActionDialog> createState() =>
      _WarrantyAlertActionDialogState();
}

class _WarrantyAlertActionDialogState extends State<WarrantyAlertActionDialog> {
  final _repo = WarrantyRepository();
  late Future<WarrantyAlertDetails?> _future;
  bool _openedLogged = false;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WarrantyAlertDetails?> _load() async {
    final details = await _repo.getAlertDetails(widget.warrantyId);
    if (details != null && !_openedLogged) {
      _openedLogged = true;
      await _repo.recordAction(
        warrantyId: details.warranty.id,
        maintenanceId: details.warranty.maintenanceId,
        action: 'alert_opened',
      );
      return _repo.getAlertDetails(widget.warrantyId);
    }
    return details;
  }

  void _reload() {
    setState(() {
      _future = _repo.getAlertDetails(widget.warrantyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'إدارة تنبيه انتهاء الضمان',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FutureBuilder<WarrantyAlertDetails?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final details = snapshot.data;
              if (details == null) {
                return SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'تعذر العثور على بيانات الضمان.',
                      style: GoogleFonts.cairo(color: AppColors.error),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetails(details),
                    const SizedBox(height: 14),
                    _buildActions(details),
                    const SizedBox(height: 14),
                    _buildLog(details.actions),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, _changed),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(WarrantyAlertDetails details) {
    final warranty = details.warranty;
    final days = warranty.calendarDaysRemaining;
    final remaining = days > 0
        ? 'متبقٍ $days يوم'
        : days == 0
            ? 'ينتهي اليوم'
            : 'منتهي منذ ${days.abs()} يوم';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warranty.expiryApproved) _buildExpiredStamp(details),
        if (warranty.expiryApproved) const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoTile('اسم العميل', details.customerName, Icons.person_rounded),
            _InfoTile(
                'رقم الجوال',
                details.customerPhone.isEmpty
                    ? 'غير مسجل'
                    : details.customerPhone,
                Icons.phone_rounded),
            _InfoTile('نوع الجهاز وموديله', details.deviceName,
                Icons.phone_android_rounded),
            _InfoTile('رقم الصيانة أو الفاتورة', details.ticketOrInvoice,
                Icons.receipt_long_rounded),
            _InfoTile('تاريخ بدء الضمان', _date(warranty.startDate),
                Icons.play_arrow_rounded),
            _InfoTile('تاريخ انتهاء الضمان', _date(warranty.endDate),
                Icons.flag_rounded),
            _InfoTile('الأيام', remaining, Icons.hourglass_bottom_rounded,
                accent: days < 0 ? AppColors.error : AppColors.warning),
            _InfoTile('حالة الصيانة الحالية', details.maintenanceStatusLabel,
                Icons.build_circle_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildExpiredStamp(WarrantyAlertDetails details) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'انتهى الضمان',
            style: GoogleFonts.cairo(
              color: AppColors.error,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'تاريخ الانتهاء: ${_date(details.warranty.endDate)} | تاريخ الاعتماد: ${_date(details.warranty.expiryApprovedAt)}',
            style: GoogleFonts.cairo(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(WarrantyAlertDetails details) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإجراء المطلوب',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: Icons.update_rounded,
                label: 'تجديد الضمان',
                color: AppColors.primary,
                filled: true,
                busy: _busy,
                onPressed: () => _renew(details),
              ),
              _ActionButton(
                icon: Icons.gpp_bad_rounded,
                label: 'اعتماد انتهاء الضمان',
                color: AppColors.error,
                busy: _busy,
                onPressed: () => _approveExpiry(details),
              ),
              _ActionButton(
                icon: Icons.notifications_off_rounded,
                label: 'إيقاف التنبيه',
                color: AppColors.warning,
                busy: _busy,
                onPressed: () => _disableAlert(details),
              ),
              _ActionButton(
                icon: Icons.note_add_rounded,
                label: 'ملاحظة تصحيحية',
                color: AppColors.success,
                busy: _busy,
                onPressed: () => _addCorrectionNote(details),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLog(List<WarrantyActionModel> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل إجراءات الضمان',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        if (actions.isEmpty)
          Text('لا توجد إجراءات مسجلة.',
              style: GoogleFonts.cairo(color: AppColors.lightTextSecondary))
        else
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        action.actionLabel,
                        action.username ?? 'النظام',
                        _dateTime(action.createdAt),
                        if ((action.notes ?? '').trim().isNotEmpty)
                          action.notes!,
                        if ((action.oldValue ?? '').trim().isNotEmpty)
                          'السابق: ${action.oldValue}',
                        if ((action.newValue ?? '').trim().isNotEmpty)
                          'الجديد: ${action.newValue}',
                      ].join(' - '),
                      style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _disableAlert(WarrantyAlertDetails details) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد إيقاف التنبيه',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: reasonCtrl,
          textDirection: TextDirection.rtl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب إيقاف التنبيه (اختياري)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.notifications_off_rounded),
            label: Text('إيقاف التنبيه', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true) return;
    await _runAction(
      () => _repo.disableAlert(
        details.warranty.id,
        reason: reason.isEmpty ? null : reason,
      ),
      'تم إيقاف التنبيه',
    );
  }

  Future<void> _renew(WarrantyAlertDetails details) async {
    final durationCtrl = TextEditingController(text: '30');
    var unit = 'days';
    var startDate = DateTime.now();

    DateTime endDate() {
      final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
      final days = unit == 'months' ? duration * 30 : duration;
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      return start.add(Duration(days: days <= 0 ? 0 : days));
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final calculatedEnd = endDate();
          return AlertDialog(
            title: Text('تجديد الضمان',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'المدة الجديدة',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'days', label: Text('أيام')),
                          ButtonSegment(value: 'months', label: Text('أشهر')),
                        ],
                        selected: {unit},
                        onSelectionChanged: (value) =>
                            setDialogState(() => unit = value.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded),
                    title: Text('بداية التجديد', style: GoogleFonts.cairo()),
                    subtitle:
                        Text(_date(startDate), style: GoogleFonts.cairo()),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => startDate = picked);
                        }
                      },
                      child: Text('اختيار', style: GoogleFonts.cairo()),
                    ),
                  ),
                  _InfoTile('تاريخ الانتهاء الجديد', _date(calculatedEnd),
                      Icons.flag_rounded),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
                  if (duration <= 0) return;
                  final confirmed = await _confirm(
                    ctx,
                    title: 'تأكيد تجديد الضمان',
                    message:
                        'سيتم حفظ مدة الضمان السابقة والجديدة وتحديث تاريخ انتهاء الضمان إلى ${_date(calculatedEnd)}.',
                    confirmLabel: 'تأكيد التجديد',
                    color: AppColors.primary,
                  );
                  if (confirmed && ctx.mounted) Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.update_rounded),
                label: Text('تجديد الضمان', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );

    final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
    durationCtrl.dispose();
    if (saved != true || duration <= 0) return;
    await _runAction(
      () => _repo.renewWarranty(
        warrantyId: details.warranty.id,
        duration: duration,
        unit: unit,
        startDate: startDate.millisecondsSinceEpoch,
      ),
      'تم تجديد الضمان',
    );
  }

  Future<void> _approveExpiry(WarrantyAlertDetails details) async {
    final confirmed = await _confirm(
      context,
      title: 'اعتماد انتهاء الضمان',
      message:
          'سيتم تغيير حالة الضمان إلى منتهٍ ومعتمد، وإيقاف التنبيه المتكرر، وإظهار ختم انتهى الضمان في السجل والتقارير.',
      confirmLabel: 'اعتماد انتهاء الضمان',
      color: AppColors.error,
    );
    if (!confirmed) return;
    await _runAction(
      () => _repo.approveExpiry(details.warranty.id),
      'تم اعتماد انتهاء الضمان',
    );
  }

  Future<void> _addCorrectionNote(WarrantyAlertDetails details) async {
    final ctrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ملاحظة تصحيحية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'اكتب الملاحظة دون حذف أو تعديل الإجراءات السابقة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save_rounded),
            label: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (saved != true || note.isEmpty) return;
    await _runAction(
      () => _repo.addCorrectionNote(details.warranty.id, note),
      'تمت إضافة الملاحظة التصحيحية',
    );
  }

  Future<void> _runAction(
    Future<dynamic> Function() action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    BuildContext dialogContext, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title:
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
        content: Text(message, style: GoogleFonts.cairo(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _date(Object? value) {
    int? ms;
    if (value is int) ms = value;
    if (value is DateTime) {
      return '${value.day}/${value.month}/${value.year}';
    }
    if (ms == null) return 'غير محدد';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _dateTime(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} ${date.hour}:$minute';
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _InfoTile(
    this.label,
    this.value,
    this.icon, {
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 235,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
      ],
    );

    if (filled) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        onPressed: busy ? null : onPressed,
        child: child,
      );
    }

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: busy ? null : onPressed,
      child: child,
    );
  }
}
