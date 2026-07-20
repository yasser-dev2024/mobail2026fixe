import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../../../core/services/document_share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/database/database_service.dart';
import '../../data/customer_model.dart';
import '../../data/customers_repository.dart';
import '../../../devices/data/device_model.dart';
import '../../../devices/data/devices_repository.dart';
import '../../../invoices/data/invoice_model.dart';
import '../../../invoices/data/invoice_repository.dart';
import '../../../maintenance/data/maintenance_model.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final _customersRepo = CustomersRepository();
  final _devicesRepo = DevicesRepository();
  final _db = DatabaseService();

  late TabController _tabController;
  CustomerModel? _customer;
  List<DeviceModel> _devices = [];
  List<MaintenanceModel> _maintenances = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customer = await _customersRepo.getById(widget.customerId);
    final devices = await _devicesRepo.getByCustomer(widget.customerId);
    final shopId = await _db.getCurrentShopId();
    final maintRows = await _db.rawQuery(
      '''
SELECT m.*,
       w.expiry_approved AS warranty_expiry_approved,
       w.expiry_approved_at AS warranty_expiry_approved_at,
       w.expiry_approved_by AS warranty_expiry_approved_by
FROM maintenance m
LEFT JOIN warranties w ON w.maintenance_id = m.id AND w.shop_id = m.shop_id
WHERE m.shop_id = ?
  AND m.customer_id = ?
  AND m.deleted_at IS NULL
ORDER BY m.created_at DESC
''',
      [shopId, widget.customerId],
    );
    final maintenances = maintRows.map(MaintenanceModel.fromMap).toList();

    if (mounted) {
      setState(() {
        _customer = customer;
        _devices = devices;
        _maintenances = maintenances;
        _loading = false;
      });
    }
  }

  Future<void> _openWhatsApp() async {
    if (_customer == null) return;
    await WhatsAppLauncher.send(
      phone: _customer!.phone,
      message: '',
    );
  }

  Future<void> _confirmDeleteCustomer() async {
    final customer = _customer;
    if (customer == null) return;

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
                  customer.name,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(customer.phone, style: GoogleFonts.cairo()),
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم إخفاء العميل وكل أجهزته من القوائم. سجلات الصيانة والفواتير ستبقى محفوظة للرجوع إليها.',
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

    if (confirmed != true || !mounted) return;

    try {
      await _customersRepo.delete(customer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف العميل', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف العميل: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _customer == null
                ? Center(
                    child: Text('لم يتم العثور على العميل',
                        style: GoogleFonts.cairo(
                            color: AppColors.lightTextSecondary)))
                : NestedScrollView(
                    headerSliverBuilder: (ctx, _) => [
                      SliverAppBar(
                        expandedHeight: 220,
                        floating: false,
                        pinned: true,
                        backgroundColor: AppColors.primary,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.white),
                            onPressed: () async {
                              await context
                                  .push('/customers/${widget.customerId}/edit');
                              _load();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_outlined,
                                color: Colors.white),
                            tooltip: 'واتساب',
                            onPressed: _openWhatsApp,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white),
                            tooltip: 'حذف العميل',
                            onPressed: _confirmDeleteCustomer,
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: AppColors.primaryGradient,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 48),
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Text(
                                    _customer!.name.isNotEmpty
                                        ? _customer!.name[0]
                                        : '?',
                                    style: GoogleFonts.cairo(
                                      fontSize: 28,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _customer!.name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone_outlined,
                                        color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _customer!.phone,
                                      style: GoogleFonts.cairo(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                    if (_customer!.customerType == 'vip') ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppColors.warning
                                                  .withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded,
                                                color: AppColors.warning,
                                                size: 12),
                                            const SizedBox(width: 3),
                                            Text(
                                              'مميز',
                                              style: GoogleFonts.cairo(
                                                color: AppColors.warning,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        bottom: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          indicatorWeight: 3,
                          labelStyle: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700, fontSize: 13),
                          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          tabs: const [
                            Tab(text: 'ملف العميل'),
                            Tab(text: 'الصيانة'),
                            Tab(text: 'الفواتير'),
                            Tab(text: 'ملاحظات'),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _StatsRow(
                          devices: _devices.length,
                          maintenances: _maintenances.length,
                          totalSpent: _customer!.totalSpent,
                          lastVisit: _customer!.lastVisit,
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _DevicesTab(
                          devices: _devices,
                          maintenances: _maintenances,
                          customerId: widget.customerId,
                          onRefresh: _load,
                        ),
                        _MaintenancesTab(maintenances: _maintenances),
                        _InvoicesTab(customerId: widget.customerId),
                        _NotesTab(notes: _customer!.notes),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int devices;
  final int maintenances;
  final double totalSpent;
  final int? lastVisit;

  const _StatsRow({
    required this.devices,
    required this.maintenances,
    required this.totalSpent,
    required this.lastVisit,
  });

  @override
  Widget build(BuildContext context) {
    final lastVisitStr = lastVisit != null
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(lastVisit!))
        : 'لا يوجد';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _StatItem(
            value: '$devices',
            label: 'جهاز',
            icon: Icons.phone_android_rounded,
            color: AppColors.primary,
          ),
          _StatItem(
            value: '$maintenances',
            label: 'صيانة',
            icon: Icons.build_outlined,
            color: AppColors.warning,
          ),
          _StatItem(
            value: '${totalSpent.toStringAsFixed(0)} ر.س',
            label: 'إجمالي',
            icon: Icons.payments_outlined,
            color: AppColors.success,
          ),
          _StatItem(
            value: lastVisitStr,
            label: 'آخر زيارة',
            icon: Icons.calendar_today_outlined,
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.lightText,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesTab extends StatelessWidget {
  final List<DeviceModel> devices;
  final List<MaintenanceModel> maintenances;
  final String customerId;
  final VoidCallback onRefresh;

  const _DevicesTab({
    required this.devices,
    required this.maintenances,
    required this.customerId,
    required this.onRefresh,
  });

  List<MaintenanceModel> _maintenancesFor(DeviceModel device) {
    return maintenances.where((maintenance) {
      if (maintenance.deviceId != null) {
        return maintenance.deviceId == device.id;
      }

      final deviceImei = (device.imei ?? '').trim();
      final maintenanceImei = (maintenance.imei ?? '').trim();
      if (deviceImei.isNotEmpty && maintenanceImei == deviceImei) {
        return true;
      }

      return maintenance.brand.trim().toLowerCase() ==
              device.brand.trim().toLowerCase() &&
          maintenance.model.trim().toLowerCase() ==
              device.model.trim().toLowerCase();
    }).toList();
  }

  List<MaintenanceModel> get _unlinkedMaintenances {
    return maintenances.where((maintenance) {
      return !devices.any((device) =>
          _maintenancesFor(device).any((item) => item.id == maintenance.id));
    }).toList();
  }

  Future<void> _confirmDeleteDevice(
    BuildContext context,
    DeviceModel device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'حذف الجوال؟',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'سيتم إخفاء "${device.displayName}" من قائمة أجهزة العميل، مع بقاء سجل الصيانة محفوظًا.',
          style: GoogleFonts.cairo(height: 1.6),
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

    try {
      await DevicesRepository().delete(device.id);
      if (!context.mounted) return;
      onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الجوال', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الجوال: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlinked = _unlinkedMaintenances;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${devices.length} جهاز مسجل - ${maintenances.length} صيانة',
              style: GoogleFonts.cairo(
                  color: AppColors.lightTextSecondary, fontSize: 13),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('إضافة جهاز',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.primary),
                  onPressed: () async {
                    await context.push('/customers/$customerId/devices/new');
                    onRefresh();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.build_rounded, size: 16),
                  label: Text('استلام صيانة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                  onPressed: () async {
                    await context
                        .push('/maintenance/new?customerId=$customerId');
                    onRefresh();
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (devices.isEmpty && maintenances.isEmpty)
          SizedBox(
            height: 260,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android_outlined,
                      size: 48,
                      color:
                          AppColors.lightTextSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text('لا يوجد أجهزة أو صيانات مسجلة',
                      style: GoogleFonts.cairo(
                          color: AppColors.lightTextSecondary, fontSize: 14)),
                ],
              ),
            ),
          )
        else ...[
          ...devices.map((device) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceFileCard(
                device: device,
                maintenances: _maintenancesFor(device),
                onOpenDevice: () async {
                  final changed =
                      await context.push<bool>('/devices/${device.id}');
                  if (changed == true) onRefresh();
                },
                onAddMaintenance: () async {
                  await context.push(
                    '/maintenance/new?customerId=$customerId&deviceId=${device.id}',
                  );
                  onRefresh();
                },
                onDeleteDevice: () => _confirmDeleteDevice(context, device),
                onOpenMaintenance: (maintenance) =>
                    context.push('/maintenance/${maintenance.id}'),
              ),
            );
          }),
          if (unlinked.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'صيانات بدون جهاز مسجل',
              style: GoogleFonts.cairo(
                color: AppColors.lightText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...unlinked.map(
              (maintenance) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _UnlinkedMaintenanceCard(
                  maintenance: maintenance,
                  onTap: () => context.push('/maintenance/${maintenance.id}'),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _DeviceFileCard extends StatelessWidget {
  final DeviceModel device;
  final List<MaintenanceModel> maintenances;
  final VoidCallback onOpenDevice;
  final VoidCallback onAddMaintenance;
  final VoidCallback onDeleteDevice;
  final void Function(MaintenanceModel maintenance) onOpenMaintenance;

  const _DeviceFileCard({
    required this.device,
    required this.maintenances,
    required this.onOpenDevice,
    required this.onAddMaintenance,
    required this.onDeleteDevice,
    required this.onOpenMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.phone_android_rounded,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: GoogleFonts.cairo(
                          color: AppColors.lightText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        [
                          if (device.imei?.trim().isNotEmpty == true)
                            'IMEI: ${device.imei}',
                          if (device.color?.trim().isNotEmpty == true)
                            device.color,
                          if (device.storage?.trim().isNotEmpty == true)
                            device.storage,
                        ].whereType<String>().join(' - '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onOpenDevice,
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: Text('فتح الجهاز',
                          style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      onPressed: onAddMaintenance,
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      label: Text('إضافة صيانة',
                          style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.45),
                        ),
                      ),
                      onPressed: onDeleteDevice,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text('حذف الجوال',
                          style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightBorder),
              ),
              child: maintenances.isEmpty
                  ? Text(
                      'لا توجد صيانات مسجلة لهذا الجوال',
                      style: GoogleFonts.cairo(
                        color: AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    )
                  : Column(
                      children: maintenances
                          .map(
                            (maintenance) => _MaintenanceMiniTile(
                              maintenance: maintenance,
                              onTap: () => onOpenMaintenance(maintenance),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceMiniTile extends StatelessWidget {
  final MaintenanceModel maintenance;
  final VoidCallback onTap;

  const _MaintenanceMiniTile({
    required this.maintenance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(maintenance.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: maintenance.statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                maintenance.statusLabel,
                style: GoogleFonts.cairo(
                  color: maintenance.statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${maintenance.ticketNumber} - ${maintenance.faultDescription}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: AppColors.lightText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: GoogleFonts.cairo(
                      color: AppColors.lightTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (maintenance.warrantyExpiryApproved)
                    _WarrantyExpiredMiniStamp(maintenance: maintenance),
                ],
              ),
            ),
            Text(
              '${maintenance.totalCost.toStringAsFixed(0)} ر.س',
              style: GoogleFonts.cairo(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlinkedMaintenanceCard extends StatelessWidget {
  final MaintenanceModel maintenance;
  final VoidCallback onTap;

  const _UnlinkedMaintenanceCard({
    required this.maintenance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: maintenance.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  maintenance.statusLabel,
                  style: GoogleFonts.cairo(
                    color: maintenance.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${maintenance.brand} ${maintenance.model}',
                      style: GoogleFonts.cairo(
                        color: AppColors.lightText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '#${maintenance.ticketNumber} - ${maintenance.faultDescription}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: AppColors.lightTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (maintenance.warrantyExpiryApproved)
                      _WarrantyExpiredMiniStamp(maintenance: maintenance),
                  ],
                ),
              ),
              Text(
                '${maintenance.totalCost.toStringAsFixed(0)} ر.س',
                style: GoogleFonts.cairo(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenancesTab extends StatelessWidget {
  final List<MaintenanceModel> maintenances;
  const _MaintenancesTab({required this.maintenances});

  @override
  Widget build(BuildContext context) {
    if (maintenances.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_outlined,
                size: 48,
                color: AppColors.lightTextSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('لا يوجد طلبات صيانة',
                style: GoogleFonts.cairo(
                    color: AppColors.lightTextSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: maintenances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final m = maintenances[i];
        return Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/maintenance/${m.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.brand} ${m.model}',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '#${m.ticketNumber}',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        if (m.warrantyExpiryApproved)
                          _WarrantyExpiredMiniStamp(maintenance: m),
                      ],
                    ),
                  ),
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
            ),
          ),
        );
      },
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

    return Padding(
      padding: const EdgeInsets.only(top: 3),
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

class _InvoicesTab extends StatefulWidget {
  final String customerId;
  const _InvoicesTab({required this.customerId});

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> {
  final _repo = InvoiceRepository();
  List<InvoiceModel> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _repo.getByCustomer(widget.customerId);
    if (mounted) {
      setState(() {
        _invoices = rows;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.lightTextSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('لا يوجد فواتير',
                style: GoogleFonts.cairo(
                    color: AppColors.lightTextSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        final date = DateTime.fromMillisecondsSinceEpoch(inv.createdAt);
        return Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading:
                const Icon(Icons.receipt_outlined, color: AppColors.primary),
            title: Text(
              '#${inv.invoiceNumber}',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${date.day}/${date.month}/${date.year} - ${inv.deviceName}',
              style: GoogleFonts.cairo(
                  fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                Text(
                  '${inv.total.toStringAsFixed(0)} ر.س',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.success),
                ),
                IconButton(
                  tooltip: 'فتح',
                  onPressed: () => _openInvoice(inv),
                  icon: const Icon(Icons.visibility_rounded),
                ),
                IconButton(
                  tooltip: 'طباعة',
                  onPressed: () => _printInvoice(inv),
                  icon: const Icon(Icons.print_rounded),
                ),
                IconButton(
                  tooltip: 'تنزيل',
                  onPressed: () => _downloadInvoice(inv),
                  icon: const Icon(Icons.download_rounded),
                ),
                IconButton(
                  tooltip: 'إرسال',
                  onPressed: () async {
                    try {
                      await _repo.sendWhatsApp(inv.id);
                      if (mounted) _load();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$e', style: GoogleFonts.cairo()),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openInvoice(InvoiceModel invoice) async {
    final path = invoice.pdfPath;
    if (path == null || !File(path).existsSync()) return;
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else {
      await Printing.sharePdf(
        bytes: await File(path).readAsBytes(),
        filename: invoice.fileName ?? 'invoice.pdf',
      );
    }
  }

  Future<void> _downloadInvoice(InvoiceModel invoice) async {
    final path = invoice.pdfPath;
    if (path == null || !File(path).existsSync()) return;
    final savedPath = await DocumentShareService.savePdfToDownloads(
      filePath: path,
      fileName: invoice.fileName ?? '${invoice.invoiceNumber}.pdf',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? 'تعذر حفظ الفاتورة في التنزيلات'
              : 'تم حفظ الفاتورة في $savedPath',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor:
            savedPath == null ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _printInvoice(InvoiceModel invoice) async {
    final path = invoice.pdfPath;
    if (path == null || !File(path).existsSync()) return;
    await Printing.layoutPdf(
      name: invoice.fileName ?? invoice.invoiceNumber,
      onLayout: (_) => File(path).readAsBytes(),
    );
  }
}

class _NotesTab extends StatelessWidget {
  final String? notes;
  const _NotesTab({required this.notes});

  @override
  Widget build(BuildContext context) {
    if (notes == null || notes!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes_outlined,
                size: 48,
                color: AppColors.lightTextSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('لا يوجد ملاحظات',
                style: GoogleFonts.cairo(
                    color: AppColors.lightTextSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            notes!,
            style: GoogleFonts.cairo(fontSize: 14, height: 1.7),
          ),
        ),
      ),
    );
  }
}
