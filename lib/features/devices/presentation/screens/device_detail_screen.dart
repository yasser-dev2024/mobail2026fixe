import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database_service.dart';
import '../../data/device_model.dart';
import '../../data/devices_repository.dart';
import '../../../notifications/data/notifications_repository.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../maintenance/data/maintenance_model.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _devicesRepo = DevicesRepository();
  final _db = DatabaseService();

  DeviceModel? _device;
  List<MaintenanceModel> _maintenances = [];
  String? _customerPhone;
  String? _customerName;
  int _unreadDeviceNotifications = 0;
  bool _loading = true;
  bool _flash = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final device = await _devicesRepo.getById(widget.deviceId);
    List<MaintenanceModel> maintenances = [];
    String? phone;
    String? name;

    if (device != null) {
      final shopId = await _db.getCurrentShopId();
      // Load maintenance records
      final rows = await _db.rawQuery(
        '''SELECT m.*, c.name as customer_name,
                  w.expiry_approved AS warranty_expiry_approved,
                  w.expiry_approved_at AS warranty_expiry_approved_at,
                  w.expiry_approved_by AS warranty_expiry_approved_by
           FROM maintenance m
           LEFT JOIN customers c ON c.id = m.customer_id AND c.shop_id = m.shop_id
           LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
           WHERE m.shop_id = ? AND m.device_id = ? AND m.deleted_at IS NULL
           ORDER BY m.created_at ASC''',
        [shopId, widget.deviceId],
      );
      maintenances = rows.map(MaintenanceModel.fromMap).toList();

      // Load customer phone for WhatsApp
      final cRows = await _db.rawQuery(
        'SELECT name, phone FROM customers WHERE shop_id = ? AND id = ? LIMIT 1',
        [shopId, device.customerId],
      );
      if (cRows.isNotEmpty) {
        phone = cRows.first['phone'] as String?;
        name = cRows.first['name'] as String?;
      }
    }

    final notificationRows = await _db.rawQuery(
      '''SELECT COUNT(*) AS cnt FROM notifications
         WHERE shop_id = ? AND reference_type = 'device' AND reference_id = ? AND is_read = 0''',
      [await _db.getCurrentShopId(), widget.deviceId],
    );
    final unread = notificationRows.isEmpty
        ? 0
        : (notificationRows.first['cnt'] as num?)?.toInt() ?? 0;

    if (mounted) {
      setState(() {
        _device = device;
        _maintenances = maintenances;
        _customerPhone = phone;
        _customerName = name;
        _unreadDeviceNotifications = unread;
        _loading = false;
      });
      _syncFlash();
    }
  }

  void _openMaintenanceForm() {
    final device = _device;
    if (device == null) return;
    context.go(
        '/maintenance/new?customerId=${device.customerId}&deviceId=${device.id}');
  }

  void _syncFlash() {
    _flashTimer?.cancel();
    if (_unreadDeviceNotifications <= 0) {
      _flash = false;
      return;
    }
    _flashTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => _flash = !_flash);
    });
  }

  // ── WhatsApp: send ready message ──────────────────────────────────────────
  Future<void> _sendWhatsAppReady(MaintenanceModel m) async {
    final rawPhone = _customerPhone ?? '';
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('لا يوجد رقم جوال مسجل للعميل', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final deviceName = _device?.displayName ?? '';
    final customerName = _customerName ?? 'عزيزي العميل';
    await WhatsAppLauncher.send(
      phone: rawPhone,
      message: 'السلام عليكم $customerName 🌟\n'
          'نود إعلامكم بأن جهازكم $deviceName قد تم إصلاحه وأصبح جاهزاً للاستلام.\n'
          'رقم تذكرة الصيانة: ${m.ticketNumber}\n'
          'يسعدنا خدمتكم في أي وقت 🙏\n'
          '— فريق ProShop',
    );
  }

  // ── Add notification dialog with colored priority chips ───────────────────
  Future<void> _showAddNotificationDialog() async {
    final device = _device;
    if (device == null) return;
    final titleCtrl =
        TextEditingController(text: 'تنبيه للجهاز ${device.displayName}');
    final messageCtrl = TextEditingController();
    String priority = AppConstants.priorityHigh;
    // Which chip is selected – maps to a label for UX
    String selectedChip = 'high';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDlg) => AlertDialog(
          title: Text('إضافة تنبيه للجوال',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Priority color chips ─────────────────────────────────
                Text('نوع الحالة:',
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PriorityChip(
                      label: 'جاهز',
                      sublabel: 'للاستلام',
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                      selected: selectedChip == 'ready',
                      onTap: () => setDlg(() {
                        selectedChip = 'ready';
                        priority = AppConstants.priorityHigh;
                        if (titleCtrl.text.isEmpty ||
                            titleCtrl.text.startsWith('تنبيه للجهاز')) {
                          titleCtrl.text =
                              '✅ ${device.displayName} جاهز للاستلام';
                          messageCtrl.text =
                              'الجهاز جاهز للاستلام. يرجى التواصل مع العميل.';
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: 'تحت',
                      sublabel: 'الصيانة',
                      color: AppColors.error,
                      icon: Icons.build_rounded,
                      selected: selectedChip == 'maintenance',
                      onTap: () => setDlg(() {
                        selectedChip = 'maintenance';
                        priority = AppConstants.priorityCritical;
                        if (titleCtrl.text.isEmpty ||
                            titleCtrl.text.startsWith('تنبيه للجهاز')) {
                          titleCtrl.text =
                              '🔧 ${device.displayName} تحت الصيانة';
                          messageCtrl.text = 'الجهاز حالياً تحت الصيانة.';
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: 'انتظار',
                      sublabel: 'قطعة',
                      color: AppColors.warning,
                      icon: Icons.hourglass_top_rounded,
                      selected: selectedChip == 'waiting',
                      onTap: () => setDlg(() {
                        selectedChip = 'waiting';
                        priority = AppConstants.priorityMedium;
                        if (titleCtrl.text.isEmpty ||
                            titleCtrl.text.startsWith('تنبيه للجهاز')) {
                          titleCtrl.text =
                              '⏳ ${device.displayName} بانتظار قطعة';
                          messageCtrl.text = 'الجهاز بانتظار توفر قطعة الغيار.';
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: 'عام',
                      sublabel: 'تنبيه',
                      color: AppColors.primary,
                      icon: Icons.notifications_rounded,
                      selected: selectedChip == 'high',
                      onTap: () => setDlg(() {
                        selectedChip = 'high';
                        priority = AppConstants.priorityHigh;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Title ────────────────────────────────────────────────
                TextField(
                  controller: titleCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'عنوان التنبيه',
                    labelStyle: GoogleFonts.cairo(),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Message ──────────────────────────────────────────────
                TextField(
                  controller: messageCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'نص التنبيه',
                    labelStyle: GoogleFonts.cairo(),
                    hintText: 'تفاصيل إضافية...',
                    hintStyle: GoogleFonts.cairo(
                        color: AppColors.lightTextSecondary, fontSize: 12),
                  ),
                ),

                // ── WhatsApp quick-send (if ready chip selected) ─────────
                if (selectedChip == 'ready' && _customerPhone != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_rounded,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إرسال إشعار واتساب للعميل تلقائياً بعد الحفظ',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedChip == 'ready'
                    ? AppColors.success
                    : selectedChip == 'maintenance'
                        ? AppColors.error
                        : selectedChip == 'waiting'
                            ? AppColors.warning
                            : AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final message = messageCtrl.text.trim();
                if (title.isEmpty) return;
                await NotificationsRepository().addDeviceNotification(
                  deviceId: device.id,
                  title: title,
                  message: message.isEmpty
                      ? 'تنبيه للجهاز ${device.displayName}'
                      : message,
                  priority: priority,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              icon: const Icon(Icons.notifications_active_rounded),
              label: Text('حفظ التنبيه', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    messageCtrl.dispose();
    if (saved == true && mounted) {
      context.read<NotificationsCubit>().loadNotifications();
      await _load();
    }
  }

  Future<void> _confirmDeleteDevice() async {
    final device = _device;
    if (device == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'حذف الجوال؟',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.phone_disabled_rounded,
                    color: AppColors.error,
                  ),
                ),
                title: Text(
                  device.displayName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  device.imei?.trim().isNotEmpty == true
                      ? 'IMEI: ${device.imei}'
                      : 'بدون IMEI',
                  style: GoogleFonts.cairo(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم إخفاء هذا الجوال من القوائم، مع بقاء سجل الصيانة محفوظًا.',
                style: GoogleFonts.cairo(
                  color: AppColors.lightTextSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_rounded),
            label: Text(
              'حذف الجوال',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _devicesRepo.delete(device.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الجوال', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الجوال: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if any maintenance is ready for WhatsApp button
    final readyMaintenance = _maintenances.cast<MaintenanceModel?>().firstWhere(
          (m) => m?.status == 'ready',
          orElse: () => null,
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            _device?.displayName ?? 'تفاصيل الجهاز',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          actions: [
            if (_device != null)
              IconButton(
                icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
                tooltip: 'إضافة تنبيه للجوال',
                onPressed: _showAddNotificationDialog,
              ),
            if (_device != null)
              IconButton(
                icon: const Icon(Icons.add_task_rounded, color: Colors.white),
                tooltip: 'إضافة صيانة',
                onPressed: _openMaintenanceForm,
              ),
            if (_device != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () async {
                  await context
                      .push('/customers/${_device!.customerId}/devices/new');
                  _load();
                },
              ),
            if (_device != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white),
                tooltip: 'حذف الجوال',
                onPressed: _confirmDeleteDevice,
              ),
          ],
        ),
        floatingActionButton: _device == null
            ? null
            : readyMaintenance != null
                // WhatsApp FAB when device is ready
                ? FloatingActionButton.extended(
                    onPressed: () => _sendWhatsAppReady(readyMaintenance),
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.chat_rounded),
                    label: Text('إرسال واتساب - جاهز',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  )
                : FloatingActionButton.extended(
                    onPressed: _openMaintenanceForm,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('إضافة صيانة',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _device == null
                ? Center(
                    child: Text(
                      'لم يتم العثور على الجهاز',
                      style: GoogleFonts.cairo(
                          color: AppColors.lightTextSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ready banner
                        if (readyMaintenance != null)
                          _ReadyBanner(
                            deviceName: _device!.displayName,
                            onWhatsApp: () =>
                                _sendWhatsAppReady(readyMaintenance),
                          ),
                        if (readyMaintenance != null)
                          const SizedBox(height: 12),

                        _DeviceInfoCard(
                          device: _device!,
                          customerName: _customerName,
                          customerPhone: _customerPhone,
                          onAddNotification: _showAddNotificationDialog,
                        ),
                        if (_unreadDeviceNotifications > 0) ...[
                          const SizedBox(height: 12),
                          _DeviceNotificationBanner(
                            count: _unreadDeviceNotifications,
                            flash: _flash,
                            onTap: () => context.go('/notifications'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'سجل الصيانة',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_maintenances.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.build_outlined,
                                    size: 48,
                                    color: AppColors.lightTextSecondary
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'لا يوجد سجل صيانة لهذا الجهاز',
                                    style: GoogleFonts.cairo(
                                      color: AppColors.lightTextSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          _MaintenanceTimeline(
                            maintenances: _maintenances,
                            onWhatsApp: readyMaintenance != null
                                ? () => _sendWhatsAppReady(readyMaintenance)
                                : null,
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ready banner – shown at top when device is ready
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyBanner extends StatelessWidget {
  final String deviceName;
  final VoidCallback onWhatsApp;
  const _ReadyBanner({required this.deviceName, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.15),
            AppColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onWhatsApp,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 26),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.85, end: 1.15, duration: 800.ms),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ الجهاز جاهز للاستلام!',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'اضغط لإرسال رسالة واتساب للعميل',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'واتساب',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Priority chip
// ─────────────────────────────────────────────────────────────────────────────

class _PriorityChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.cairo(
                fontSize: 9,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification banner
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceNotificationBanner extends StatelessWidget {
  final int count;
  final bool flash;
  final VoidCallback onTap;

  const _DeviceNotificationBanner({
    required this.count,
    required this.flash,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = flash ? AppColors.error : AppColors.warning;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: color.withValues(alpha: flash ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: flash ? 2 : 1),
        boxShadow: flash
            ? [
                BoxShadow(
                  color: AppColors.error.withAlpha(110),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'يوجد $count تنبيه غير مقروء لهذا الجوال',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightText,
                  ),
                ),
              ),
              Text(
                'فتح التنبيهات',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_left_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device info card
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceInfoCard extends StatelessWidget {
  final DeviceModel device;
  final String? customerName;
  final String? customerPhone;
  final VoidCallback onAddNotification;

  const _DeviceInfoCard({
    required this.device,
    required this.onAddNotification,
    this.customerName,
    this.customerPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.phone_android_rounded,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.brand,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      Text(
                        device.model,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.lightText,
                        ),
                      ),
                      if (customerName != null)
                        Text(
                          '👤 $customerName',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.lightDivider),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                if (device.imei != null)
                  _InfoItem(
                      icon: Icons.fingerprint,
                      label: 'IMEI',
                      value: device.imei!),
                if (device.serialNumber != null)
                  _InfoItem(
                      icon: Icons.tag,
                      label: 'الرقم التسلسلي',
                      value: device.serialNumber!),
                if (device.color != null)
                  _InfoItem(
                      icon: Icons.palette_outlined,
                      label: 'اللون',
                      value: device.color!),
                if (device.storage != null)
                  _InfoItem(
                      icon: Icons.storage_outlined,
                      label: 'السعة',
                      value: device.storage!),
                if (customerPhone != null)
                  _InfoItem(
                      icon: Icons.phone_rounded,
                      label: 'جوال العميل',
                      value: customerPhone!),
              ],
            ),
            if (device.notes != null && device.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.lightDivider),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined,
                      size: 16, color: AppColors.lightTextSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      device.notes!,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAddNotification,
              icon: const Icon(Icons.add_alert_rounded),
              label: Text('إضافة تنبيه للجوال',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.cairo(
                        fontSize: 10, color: AppColors.lightTextSecondary)),
                Text(value,
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightText),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Maintenance timeline
// ─────────────────────────────────────────────────────────────────────────────

class _MaintenanceTimeline extends StatelessWidget {
  final List<MaintenanceModel> maintenances;
  final VoidCallback? onWhatsApp;
  const _MaintenanceTimeline({required this.maintenances, this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(maintenances.length, (i) {
        final m = maintenances[i];
        final isLast = i == maintenances.length - 1;
        final date = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
        final isReady = m.status == 'ready';

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline indicator
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: m.statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: m.statusColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    )
                        .animate(
                            onPlay:
                                isReady ? (c) => c.repeat(reverse: true) : null)
                        .scaleXY(
                            begin: isReady ? 0.7 : 1.0,
                            end: isReady ? 1.4 : 1.0,
                            duration: 700.ms),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.lightDivider,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Card(
                    elevation: isReady ? 3 : 1,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isReady
                          ? BorderSide(
                              color: AppColors.success.withValues(alpha: 0.6),
                              width: 1.5)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/maintenance/${m.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        m.statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    m.statusLabel,
                                    style: GoogleFonts.cairo(
                                      color: m.statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${m.totalCost.toStringAsFixed(0)} ر.س',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'صيانة رقم ${i + 1}',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.lightText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '#${m.ticketNumber}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              m.faultDescription,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.lightTextSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                                if (isReady && onWhatsApp != null) ...[
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: onWhatsApp,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.chat_rounded,
                                              color: Colors.white, size: 13),
                                          const SizedBox(width: 4),
                                          Text(
                                            'واتساب',
                                            style: GoogleFonts.cairo(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (m.warrantyExpiryApproved) ...[
                              const SizedBox(height: 5),
                              _WarrantyExpiredMiniStamp(maintenance: m),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _WarrantyExpiredMiniStamp extends StatelessWidget {
  final MaintenanceModel maintenance;
  const _WarrantyExpiredMiniStamp({required this.maintenance});

  @override
  Widget build(BuildContext context) {
    String fmt(int? ms) {
      if (ms == null) return 'غير محدد';
      final date = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        'انتهى الضمان - النهاية: ${fmt(maintenance.warrantyEnd)} - الاعتماد: ${fmt(maintenance.warrantyExpiryApprovedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cairo(
          color: AppColors.error,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
