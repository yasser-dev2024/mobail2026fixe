import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../customers/data/customer_model.dart';
import '../../../customers/data/customers_repository.dart';
import '../../../device_photos/data/device_photo_model.dart';
import '../../../device_photos/data/device_photo_repository.dart';
import '../../../devices/data/device_model.dart';
import '../../../devices/data/devices_repository.dart';
import '../../../warranty/data/warranty_model.dart';
import '../../../warranty/presentation/widgets/warranty_alert_action_dialog.dart';
import '../../data/repair_board_repository.dart';

const _receiveGraphicAsset = 'assets/images/workflow_receive.png';
const _repairGraphicAsset = 'assets/images/workflow_repair.png';
const _deliveryGraphicAsset = 'assets/images/workflow_delivery.png';
const _warrantyGraphicAsset = 'assets/images/workflow_warranty.png';

double _dialogWidthFor(BuildContext context, double maxWidth) {
  final available = MediaQuery.sizeOf(context).width - 48;
  return available.clamp(280.0, maxWidth).toDouble();
}

double _dialogHeightFor(BuildContext context, double maxHeight) {
  final available = MediaQuery.sizeOf(context).height - 170;
  return available.clamp(360.0, maxHeight).toDouble();
}

Future<String?> _captureCameraImage(BuildContext context) async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    return file?.path;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر فتح الكاميرا: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return null;
  }
}

class RepairBoardScreen extends StatefulWidget {
  const RepairBoardScreen({super.key});

  @override
  State<RepairBoardScreen> createState() => _RepairBoardScreenState();
}

class _RepairBoardScreenState extends State<RepairBoardScreen> {
  final _repo = RepairBoardRepository();
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;
  RepairBoardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.loadBoard(search: _searchCtrl.text);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _receiveNewDevice({CustomerModel? customer}) async {
    final data = await showDialog<RepairIntakeData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IntakeDialog(initialCustomer: customer),
    );
    if (data == null) return;

    await _runAction(
      () => _repo.receiveNewDevice(data),
      success: 'تم استلام الجهاز وظهر في الشاشة الرئيسية.',
    );
  }

  Future<void> _createBackup() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد حفظ النسخة الاحتياطية',
    );
    if (directory == null) return;

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(
      directory,
      'ProShop_Backup_$stamp${AppConstants.backupExtension}',
    );

    await _runAction(
      () async {
        final service = BackupService();
        final ok = await service.createBackup(filePath);
        if (!ok) {
          throw Exception(
            service.lastError ?? 'تعذر إنشاء النسخة الاحتياطية.',
          );
        }
        return ok;
      },
      success: 'تم إنشاء النسخة الاحتياطية: ${p.basename(filePath)}',
      reload: false,
    );
  }

  Future<void> _openDevice(RepairDeviceCard card) async {
    final status = card.maintenance.status;
    if (status == AppConstants.statusReady) {
      await _confirmDelivery(card);
      return;
    }

    final action = await showDialog<_DeviceAction>(
      context: context,
      builder: (_) => _DeviceActionDialog(card: card),
    );
    if (action == null) return;
    if (!mounted) return;

    switch (action) {
      case _DeviceAction.underRepair:
        final note = await showDialog<String>(
          context: context,
          builder: (_) => const _ShortNoteDialog(
            title: 'تحت الصيانة',
            label: 'ملاحظة قصيرة اختيارية',
            buttonLabel: 'حفظ الحالة',
          ),
        );
        if (note == null) return;
        await _runAction(
          () => _repo.markUnderRepair(card.maintenance.id, note: note),
          success: 'تم تغيير الحالة إلى تحت الصيانة.',
        );
        break;
      case _DeviceAction.needsPart:
        final part = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _ShortNoteDialog(
            title: 'يحتاج قطع غيار',
            label: 'اسم القطعة المطلوبة أو وصفها',
            buttonLabel: 'حفظ الحالة',
            requiredValue: true,
          ),
        );
        if (part == null) return;
        await _runAction(
          () => _repo.markNeedsPart(
            maintenanceId: card.maintenance.id,
            partName: part,
          ),
          success: 'تم حفظ القطعة المطلوبة وتجهيز رسالة واتساب.',
        );
        break;
      case _DeviceAction.ready:
        final payload = await showDialog<_ReadyPayload>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _ReadyDialog(),
        );
        if (payload == null) return;
        await _runAction(
          () => _repo.markReady(
            maintenanceId: card.maintenance.id,
            repairDetails: payload.repairDetails,
            changedPart: payload.changedPart,
            cost: payload.cost,
            warrantyDays: payload.warrantyDays,
            notes: payload.notes,
            afterImagePaths: payload.imagePaths,
          ),
          success: 'تم جعل الجهاز جاهزاً وتجهيز رسالة واتساب للعميل.',
        );
        break;
    }
  }

  Future<void> _confirmDelivery(RepairDeviceCard card) async {
    final payload = await showDialog<_DeliveryPayload>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeliveryDialog(card: card),
    );
    if (payload == null) return;

    await _runAction(
      () => _repo.confirmDelivery(
        maintenanceId: card.maintenance.id,
        paidAmount: payload.paidAmount,
        warrantyDays: payload.warrantyDays,
        deliveryCondition: payload.deliveryCondition,
        receiverName: payload.receiverName,
        warrantyTerms: payload.warrantyTerms,
        notes: payload.notes,
      ),
      success: 'تم تأكيد التسليم وبدأ الضمان من تاريخ اليوم.',
    );
  }

  Future<void> _receiveUnderWarranty(WarrantyModel warranty) async {
    final payload = await showDialog<_WarrantyReturnPayload>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WarrantyReturnDialog(warranty: warranty),
    );
    if (payload == null) return;

    await _runAction(
      () => _repo.receiveUnderWarranty(
        warranty: warranty,
        problem: payload.problem,
        customerDescription: payload.customerDescription,
        deviceCondition: payload.deviceCondition,
        employeeNotes: payload.employeeNotes,
        imagePaths: payload.imagePaths,
      ),
      success: 'تم استلام الجهاز تحت الضمان وظهر في تنبيهات المحل.',
    );
  }

  Future<void> _sendReadyWhatsapp(RepairDeviceCard card) async {
    await _runAction(
      () => _repo.sendReadyWhatsapp(card.maintenance.id),
      success: 'تم فتح واتساب برسالة الجاهزية.',
      reload: false,
    );
  }

  Future<void> _sendWarrantyClaimWhatsapp(RepairDeviceCard card) async {
    await _runAction(
      () => _repo.sendWarrantyClaimWhatsapp(card.maintenance.id),
      success: 'تم فتح واتساب برسالة الضمان.',
      reload: false,
    );
  }

  Future<void> _sendWarrantyWhatsapp(WarrantyModel warranty) async {
    await _runAction(
      () => _repo.sendWarrantyWhatsapp(warranty),
      success: 'تم تجهيز PDF الضمان وفتح واتساب مع الملف المرفق.',
      reload: false,
    );
  }

  Future<void> _manageWarrantyAlert(WarrantyModel warranty) async {
    final changed = await showWarrantyAlertActionDialog(
      context,
      warrantyId: warranty.id,
    );
    if (changed == true) await _load();
  }

  Future<void> _confirmDeleteCustomer({
    required String customerId,
    required String customerName,
    String? customerPhone,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'حذف العميل؟',
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
                    Icons.person_remove_rounded,
                    color: AppColors.error,
                  ),
                ),
                title: Text(
                  customerName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(customerPhone ?? '', style: GoogleFonts.cairo()),
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم إخفاء العميل وأجهزته من القوائم، مع بقاء سجلات الصيانة والفواتير محفوظة.',
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
              'حذف العميل',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(
      () => _repo.deleteCustomer(customerId),
      success: 'تم حذف العميل',
    );
  }

  Future<void> _confirmDeleteDevice(RepairDeviceCard card) async {
    final deviceId = card.maintenance.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن حذف جوال بدون ملف جهاز مرتبط.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final deviceName = '${card.maintenance.brand} ${card.maintenance.model}';
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
                  deviceName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  card.maintenance.customerName ?? 'عميل',
                  style: GoogleFonts.cairo(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم إخفاء الجوال من القوائم، مع بقاء سجل الصيانة محفوظًا.',
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
    if (confirmed != true) return;

    await _runAction(
      () => _repo.deleteDevice(deviceId),
      success: 'تم حذف الجوال',
    );
  }

  Future<void> _runAction(
    Future<Object?> Function() action, {
    required String success,
    bool reload = true,
  }) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
      if (reload) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final data = _data;

    return Scaffold(
      backgroundColor: colors.background,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _BoardHeader(
              searchCtrl: _searchCtrl,
              onSearchChanged: _onSearchChanged,
              onReceive: () => _receiveNewDevice(),
              onRefresh: _load,
              onBackup: _createBackup,
            ),
            const SizedBox(height: 14),
            if (!_loading && data != null && data.customerResults.isNotEmpty)
              SizedBox(
                height: 116,
                child: _CustomerResultsSection(
                  customers: data.customerResults,
                  onOpenCustomer: (customer) =>
                      context.push('/customers/${customer.id}'),
                  onAddDevice: (customer) =>
                      _receiveNewDevice(customer: customer),
                  onDeleteCustomer: (customer) => _confirmDeleteCustomer(
                    customerId: customer.id,
                    customerName: customer.name,
                    customerPhone: customer.phone,
                  ),
                ),
              ),
            if (!_loading && data != null && data.customerResults.isNotEmpty)
              const SizedBox(height: 14),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: _ErrorView(message: _error!, onRetry: _load),
              )
            else if (data != null)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 980) {
                      return ListView(
                        children: [
                          SizedBox(
                            height: 560,
                            child: _ActiveDevicesSection(
                              items: data.activeDevices,
                              onOpen: _openDevice,
                              onReadyWhatsapp: _sendReadyWhatsapp,
                              onWarrantyWhatsapp: _sendWarrantyClaimWhatsapp,
                              onDeleteDevice: _confirmDeleteDevice,
                              onDeleteCustomer: (group) =>
                                  _confirmDeleteCustomer(
                                customerId: group.customerId,
                                customerName: group.customerName,
                                customerPhone: group.customerPhone,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 520,
                            child: _WarrantySection(
                              warranties: data.warranties,
                              activeMaintenanceIds: data.activeMaintenanceIds,
                              onReceiveUnderWarranty: _receiveUnderWarranty,
                              onWarrantyWhatsapp: _sendWarrantyWhatsapp,
                              onManage: _manageWarrantyAlert,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _ActiveDevicesSection(
                            items: data.activeDevices,
                            onOpen: _openDevice,
                            onReadyWhatsapp: _sendReadyWhatsapp,
                            onWarrantyWhatsapp: _sendWarrantyClaimWhatsapp,
                            onDeleteDevice: _confirmDeleteDevice,
                            onDeleteCustomer: (group) => _confirmDeleteCustomer(
                              customerId: group.customerId,
                              customerName: group.customerName,
                              customerPhone: group.customerPhone,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 390,
                          child: _WarrantySection(
                            warranties: data.warranties,
                            activeMaintenanceIds: data.activeMaintenanceIds,
                            onReceiveUnderWarranty: _receiveUnderWarranty,
                            onWarrantyWhatsapp: _sendWarrantyWhatsapp,
                            onManage: _manageWarrantyAlert,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onReceive;
  final VoidCallback onRefresh;
  final VoidCallback onBackup;

  const _BoardHeader({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onReceive,
    required this.onRefresh,
    required this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    Widget receiveButton({bool compact = false}) {
      return SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onReceive,
          style: compact
              ? ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                )
              : null,
          icon: const Icon(Icons.add_circle_rounded, size: 23),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'استلام جوال جديد',
              maxLines: 1,
              style: GoogleFonts.cairo(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    Widget backupButton({bool compact = false}) {
      return SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onBackup,
          style: compact
              ? OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                )
              : null,
          icon: const Icon(Icons.backup_rounded),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'نسخ احتياطي',
              maxLines: 1,
              style: GoogleFonts.cairo(
                fontSize: compact ? 13 : null,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    Widget searchField() {
      return SizedBox(
        height: 52,
        child: TextField(
          controller: searchCtrl,
          onChanged: onSearchChanged,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'بحث واحد: اسم العميل، رقم الجوال، الجهاز، رقم الطلب...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchCtrl.text.isEmpty
                ? IconButton(
                    tooltip: 'تحديث',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  )
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      searchCtrl.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final stackButtons = constraints.maxWidth < 360;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stackButtons) ...[
                receiveButton(compact: true),
                const SizedBox(height: 8),
                backupButton(compact: true),
              ] else
                Row(
                  children: [
                    Expanded(child: receiveButton(compact: true)),
                    const SizedBox(width: 8),
                    Expanded(child: backupButton(compact: true)),
                  ],
                ),
              const SizedBox(height: 8),
              searchField(),
            ],
          );
        }

        return Row(
          children: [
            receiveButton(),
            const SizedBox(width: 8),
            backupButton(),
            const SizedBox(width: 12),
            Expanded(child: searchField()),
          ],
        );
      },
    );
  }
}

class _CustomerResultsSection extends StatelessWidget {
  final List<RepairCustomerResult> customers;
  final ValueChanged<CustomerModel> onOpenCustomer;
  final ValueChanged<CustomerModel> onAddDevice;
  final ValueChanged<CustomerModel> onDeleteCustomer;

  const _CustomerResultsSection({
    required this.customers,
    required this.onOpenCustomer,
    required this.onAddDevice,
    required this.onDeleteCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_search_rounded,
                    color: AppColors.primary),
                const SizedBox(height: 4),
                Text(
                  'ملفات العملاء',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: customers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final result = customers[index];
                return _CustomerResultCard(
                  result: result,
                  onOpen: () => onOpenCustomer(result.customer),
                  onAddDevice: () => onAddDevice(result.customer),
                  onDelete: () => onDeleteCustomer(result.customer),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerResultCard extends StatelessWidget {
  final RepairCustomerResult result;
  final VoidCallback onOpen;
  final VoidCallback onAddDevice;
  final VoidCallback onDelete;

  const _CustomerResultCard({
    required this.result,
    required this.onOpen,
    required this.onAddDevice,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final customer = result.customer;
    return Container(
      width: 330,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              customer.name.isEmpty ? '?' : customer.name[0],
              style: GoogleFonts.cairo(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  [customer.phone, customer.phone2]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(' / '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${result.deviceCount} أجهزة - ${result.maintenanceCount} صيانة',
                  style: GoogleFonts.cairo(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'حذف العميل',
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 19,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: onOpen,
                  child:
                      Text('فتح الملف', style: GoogleFonts.cairo(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: onAddDevice,
                  child: Text('إضافة جوال',
                      style: GoogleFonts.cairo(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDevicesSection extends StatelessWidget {
  final List<RepairDeviceCard> items;
  final ValueChanged<RepairDeviceCard> onOpen;
  final ValueChanged<RepairDeviceCard> onReadyWhatsapp;
  final ValueChanged<RepairDeviceCard> onWarrantyWhatsapp;
  final ValueChanged<RepairDeviceCard> onDeleteDevice;
  final ValueChanged<_RepairCustomerGroup> onDeleteCustomer;

  const _ActiveDevicesSection({
    required this.items,
    required this.onOpen,
    required this.onReadyWhatsapp,
    required this.onWarrantyWhatsapp,
    required this.onDeleteDevice,
    required this.onDeleteCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final groups = _RepairCustomerGroup.fromCards(items);
    return _Panel(
      title: 'تنبيهات الأجهزة الموجودة في المحل',
      subtitle:
          '${groups.length} عميل - ${items.length} جهاز ظاهر حتى يتم تسليمه',
      child: groups.isEmpty
          ? const _EmptyHint(
              icon: Icons.task_alt_rounded,
              title: 'لا توجد أجهزة داخل المحل الآن',
              subtitle: 'استلم جهازاً جديداً ليظهر هنا مباشرة.',
            )
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    colors.background,
                    AppColors.primary.withValues(alpha: 0.045),
                    AppColors.warning.withValues(alpha: 0.035),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 430,
                  mainAxisExtent: 296,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _MotionIn(
                    delay: Duration(
                      milliseconds: 45 * (index > 8 ? 8 : index),
                    ),
                    child: _RepairCustomerCard(
                      group: group,
                      onOpen: () => _openCustomerDevices(context, group),
                      onDelete: () => onDeleteCustomer(group),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openCustomerDevices(
    BuildContext context,
    _RepairCustomerGroup group,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CustomerDevicesDialog(
        group: group,
        onOpen: (card) {
          Navigator.pop(dialogContext);
          onOpen(card);
        },
        onReadyWhatsapp: (card) {
          Navigator.pop(dialogContext);
          onReadyWhatsapp(card);
        },
        onWarrantyWhatsapp: (card) {
          Navigator.pop(dialogContext);
          onWarrantyWhatsapp(card);
        },
        onDeleteDevice: (card) {
          Navigator.pop(dialogContext);
          onDeleteDevice(card);
        },
      ),
    );
  }
}

class _RepairCustomerGroup {
  final String customerId;
  final List<RepairDeviceCard> cards;

  const _RepairCustomerGroup({
    required this.customerId,
    required this.cards,
  });

  static List<_RepairCustomerGroup> fromCards(List<RepairDeviceCard> items) {
    final grouped = <String, List<RepairDeviceCard>>{};
    for (final item in items) {
      final key = item.maintenance.customerId.trim().isEmpty
          ? item.maintenance.id
          : item.maintenance.customerId;
      grouped.putIfAbsent(key, () => <RepairDeviceCard>[]).add(item);
    }

    final groups = grouped.entries.map((entry) {
      final sortedCards = [...entry.value]..sort((a, b) {
          final priority = _cardPriority(a).compareTo(_cardPriority(b));
          if (priority != 0) return priority;
          return b.maintenance.updatedAt.compareTo(a.maintenance.updatedAt);
        });
      return _RepairCustomerGroup(
        customerId: entry.key,
        cards: List.unmodifiable(sortedCards),
      );
    }).toList();

    groups.sort((a, b) {
      final priority =
          _cardPriority(a.leadCard).compareTo(_cardPriority(b.leadCard));
      if (priority != 0) return priority;
      return b.leadCard.maintenance.updatedAt
          .compareTo(a.leadCard.maintenance.updatedAt);
    });
    return groups;
  }

  RepairDeviceCard get leadCard => cards.first;

  String get customerName {
    final name = leadCard.maintenance.customerName?.trim() ?? '';
    return name.isEmpty ? 'عميل' : name;
  }

  String? get customerPhone {
    final phone = leadCard.maintenance.customerPhone?.trim() ?? '';
    return phone.isEmpty ? null : phone;
  }

  int get deviceCount {
    final ids = cards.map((card) {
      final deviceId = card.maintenance.deviceId?.trim() ?? '';
      if (deviceId.isNotEmpty) return deviceId;
      return '${card.maintenance.brand}|${card.maintenance.model}|${card.maintenance.imei ?? card.maintenance.id}';
    }).toSet();
    return ids.length;
  }

  int get readyCount => cards
      .where((card) => card.maintenance.status == AppConstants.statusReady)
      .length;

  String get latestProblem =>
      leadCard.latestWarrantyProblem ?? leadCard.maintenance.faultDescription;
}

class _RepairCustomerCard extends StatelessWidget {
  final _RepairCustomerGroup group;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _RepairCustomerCard({
    required this.group,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = _cardColor(group.leadCard);
    final title = _cardTitle(group.leadCard);

    return _HoverLift(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: _BlinkingAlertFrame(
          color: color,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  color.withValues(alpha: 0.14),
                  colors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: color.withValues(alpha: 0.42), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _WorkflowThumb(
                      asset: _workflowAssetForCard(group.leadCard),
                      color: color,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          if (group.customerPhone != null)
                            Text(
                              group.customerPhone!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'حذف العميل',
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ReceiverRibbon(name: _receiverName(group.leadCard)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _InfoPill(
                      icon: Icons.phone_android_rounded,
                      text: '${group.deviceCount} أجهزة',
                    ),
                    _InfoPill(
                      icon: Icons.build_circle_rounded,
                      text: '${group.cards.length} صيانة',
                    ),
                    if (group.readyCount > 0)
                      _InfoPill(
                        icon: Icons.task_alt_rounded,
                        text: '${group.readyCount} جاهز',
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                _SmallBadge(label: title, color: color),
                const SizedBox(height: 6),
                Text(
                  group.latestProblem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'فتح الجوالات',
                        maxLines: 1,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerDevicesDialog extends StatelessWidget {
  final _RepairCustomerGroup group;
  final ValueChanged<RepairDeviceCard> onOpen;
  final ValueChanged<RepairDeviceCard> onReadyWhatsapp;
  final ValueChanged<RepairDeviceCard> onWarrantyWhatsapp;
  final ValueChanged<RepairDeviceCard> onDeleteDevice;

  const _CustomerDevicesDialog({
    required this.group,
    required this.onOpen,
    required this.onReadyWhatsapp,
    required this.onWarrantyWhatsapp,
    required this.onDeleteDevice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dialogWidth = _dialogWidthFor(context, 920);
    final dialogHeight = _dialogHeightFor(context, 620);

    return AlertDialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: _DialogTitle('أجهزة ${group.customerName}'),
      content: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              colors.background,
              AppColors.primary.withValues(alpha: 0.055),
              AppColors.success.withValues(alpha: 0.045),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (group.customerPhone != null)
                  _InfoPill(
                    icon: Icons.phone_rounded,
                    text: group.customerPhone!,
                  ),
                _InfoPill(
                  icon: Icons.phone_android_rounded,
                  text: '${group.deviceCount} أجهزة',
                ),
                _InfoPill(
                  icon: Icons.build_circle_rounded,
                  text: '${group.cards.length} صيانة',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 430,
                  mainAxisExtent: 430,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: group.cards.length,
                itemBuilder: (context, index) {
                  final card = group.cards[index];
                  return _MotionIn(
                    delay: Duration(
                      milliseconds: 45 * (index > 8 ? 8 : index),
                    ),
                    child: _RepairCard(
                      card: card,
                      onPressed: () => onOpen(card),
                      onReadyWhatsapp: () => onReadyWhatsapp(card),
                      onWarrantyWhatsapp: () => onWarrantyWhatsapp(card),
                      onDelete: () => onDeleteDevice(card),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarrantySection extends StatelessWidget {
  final List<WarrantyModel> warranties;
  final Set<String> activeMaintenanceIds;
  final ValueChanged<WarrantyModel> onReceiveUnderWarranty;
  final ValueChanged<WarrantyModel> onWarrantyWhatsapp;
  final ValueChanged<WarrantyModel> onManage;

  const _WarrantySection({
    required this.warranties,
    required this.activeMaintenanceIds,
    required this.onReceiveUnderWarranty,
    required this.onWarrantyWhatsapp,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'تنبيهات الضمان',
      subtitle: '${warranties.length} سجل ضمان',
      child: warranties.isEmpty
          ? const _EmptyHint(
              icon: Icons.verified_user_outlined,
              title: 'لا توجد ضمانات',
              subtitle: 'بعد تسليم جهاز بضمان سيظهر هنا.',
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: warranties.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final warranty = warranties[index];
                final alreadyInside =
                    activeMaintenanceIds.contains(warranty.maintenanceId);
                return _WarrantyCard(
                  warranty: warranty,
                  alreadyInside: alreadyInside,
                  onReceive: warranty.status == 'expired' || alreadyInside
                      ? null
                      : () => onReceiveUnderWarranty(warranty),
                  onWhatsapp: warranty.status == 'expired'
                      ? null
                      : () => onWarrantyWhatsapp(warranty),
                  onManage: () => onManage(warranty),
                );
              },
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                flex: 0,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RepairCard extends StatelessWidget {
  final RepairDeviceCard card;
  final VoidCallback onPressed;
  final VoidCallback onReadyWhatsapp;
  final VoidCallback onWarrantyWhatsapp;
  final VoidCallback? onDelete;

  const _RepairCard({
    required this.card,
    required this.onPressed,
    required this.onReadyWhatsapp,
    required this.onWarrantyWhatsapp,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final m = card.maintenance;
    final color = _cardColor(card);
    final title = _cardTitle(card);
    final isReady = m.status == AppConstants.statusReady;
    final isWarrantyReturn = m.status == AppConstants.statusWarrantyReturn;
    final buttonLabel =
        m.status == AppConstants.statusReady ? 'تأكيد الاستلام' : 'فتح الجهاز';
    final problem = card.latestWarrantyProblem ?? m.faultDescription;

    return _HoverLift(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: _BlinkingAlertFrame(
          color: color,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  color.withValues(alpha: 0.14),
                  colors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: color.withValues(alpha: 0.42), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _WorkflowThumb(
                      asset: _workflowAssetForCard(card),
                      color: color,
                      size: 42,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (card.isWarrantyWork) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_user_rounded,
                          color: AppColors.info, size: 18),
                    ],
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112),
                      child: Text(
                        m.ticketNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'حذف الجوال',
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _ReceiverRibbon(name: _receiverName(card)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _InfoPill(
                        icon: Icons.person_rounded,
                        text: m.customerName ?? 'عميل'),
                    if (_technicianName(card) != null)
                      _InfoPill(
                        icon: Icons.engineering_rounded,
                        text: 'الفني: ${_technicianName(card)}',
                      ),
                    if ((m.customerPhone ?? '').isNotEmpty)
                      _InfoPill(
                          icon: Icons.phone_rounded, text: m.customerPhone!),
                    _InfoPill(
                      icon: Icons.phone_android_rounded,
                      text: '${m.brand} ${m.model}',
                    ),
                    _InfoPill(
                      icon: Icons.schedule_rounded,
                      text: _elapsedSince(m.receivedAt),
                    ),
                    if (card.deviceRepairCount > 1)
                      _InfoPill(
                        icon: Icons.history_rounded,
                        text: '${card.deviceRepairCount} صيانات',
                      ),
                    if (card.customerDeviceCount > 1)
                      _InfoPill(
                        icon: Icons.devices_other_rounded,
                        text: '${card.customerDeviceCount} أجهزة',
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  problem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (card.requiredParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'القطعة المطلوبة: ${card.requiredParts.join('، ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.statusWaitingPart,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (m.status == AppConstants.statusReady) ...[
                  const SizedBox(height: 4),
                  Text(
                    'جاهز منذ ${_elapsedSince(card.readyAt ?? m.updatedAt)}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            buttonLabel,
                            maxLines: 1,
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isReady || isWarrantyReturn) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 34,
                        child: _CompactOutlinedAction(
                          onPressed:
                              isReady ? onReadyWhatsapp : onWarrantyWhatsapp,
                          icon: Icons.chat_rounded,
                          label: 'واتساب',
                          height: 34,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  final WarrantyModel warranty;
  final bool alreadyInside;
  final VoidCallback? onReceive;
  final VoidCallback? onWhatsapp;
  final VoidCallback onManage;

  const _WarrantyCard({
    required this.warranty,
    required this.alreadyInside,
    required this.onReceive,
    required this.onWhatsapp,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final color = _warrantyColor(warranty.status);
    final title = _warrantyTitle(warranty.status);
    final start = _date(warranty.startDate);
    final end = _date(warranty.endDate);

    return _BlinkingAlertFrame(
      color: color,
      enabled: warranty.status != 'active' || alreadyInside,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onManage,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      warranty.customerName ?? 'عميل',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _SmallBadge(label: title, color: color, compact: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                warranty.deviceInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                runSpacing: 2,
                children: [
                  _MiniText('من: $start'),
                  _MiniText('إلى: $end'),
                  _MiniText(
                    _warrantyCountdownLabel(warranty),
                    color: color,
                  ),
                ],
              ),
              if (alreadyInside) ...[
                const SizedBox(height: 5),
                _SmallBadge(
                  label: 'الجهاز موجود حالياً في المحل',
                  color: color,
                  compact: true,
                ),
              ],
              if (onWhatsapp != null || onReceive != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (onWhatsapp != null)
                      Expanded(
                        child: _CompactOutlinedAction(
                          onPressed: onWhatsapp,
                          icon: Icons.chat_rounded,
                          label: 'واتساب الضمان',
                          height: 32,
                          fontSize: 11,
                        ),
                      ),
                    if (onWhatsapp != null && onReceive != null)
                      const SizedBox(width: 6),
                    if (onReceive != null)
                      Expanded(
                        child: _CompactOutlinedAction(
                          onPressed: onReceive,
                          icon: Icons.assignment_return_rounded,
                          label: 'استلام ضمان',
                          height: 32,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactOutlinedAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final double height;
  final double fontSize;

  const _CompactOutlinedAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.height = 40,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.1),
          padding: const EdgeInsets.symmetric(horizontal: 7),
          minimumSize: Size(0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: height <= 34 ? 14 : 16),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowThumb extends StatelessWidget {
  final String asset;
  final Color color;
  final double size;

  const _WorkflowThumb({
    required this.asset,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.phone_android_rounded, color: color, size: size * 0.5),
        ),
      ),
    );
  }
}

class _WorkflowHero extends StatelessWidget {
  final String asset;
  final Color color;
  final String title;
  final String subtitle;
  final bool compact;

  const _WorkflowHero({
    required this.asset,
    required this.color,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final imageHeight = compact ? 104.0 : 132.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: color.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Icon(
                  Icons.phone_android_rounded,
                  color: color,
                  size: 42,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
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

class _ReceiverRibbon extends StatelessWidget {
  final String name;

  const _ReceiverRibbon({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            AppColors.success,
            AppColors.success.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_ind_rounded,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'مستلم الجهاز: $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionIn extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const _MotionIn({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final total = (360 + delay.inMilliseconds).clamp(1, 1200).toDouble();
        final start = delay.inMilliseconds == 0
            ? 0.0
            : (delay.inMilliseconds / total).clamp(0.0, 0.7).toDouble();
        final progress = value <= start
            ? 0.0
            : ((value - start) / (1 - start)).clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;

  const _HoverLift({required this.child});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.018 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _hovered ? const Offset(0, -0.012) : Offset.zero,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class _MiniText extends StatelessWidget {
  final String text;
  final Color? color;

  const _MiniText(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 10,
        color: color ?? context.appColors.textSecondary,
        fontWeight: color == null ? FontWeight.w500 : FontWeight.w800,
      ),
    );
  }
}

class _BlinkingAlertFrame extends StatefulWidget {
  final Color color;
  final Widget child;
  final bool enabled;

  const _BlinkingAlertFrame({
    required this.color,
    required this.child,
    this.enabled = true,
  });

  @override
  State<_BlinkingAlertFrame> createState() => _BlinkingAlertFrameState();
}

class _BlinkingAlertFrameState extends State<_BlinkingAlertFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _BlinkingAlertFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.025 + (pulse * 0.055)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.35 + (pulse * 0.42)),
              width: 1.1 + (pulse * 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.13 + (pulse * 0.18)),
                blurRadius: 7 + (pulse * 12),
                spreadRadius: 0.5 + (pulse * 2),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final String title;

  const _DialogTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
        Tooltip(
          message: 'إغلاق',
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _IntakePhotosButton extends StatelessWidget {
  final String maintenanceId;

  const _IntakePhotosButton({required this.maintenanceId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DevicePhotoModel>>(
      future: DevicePhotoRepository().getForMaintenance(maintenanceId),
      builder: (context, snapshot) {
        final photos = (snapshot.data ?? const <DevicePhotoModel>[])
            .where((photo) => photo.stage == AppConstants.photoStageIntake)
            .toList();
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final label = photos.isEmpty
            ? 'صور الجهاز قبل الصيانة'
            : 'صور الجهاز قبل الصيانة (${photos.length})';
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: loading
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) =>
                          _IntakePhotosDialog(photos: photos),
                    ),
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_rounded),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        );
      },
    );
  }
}

class _IntakePhotosDialog extends StatelessWidget {
  final List<DevicePhotoModel> photos;

  const _IntakePhotosDialog({required this.photos});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: const _DialogTitle('صور الجهاز قبل الصيانة'),
      content: SizedBox(
        width: _dialogWidthFor(context, 680),
        height: _dialogHeightFor(context, 540),
        child: photos.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_camera_back_outlined,
                      size: 52,
                      color: context.appColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد صور محفوظة قبل الصيانة لهذا الجهاز.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: context.appColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'التقط الصور من نافذة الاستلام ليتم حفظها هنا تلقائياً.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: context.appColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return _DevicePhotoTile(photo: photo);
                },
              ),
      ),
    );
  }
}

class _DevicePhotoTile extends StatelessWidget {
  final DevicePhotoModel photo;

  const _DevicePhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final path = photo.thumbnailPath ?? photo.originalPath;
    final exists = File(path).existsSync();
    final capturedAt = DateFormat('dd/MM/yyyy HH:mm', 'ar')
        .format(DateTime.fromMillisecondsSinceEpoch(photo.capturedAt));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: exists
                ? Image.file(File(path), fit: BoxFit.cover)
                : Container(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.photoType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  capturedAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: colors.textSecondary,
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

class _PhotoSourceButtons extends StatelessWidget {
  final int count;
  final String cameraLabel;
  final String galleryLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoSourceButtons({
    required this.count,
    required this.cameraLabel,
    required this.galleryLabel,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onCamera,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(
            cameraLabel,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onGallery,
          icon: const Icon(Icons.photo_library_rounded),
          label: Text(
            galleryLabel,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(height: 8),
          Text(
            'تم اختيار $count صورة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _IntakeDialog extends StatefulWidget {
  final CustomerModel? initialCustomer;

  const _IntakeDialog({this.initialCustomer});

  @override
  State<_IntakeDialog> createState() => _IntakeDialogState();
}

class _IntakeDialogState extends State<_IntakeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerLookup = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerPhone2 = TextEditingController();
  final _receiverName = TextEditingController();
  final _deviceType = TextEditingController(text: 'جوال');
  final _company = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _imei = TextEditingController();
  final _serial = TextEditingController();
  final _lockCode = TextEditingController();
  final _accessories = TextEditingController();
  final _problem = TextEditingController();
  final _condition = TextEditingController();
  final _damage = TextEditingController();
  final _notes = TextEditingController();
  bool _works = true;
  bool _charges = true;
  bool _water = false;
  final List<String> _images = [];
  final _customersRepo = CustomersRepository();
  final _devicesRepo = DevicesRepository();
  CustomerModel? _selectedCustomer;
  String? _selectedDeviceId;
  List<CustomerModel> _customerSuggestions = [];
  List<DeviceModel> _customerDevices = [];
  List<String> _receiverNames = [];
  bool _loadingDevices = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.initialCustomer;
    if (customer != null) {
      _applyCustomer(customer);
      _loadCustomerDevices(customer.id);
    }
    _loadDefaultReceiverName();
  }

  Future<void> _loadDefaultReceiverName() async {
    final settings = SettingsService();
    await settings.load();
    final currentUser = AuthRepository().getCurrentUser();
    final fallbackName = currentUser?.name.trim().isNotEmpty == true
        ? currentUser!.name.trim()
        : (currentUser?.username.trim() ?? '');
    final names = settings.deviceReceiverNames.toList();
    if (names.isEmpty && fallbackName.isNotEmpty) {
      names.add(fallbackName);
    }
    final defaultName = names.isNotEmpty ? names.first : fallbackName;
    if (!mounted) return;
    setState(() {
      _receiverNames = names;
      if (_receiverName.text.trim().isEmpty) {
        _receiverName.text = defaultName;
      }
    });
  }

  @override
  void dispose() {
    _customerLookup.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _customerPhone2.dispose();
    _receiverName.dispose();
    _deviceType.dispose();
    _company.dispose();
    _model.dispose();
    _color.dispose();
    _imei.dispose();
    _serial.dispose();
    _lockCode.dispose();
    _accessories.dispose();
    _problem.dispose();
    _condition.dispose();
    _damage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _customerSuggestions = []);
      return;
    }
    final results = await _customersRepo.getAll(search: query.trim());
    if (!mounted) return;
    setState(() => _customerSuggestions = results.take(8).toList());
  }

  Future<void> _loadCustomerDevices(String customerId) async {
    setState(() => _loadingDevices = true);
    final devices = await _devicesRepo.getByCustomer(customerId);
    if (!mounted) return;
    setState(() {
      _customerDevices = devices;
      _loadingDevices = false;
    });
  }

  void _applyCustomer(CustomerModel customer) {
    setState(() {
      _selectedCustomer = customer;
      _selectedDeviceId = null;
      _customerLookup.text = '${customer.name} - ${customer.phone}';
      _customerName.text = customer.name;
      _customerPhone.text = customer.phone;
      _customerPhone2.text = customer.phone2 ?? '';
      _customerDevices = [];
    });
  }

  Future<void> _selectCustomer(CustomerModel customer) async {
    _applyCustomer(customer);
    await _loadCustomerDevices(customer.id);
  }

  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomer = null;
      _selectedDeviceId = null;
      _customerLookup.clear();
      _customerName.clear();
      _customerPhone.clear();
      _customerPhone2.clear();
      _customerDevices = [];
      _company.clear();
      _model.clear();
      _color.clear();
      _imei.clear();
      _serial.clear();
    });
  }

  void _selectDevice(DeviceModel device) {
    setState(() {
      _selectedDeviceId = device.id;
      _company.text = device.brand;
      _model.text = device.model;
      _color.text = device.color ?? '';
      _imei.text = device.imei ?? '';
      _serial.text = device.serialNumber ?? '';
    });
  }

  void _newDeviceForCustomer() {
    setState(() {
      _selectedDeviceId = null;
      _company.clear();
      _model.clear();
      _color.clear();
      _imei.clear();
      _serial.clear();
    });
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      _addUniqueImages(result.paths.whereType<String>());
    });
  }

  Future<void> _captureImage() async {
    final path = await _captureCameraImage(context);
    if (path == null || !mounted) return;
    setState(() {
      _addUniqueImages([path]);
    });
  }

  void _addUniqueImages(Iterable<String> paths) {
    for (final path in paths) {
      if (!_images.contains(path)) {
        _images.add(path);
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      RepairIntakeData(
        customerId: _selectedCustomer?.id,
        deviceId: _selectedDeviceId,
        customerName: _customerName.text,
        customerPhone: _customerPhone.text,
        customerPhone2: _customerPhone2.text,
        receiverName: _receiverName.text,
        deviceType: _deviceType.text,
        company: _company.text,
        model: _model.text,
        color: _color.text,
        imei: _imei.text,
        serial: _serial.text,
        lockCode: _lockCode.text,
        accessories: _accessories.text,
        problem: _problem.text,
        deviceCondition: _condition.text,
        damage: _damage.text,
        deviceWorks: _works,
        deviceCharges: _charges,
        waterDamage: _water,
        extraNotes: _notes.text,
        imagePaths: List.unmodifiable(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: const _DialogTitle('استلام جوال جديد'),
      content: SizedBox(
        width: _dialogWidthFor(context, 760),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WorkflowHero(
                  asset: _receiveGraphicAsset,
                  color: AppColors.primary,
                  title: 'استلام منظم',
                  subtitle: 'توثيق بيانات العميل والجهاز والصور من أول خطوة.',
                ),
                const SizedBox(height: 12),
                _ReceiverSelector(
                  controller: _receiverName,
                  names: _receiverNames,
                ),
                const SizedBox(height: 12),
                _DialogSection(
                  title: 'بيانات العميل',
                  children: [
                    Autocomplete<CustomerModel>(
                      displayStringForOption: (customer) =>
                          '${customer.name} - ${customer.phone}',
                      optionsBuilder: (value) async {
                        await _searchCustomers(value.text);
                        return _customerSuggestions;
                      },
                      onSelected: _selectCustomer,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmit) {
                        if (_customerLookup.text.isNotEmpty &&
                            controller.text.isEmpty) {
                          controller.text = _customerLookup.text;
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(
                            labelText: 'بحث عن عميل مسجل بالاسم أو الرقم',
                            prefixIcon: Icon(Icons.person_search_rounded),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 220,
                                maxWidth: _dialogWidthFor(context, 520) - 24,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final customer = options.elementAt(index);
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primary,
                                    ),
                                    title: Text(customer.name,
                                        style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                      [customer.phone, customer.phone2]
                                          .whereType<String>()
                                          .where((value) =>
                                              value.trim().isNotEmpty)
                                          .join(' / '),
                                      style: GoogleFonts.cairo(fontSize: 12),
                                    ),
                                    onTap: () => onSelected(customer),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCustomer == null
                                ? 'يمكنك اختيار عميل مسجل أو إدخال عميل جديد من الحقول التالية.'
                                : 'العميل المحدد: ${_selectedCustomer!.name}',
                            style: GoogleFonts.cairo(
                              color: context.appColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_selectedCustomer != null) ...[
                          TextButton.icon(
                            onPressed: () => context
                                .push('/customers/${_selectedCustomer!.id}'),
                            icon:
                                const Icon(Icons.folder_open_rounded, size: 18),
                            label: Text('فتح ملف العميل',
                                style: GoogleFonts.cairo(fontSize: 12)),
                          ),
                          TextButton.icon(
                            onPressed: _clearSelectedCustomer,
                            icon: const Icon(Icons.person_add_alt_1_rounded,
                                size: 18),
                            label: Text('عميل جديد',
                                style: GoogleFonts.cairo(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _TwoFields(
                      first: _TextFieldBox(
                        controller: _customerName,
                        label: 'اسم العميل',
                        requiredValue: true,
                      ),
                      second: _TextFieldBox(
                        controller: _customerPhone,
                        label: 'رقم الجوال',
                        requiredValue: true,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    _TextFieldBox(
                      controller: _customerPhone2,
                      label: 'رقم إضافي اختياري',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                _DialogSection(
                  title: 'بيانات الجهاز',
                  children: [
                    _ExistingDevicePicker(
                      selectedCustomer: _selectedCustomer,
                      devices: _customerDevices,
                      selectedDeviceId: _selectedDeviceId,
                      loading: _loadingDevices,
                      onSelectDevice: _selectDevice,
                      onNewDevice: _newDeviceForCustomer,
                    ),
                    const SizedBox(height: 10),
                    _TwoFields(
                      first: _TextFieldBox(
                        controller: _deviceType,
                        label: 'نوع الجهاز',
                      ),
                      second: _TextFieldBox(
                        controller: _company,
                        label: 'الشركة',
                      ),
                    ),
                    _TwoFields(
                      first: _TextFieldBox(
                        controller: _model,
                        label: 'الموديل',
                        requiredValue: true,
                      ),
                      second: _TextFieldBox(
                        controller: _color,
                        label: 'اللون',
                      ),
                    ),
                    _TwoFields(
                      first: _TextFieldBox(
                        controller: _imei,
                        label: 'IMEI أو الرقم التسلسلي',
                      ),
                      second: _TextFieldBox(
                        controller: _lockCode,
                        label: 'رمز القفل اختياري',
                      ),
                    ),
                    _TextFieldBox(
                      controller: _serial,
                      label: 'الرقم التسلسلي',
                    ),
                    _TextFieldBox(
                      controller: _accessories,
                      label: 'الملحقات المستلمة',
                    ),
                  ],
                ),
                _DialogSection(
                  title: 'المشكلة وحالة الجهاز',
                  children: [
                    _TextFieldBox(
                      controller: _problem,
                      label: 'وصف المشكلة',
                      requiredValue: true,
                      maxLines: 3,
                    ),
                    _TwoFields(
                      first: _TextFieldBox(
                        controller: _condition,
                        label: 'حالة الجهاز عند الاستلام',
                      ),
                      second: _TextFieldBox(
                        controller: _damage,
                        label: 'الكسر أو الخدوش',
                      ),
                    ),
                    SwitchListTile(
                      value: _works,
                      onChanged: (v) => setState(() => _works = v),
                      title:
                          Text('هل الجهاز يعمل؟', style: GoogleFonts.cairo()),
                    ),
                    SwitchListTile(
                      value: _charges,
                      onChanged: (v) => setState(() => _charges = v),
                      title:
                          Text('هل الجهاز يشحن؟', style: GoogleFonts.cairo()),
                    ),
                    SwitchListTile(
                      value: _water,
                      onChanged: (v) => setState(() => _water = v),
                      title: Text('هل تعرض للماء؟', style: GoogleFonts.cairo()),
                    ),
                    _TextFieldBox(
                      controller: _notes,
                      label: 'ملاحظات إضافية',
                      maxLines: 3,
                    ),
                  ],
                ),
                _DialogSection(
                  title: 'صور الجهاز',
                  children: [
                    _PhotoSourceButtons(
                      count: _images.length,
                      cameraLabel: 'التقاط صورة بالكاميرا',
                      galleryLabel: 'اختيار صور من المعرض',
                      onCamera: _captureImage,
                      onGallery: _pickImages,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _save,
            child: Text(
              'حفظ واستلام الجهاز',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExistingDevicePicker extends StatelessWidget {
  final CustomerModel? selectedCustomer;
  final List<DeviceModel> devices;
  final String? selectedDeviceId;
  final bool loading;
  final ValueChanged<DeviceModel> onSelectDevice;
  final VoidCallback onNewDevice;

  const _ExistingDevicePicker({
    required this.selectedCustomer,
    required this.devices,
    required this.selectedDeviceId,
    required this.loading,
    required this.onSelectDevice,
    required this.onNewDevice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (selectedCustomer == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          'اختر عميلًا مسجلًا لعرض جوالاته السابقة، أو أكمل البيانات كعميل جديد.',
          style: GoogleFonts.cairo(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'جوالات العميل السابقة',
                  style: GoogleFonts.cairo(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onNewDevice,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('جوال جديد', style: GoogleFonts.cairo()),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _DevicePickTile(
            title: 'تسجيل جوال جديد لهذا العميل',
            subtitle: 'سيتم حفظه داخل ملف العميل بعد الاستلام',
            icon: Icons.add_circle_outline_rounded,
            selected: selectedDeviceId == null,
            onTap: onNewDevice,
          ),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'لا توجد جوالات سابقة لهذا العميل.',
                style: GoogleFonts.cairo(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            )
          else
            ...devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _DevicePickTile(
                  title: device.displayName,
                  subtitle: [
                    if (device.imei?.trim().isNotEmpty == true)
                      'IMEI: ${device.imei}',
                    if (device.serialNumber?.trim().isNotEmpty == true)
                      'SN: ${device.serialNumber}',
                    if (device.color?.trim().isNotEmpty == true) device.color,
                    if (device.storage?.trim().isNotEmpty == true)
                      device.storage,
                  ].whereType<String>().join(' - '),
                  icon: Icons.phone_android_rounded,
                  selected: selectedDeviceId == device.id,
                  onTap: () => onSelectDevice(device),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DevicePickTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DevicePickTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = selected ? AppColors.primary : colors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : colors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceActionDialog extends StatelessWidget {
  final RepairDeviceCard card;

  const _DeviceActionDialog({required this.card});

  @override
  Widget build(BuildContext context) {
    final m = card.maintenance;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: const _DialogTitle('فتح الجهاز'),
      content: SizedBox(
        width: _dialogWidthFor(context, 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WorkflowHero(
                asset: _repairGraphicAsset,
                color: AppColors.info,
                title: 'إدارة حالة الصيانة',
                subtitle: 'اختر الخطوة التالية للجهاز من بطاقة العمل.',
                compact: true,
              ),
              const SizedBox(height: 12),
              _DeviceSummary(card: card),
              const SizedBox(height: 12),
              _IntakePhotosButton(maintenanceId: m.id),
              const SizedBox(height: 16),
              _ActionButton(
                color: AppColors.info,
                asset: _repairGraphicAsset,
                icon: Icons.build_rounded,
                title: 'تحت الصيانة',
                onTap: () => Navigator.pop(context, _DeviceAction.underRepair),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                color: AppColors.statusWaitingPart,
                asset: _repairGraphicAsset,
                icon: Icons.extension_rounded,
                title: 'يحتاج قطع غيار',
                onTap: () => Navigator.pop(context, _DeviceAction.needsPart),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                color: AppColors.success,
                asset: _deliveryGraphicAsset,
                icon: Icons.task_alt_rounded,
                title: 'جاهز',
                onTap: () => Navigator.pop(context, _DeviceAction.ready),
              ),
              if (m.status == AppConstants.statusWarrantyReturn ||
                  card.isWarrantyWork) ...[
                const SizedBox(height: 12),
                const _SmallBadge(
                    label: 'صيانة تحت الضمان', color: AppColors.info),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortNoteDialog extends StatefulWidget {
  final String title;
  final String label;
  final String buttonLabel;
  final bool requiredValue;

  const _ShortNoteDialog({
    required this.title,
    required this.label,
    required this.buttonLabel,
    this.requiredValue = false,
  });

  @override
  State<_ShortNoteDialog> createState() => _ShortNoteDialogState();
}

class _ShortNoteDialogState extends State<_ShortNoteDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.requiredValue && _ctrl.text.trim().isEmpty) {
      setState(() => _error = 'هذا الحقل مطلوب');
      return;
    }
    Navigator.pop(context, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _DialogTitle(widget.title),
      content: TextField(
        controller: _ctrl,
        textDirection: TextDirection.rtl,
        autofocus: true,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _save,
            child: Text(widget.buttonLabel, style: GoogleFonts.cairo()),
          ),
        ),
      ],
    );
  }
}

class _WarrantyDurationChooser extends StatefulWidget {
  final TextEditingController controller;

  const _WarrantyDurationChooser({required this.controller});

  @override
  State<_WarrantyDurationChooser> createState() =>
      _WarrantyDurationChooserState();
}

class _WarrantyDurationChooserState extends State<_WarrantyDurationChooser> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _WarrantyDurationChooser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int? get _selectedPreset {
    final days = int.tryParse(widget.controller.text.trim());
    if (days == null) return null;
    for (final preset in _warrantyDurationPresets) {
      if (preset.days == days) return preset.days;
    }
    return null;
  }

  void _applyPreset(int? days) {
    if (days == null) return;
    widget.controller.text = days.toString();
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TextFieldBox(
          controller: widget.controller,
          label: 'مدة الضمان بالأيام',
          keyboardType: TextInputType.number,
          validator: _validateWarrantyDaysText,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<int>(
            value: _selectedPreset,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'اختيار سريع للضمان',
            ),
            hint: const Text('شهر، شهرين... حتى سنتين'),
            items: _warrantyDurationPresets
                .map(
                  (preset) => DropdownMenuItem<int>(
                    value: preset.days,
                    child: Text(
                      '${preset.label} - ${preset.days} يوم',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _applyPreset,
          ),
        ),
      ],
    );
  }
}

class _ReadyDialog extends StatefulWidget {
  const _ReadyDialog();

  @override
  State<_ReadyDialog> createState() => _ReadyDialogState();
}

class _ReadyDialogState extends State<_ReadyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repair = TextEditingController();
  final _part = TextEditingController();
  final _cost = TextEditingController();
  final _warrantyDays = TextEditingController(text: '30');
  final _notes = TextEditingController();
  final List<String> _images = [];

  @override
  void dispose() {
    _repair.dispose();
    _part.dispose();
    _cost.dispose();
    _warrantyDays.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => _addUniqueImages(result.paths.whereType<String>()));
  }

  Future<void> _captureImage() async {
    final path = await _captureCameraImage(context);
    if (path == null || !mounted) return;
    setState(() => _addUniqueImages([path]));
  }

  void _addUniqueImages(Iterable<String> paths) {
    for (final path in paths) {
      if (!_images.contains(path)) {
        _images.add(path);
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ReadyPayload(
        repairDetails: _repair.text.trim(),
        changedPart: _part.text.trim(),
        cost: double.tryParse(_cost.text.trim()) ?? 0,
        warrantyDays: int.tryParse(_warrantyDays.text.trim()) ?? 0,
        notes: _notes.text.trim(),
        imagePaths: List.unmodifiable(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: const _DialogTitle('جعل الجهاز جاهزاً'),
      content: SizedBox(
        width: _dialogWidthFor(context, 620),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _WorkflowHero(
                  asset: _deliveryGraphicAsset,
                  color: AppColors.success,
                  title: 'جاهز للتسليم',
                  subtitle: 'سجل الصيانة والقطع والضمان قبل إشعار العميل.',
                ),
                const SizedBox(height: 12),
                _TextFieldBox(
                  controller: _repair,
                  label: 'ما الصيانة التي تمت؟',
                  requiredValue: true,
                  maxLines: 3,
                ),
                _TextFieldBox(
                  controller: _part,
                  label: 'القطعة التي تم تغييرها، إن وجدت',
                ),
                _TwoFields(
                  first: _TextFieldBox(
                    controller: _cost,
                    label: 'تكلفة الصيانة',
                    keyboardType: TextInputType.number,
                  ),
                  second: _WarrantyDurationChooser(
                    controller: _warrantyDays,
                  ),
                ),
                _TextFieldBox(
                  controller: _notes,
                  label: 'ملاحظات الصيانة',
                  maxLines: 3,
                ),
                _PhotoSourceButtons(
                  count: _images.length,
                  cameraLabel: 'التقاط صورة بعد الصيانة',
                  galleryLabel: 'اختيار صور بعد الصيانة',
                  onCamera: _captureImage,
                  onGallery: _pickImages,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _save,
            child: Text(
              'حفظ وجعل الجهاز جاهزاً',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryDialog extends StatefulWidget {
  final RepairDeviceCard card;

  const _DeliveryDialog({required this.card});

  @override
  State<_DeliveryDialog> createState() => _DeliveryDialogState();
}

class _DeliveryDialogState extends State<_DeliveryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paid = TextEditingController();
  final _warranty = TextEditingController();
  final _condition = TextEditingController();
  final _receiver = TextEditingController();
  final _warrantyTerms = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final m = widget.card.maintenance;
    _paid.text = m.totalCost.toStringAsFixed(0);
    _warranty.text = (m.warrantyDays ?? 30).toString();
    _loadDefaultWarrantyTerms();
  }

  Future<void> _loadDefaultWarrantyTerms() async {
    final settings = SettingsService();
    await settings.load();
    if (!mounted || _warrantyTerms.text.trim().isNotEmpty) return;
    setState(() => _warrantyTerms.text = settings.warrantyTerms);
  }

  @override
  void dispose() {
    _paid.dispose();
    _warranty.dispose();
    _condition.dispose();
    _receiver.dispose();
    _warrantyTerms.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _DeliveryPayload(
        paidAmount: double.tryParse(_paid.text.trim()) ?? 0,
        warrantyDays: int.tryParse(_warranty.text.trim()) ?? 0,
        deliveryCondition: _condition.text.trim(),
        receiverName: _receiver.text.trim(),
        warrantyTerms: _warrantyTerms.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.card.maintenance;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: const _DialogTitle('تأكيد استلام العميل للجهاز'),
      content: SizedBox(
        width: _dialogWidthFor(context, 620),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WorkflowHero(
                  asset: _deliveryGraphicAsset,
                  color: AppColors.success,
                  title: 'تسليم موثق',
                  subtitle: 'حفظ حالة الجهاز النهائية وشروط الضمان للعميل.',
                ),
                const SizedBox(height: 12),
                _DeviceSummary(card: widget.card),
                const SizedBox(height: 12),
                _TextFieldBox(
                  controller: _condition,
                  label: 'حالة الجهاز عند التسليم',
                ),
                _TwoFields(
                  first: _TextFieldBox(
                    controller: _paid,
                    label: 'المبلغ المدفوع',
                    keyboardType: TextInputType.number,
                  ),
                  second: _WarrantyDurationChooser(controller: _warranty),
                ),
                _TextFieldBox(
                  controller: _receiver,
                  label: 'اسم المستلم، إذا كان مختلفاً عن العميل',
                ),
                _TextFieldBox(
                  controller: _warrantyTerms,
                  label: 'شروط الضمان للعميل',
                  maxLines: 4,
                ),
                _TextFieldBox(
                  controller: _notes,
                  label: 'ملاحظات التسليم',
                  maxLines: 3,
                ),
                Text(
                  'مدة الضمان تبدأ من وقت تأكيد التسليم، وليس من وقت الجاهزية.',
                  style: GoogleFonts.cairo(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'الإجمالي المسجل: ${m.totalCost.toStringAsFixed(0)} ر.س',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _save,
            child: Text(
              'تأكيد التسليم وبدء الضمان',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _WarrantyReturnDialog extends StatefulWidget {
  final WarrantyModel warranty;

  const _WarrantyReturnDialog({required this.warranty});

  @override
  State<_WarrantyReturnDialog> createState() => _WarrantyReturnDialogState();
}

class _WarrantyReturnDialogState extends State<_WarrantyReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _problem = TextEditingController();
  final _description = TextEditingController();
  final _condition = TextEditingController();
  final _notes = TextEditingController();
  final List<String> _images = [];

  @override
  void dispose() {
    _problem.dispose();
    _description.dispose();
    _condition.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => _addUniqueImages(result.paths.whereType<String>()));
  }

  Future<void> _captureImage() async {
    final path = await _captureCameraImage(context);
    if (path == null || !mounted) return;
    setState(() => _addUniqueImages([path]));
  }

  void _addUniqueImages(Iterable<String> paths) {
    for (final path in paths) {
      if (!_images.contains(path)) {
        _images.add(path);
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _WarrantyReturnPayload(
        problem: _problem.text.trim(),
        customerDescription: _description.text.trim(),
        deviceCondition: _condition.text.trim(),
        employeeNotes: _notes.text.trim(),
        imagePaths: List.unmodifiable(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      title: const _DialogTitle('استلام الجهاز تحت الضمان'),
      content: SizedBox(
        width: _dialogWidthFor(context, 620),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WorkflowHero(
                  asset: _warrantyGraphicAsset,
                  color: AppColors.info,
                  title: 'استلام تحت الضمان',
                  subtitle: 'توثيق مشكلة الرجوع والصور قبل متابعة المعالجة.',
                ),
                const SizedBox(height: 12),
                _SmallBadge(
                  label: widget.warranty.deviceInfo,
                  color: AppColors.info,
                ),
                const SizedBox(height: 12),
                _TextFieldBox(
                  controller: _problem,
                  label: 'المشكلة الحالية',
                  requiredValue: true,
                  maxLines: 2,
                ),
                _TextFieldBox(
                  controller: _description,
                  label: 'وصف العميل',
                  maxLines: 2,
                ),
                _TextFieldBox(
                  controller: _condition,
                  label: 'حالة الجهاز عند العودة',
                  maxLines: 2,
                ),
                _TextFieldBox(
                  controller: _notes,
                  label: 'ملاحظات الموظف',
                  maxLines: 3,
                ),
                _PhotoSourceButtons(
                  count: _images.length,
                  cameraLabel: 'التقاط صورة عند العودة',
                  galleryLabel: 'اختيار صور عند العودة',
                  onCamera: _captureImage,
                  onGallery: _pickImages,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _save,
            child: Text(
              'حفظ واستلامه تحت الضمان',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  final RepairDeviceCard card;

  const _DeviceSummary({required this.card});

  @override
  Widget build(BuildContext context) {
    final m = card.maintenance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: 'العميل', value: m.customerName ?? 'عميل'),
          _InfoLine(label: 'المستلم', value: _receiverName(card)),
          if (_technicianName(card) != null)
            _InfoLine(label: 'الفني', value: _technicianName(card)!),
          _InfoLine(label: 'الجوال', value: m.customerPhone ?? 'غير مسجل'),
          _InfoLine(label: 'الجهاز', value: '${m.brand} ${m.model}'),
          _InfoLine(
              label: 'المشكلة',
              value: card.latestWarrantyProblem ?? m.faultDescription),
          _InfoLine(label: 'الحالة الحالية', value: _cardTitle(card)),
          if (card.requiredParts.isNotEmpty)
            _InfoLine(label: 'القطع', value: card.requiredParts.join('، ')),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final String? asset;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionButton({
    required this.color,
    this.asset,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Row(
          children: [
            if (asset != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  asset!,
                  width: 56,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(icon, size: 24),
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              Icon(icon, size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiverSelector extends StatelessWidget {
  final TextEditingController controller;
  final List<String> names;

  const _ReceiverSelector({
    required this.controller,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = controller.text.trim();
    final selected = names.contains(current)
        ? current
        : (names.isNotEmpty ? names.first : null);
    if (selected != null && current.isEmpty) {
      controller.text = selected;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_ind_rounded,
                  color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مستلم الجهاز',
                  style: GoogleFonts.cairo(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                names.isEmpty ? 'أضفه من الإعدادات' : '${names.length} أسماء',
                style: GoogleFonts.cairo(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (names.isEmpty)
            TextFormField(
              controller: controller,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'اكتب اسم مستلم الجهاز',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'حدد اسم مستلم الجهاز';
                }
                return null;
              },
            )
          else
            DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اختر المستلم من الإعدادات',
                prefixIcon: Icon(Icons.engineering_rounded),
              ),
              items: names
                  .map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                controller.text = value;
              },
              validator: (value) {
                if ((value ?? controller.text).trim().isEmpty) {
                  return 'حدد اسم مستلم الجهاز';
                }
                return null;
              },
            ),
        ],
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool requiredValue;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _TextFieldBox({
    required this.controller,
    required this.label,
    this.requiredValue = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration:
            InputDecoration(labelText: requiredValue ? '$label *' : label),
        validator: (value) {
          if (requiredValue && (value == null || value.trim().isEmpty)) {
            return 'هذا الحقل مطلوب';
          }
          return validator?.call(value);
        },
      ),
    );
  }
}

class _TwoFields extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _TwoFields({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, second]);
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _DialogSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DialogSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 176),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _SmallBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 164 : 240),
        child: Text(
          label,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: compact ? 10.5 : 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              color: context.appColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64,
              color: context.appColors.textSecondary.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.cairo(color: context.appColors.textSecondary),
            textAlign: TextAlign.center,
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
              size: 62, color: AppColors.error),
          const SizedBox(height: 12),
          Text('حدث خطأ',
              style:
                  GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message,
              style: GoogleFonts.cairo(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

enum _DeviceAction { underRepair, needsPart, ready }

class _ReadyPayload {
  final String repairDetails;
  final String changedPart;
  final double cost;
  final int warrantyDays;
  final String notes;
  final List<String> imagePaths;

  const _ReadyPayload({
    required this.repairDetails,
    required this.changedPart,
    required this.cost,
    required this.warrantyDays,
    required this.notes,
    required this.imagePaths,
  });
}

class _DeliveryPayload {
  final double paidAmount;
  final int warrantyDays;
  final String deliveryCondition;
  final String receiverName;
  final String warrantyTerms;
  final String notes;

  const _DeliveryPayload({
    required this.paidAmount,
    required this.warrantyDays,
    required this.deliveryCondition,
    required this.receiverName,
    required this.warrantyTerms,
    required this.notes,
  });
}

class _WarrantyReturnPayload {
  final String problem;
  final String customerDescription;
  final String deviceCondition;
  final String employeeNotes;
  final List<String> imagePaths;

  const _WarrantyReturnPayload({
    required this.problem,
    required this.customerDescription,
    required this.deviceCondition,
    required this.employeeNotes,
    required this.imagePaths,
  });
}

int _cardPriority(RepairDeviceCard card) {
  switch (card.maintenance.status) {
    case AppConstants.statusReady:
      return 0;
    case AppConstants.statusNew:
      return 1;
    case AppConstants.statusWarrantyReturn:
      return 2;
    case AppConstants.statusWaitingPart:
      return 3;
    case AppConstants.statusRepairing:
      return 4;
    default:
      return 5;
  }
}

Color _cardColor(RepairDeviceCard card) {
  if (card.isWarrantyWork ||
      card.maintenance.status == AppConstants.statusWarrantyReturn) {
    return AppColors.statusWarrantyReturn;
  }
  switch (card.maintenance.status) {
    case AppConstants.statusNew:
      return AppColors.warning;
    case AppConstants.statusRepairing:
      return AppColors.info;
    case AppConstants.statusWaitingPart:
      return AppColors.statusWaitingPart;
    case AppConstants.statusReady:
      return AppColors.success;
    default:
      return AppColors.primary;
  }
}

String _cardTitle(RepairDeviceCard card) {
  if (card.isWarrantyWork ||
      card.maintenance.status == AppConstants.statusWarrantyReturn) {
    if (card.maintenance.status == AppConstants.statusReady) {
      return 'جهاز ضمان جاهز للاستلام';
    }
    return 'صيانة تحت الضمان';
  }
  switch (card.maintenance.status) {
    case AppConstants.statusNew:
      return 'جهاز جديد دخل الصيانة';
    case AppConstants.statusRepairing:
      return 'تحت الصيانة';
    case AppConstants.statusWaitingPart:
      return 'يحتاج قطع غيار';
    case AppConstants.statusReady:
      return 'الجهاز جاهز للاستلام';
    default:
      return AppConstants.maintenanceStatusLabel(card.maintenance.status);
  }
}

String _receiverName(RepairDeviceCard card) {
  final savedReceiver = _extractReceiverName(card.maintenance.internalNotes);
  if (savedReceiver != null) return savedReceiver;
  final createdByName = card.maintenance.createdByName?.trim() ?? '';
  if (createdByName.isNotEmpty) return createdByName;
  final createdBy = card.maintenance.createdBy.trim();
  return createdBy.isEmpty ? 'غير محدد' : createdBy;
}

String? _extractReceiverName(String? notes) {
  final text = notes?.trim() ?? '';
  if (text.isEmpty) return null;
  for (final line in text.split('\n')) {
    final clean = line.trim();
    const label = 'مستلم الجهاز:';
    if (!clean.startsWith(label)) continue;
    final value = clean.substring(label.length).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

String? _technicianName(RepairDeviceCard card) {
  final name = card.maintenance.technicianName?.trim() ?? '';
  return name.isEmpty ? null : name;
}

String _workflowAssetForCard(RepairDeviceCard card) {
  if (card.maintenance.status == AppConstants.statusReady) {
    return _deliveryGraphicAsset;
  }
  if (card.maintenance.status == AppConstants.statusNew) {
    return _receiveGraphicAsset;
  }
  return _repairGraphicAsset;
}

Color _warrantyColor(String status) {
  switch (status) {
    case 'active':
      return AppColors.warrantyActive;
    case 'expiring':
      return AppColors.warrantyExpiringSoon;
    default:
      return AppColors.warrantyExpired;
  }
}

String _warrantyTitle(String status) {
  switch (status) {
    case 'active':
      return 'ضمان فعال';
    case 'expiring':
      return 'الضمان ينتهي قريباً';
    default:
      return 'انتهى الضمان';
  }
}

String _warrantyCountdownLabel(WarrantyModel warranty) {
  if (warranty.isVoid) return 'ملغي';
  final days = warranty.calendarDaysRemaining;
  if (days > 0) return 'متبقي: $days يوم';
  if (days == 0) return 'ينتهي اليوم';
  return 'منتهي منذ ${days.abs()} يوم';
}

final List<_WarrantyDurationPreset> _warrantyDurationPresets =
    List<_WarrantyDurationPreset>.unmodifiable(
  List<_WarrantyDurationPreset>.generate(24, (index) {
    final months = index + 1;
    return _WarrantyDurationPreset(
      label: _warrantyMonthLabel(months),
      days: _warrantyDaysForMonths(months),
    );
  }),
);

class _WarrantyDurationPreset {
  final String label;
  final int days;

  const _WarrantyDurationPreset({
    required this.label,
    required this.days,
  });
}

int _warrantyDaysForMonths(int months) {
  if (months >= 24) return AppConstants.warrantyMaxDays;
  if (months == 12) return 365;
  if (months > 12) return 365 + ((months - 12) * 30);
  return months * 30;
}

String _warrantyMonthLabel(int months) {
  if (months == 1) return 'شهر';
  if (months == 2) return 'شهرين';
  if (months == 12) return 'سنة';
  if (months == 24) return 'سنتين';
  if (months < 12) {
    return months <= 10 ? '$months أشهر' : '$months شهر';
  }

  final rest = months - 12;
  if (rest == 1) return 'سنة وشهر';
  if (rest == 2) return 'سنة وشهرين';
  return rest <= 10 ? 'سنة و$rest أشهر' : 'سنة و$rest شهر';
}

String? _validateWarrantyDaysText(String? value) {
  final days = int.tryParse(value?.trim() ?? '');
  if (!AppConstants.isValidWarrantyDays(days)) {
    return 'حدد مدة الضمان من يوم واحد إلى سنتين.';
  }
  return null;
}

String _elapsedSince(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final diff = DateTime.now().difference(date);
  if (diff.inDays > 0) return '${diff.inDays} يوم';
  if (diff.inHours > 0) return '${diff.inHours} ساعة';
  final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
  return '$minutes دقيقة';
}

String _date(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
