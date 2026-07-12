import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:window_manager/window_manager.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../customers/data/customer_model.dart';
import '../../../devices/data/device_model.dart';
import '../../../devices/data/devices_repository.dart';
import '../../../maintenance/data/maintenance_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = DatabaseService();
  final _devicesRepo = DevicesRepository();
  final _phoneCtrl = TextEditingController();

  List<CustomerModel> _customers = [];
  List<DeviceModel> _devices = [];
  List<MaintenanceModel> _maintenances = [];
  CustomerModel? _selectedCustomer;
  bool _searching = false;
  bool _loadingDetails = false;
  int _searchToken = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String query) async {
    final q = query.trim();
    final token = ++_searchToken;

    if (q.length < 2) {
      setState(() {
        _customers = [];
        _selectedCustomer = null;
        _devices = [];
        _maintenances = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _selectedCustomer = null;
      _devices = [];
      _maintenances = [];
    });

    final digits = q.replaceAll(RegExp(r'\D'), '');
    final like = '%$q%';
    final digitsLike = '%${digits.isEmpty ? q : digits}%';
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''
      SELECT *
      FROM customers
      WHERE shop_id = ?
        AND deleted_at IS NULL
        AND (
          name LIKE ?
          OR phone LIKE ?
          OR IFNULL(phone2, '') LIKE ?
          OR REPLACE(REPLACE(REPLACE(IFNULL(phone, ''), ' ', ''), '-', ''), '+', '') LIKE ?
          OR REPLACE(REPLACE(REPLACE(IFNULL(phone2, ''), ' ', ''), '-', ''), '+', '') LIKE ?
        )
      ORDER BY name ASC
      LIMIT 30
      ''',
      [shopId, like, like, like, digitsLike, digitsLike],
    );

    if (!mounted || token != _searchToken) return;
    final matches = rows.map(CustomerModel.fromMap).toList();
    setState(() {
      _customers = matches;
      _searching = false;
    });
    if (matches.length == 1) {
      await _selectCustomer(matches.first);
    }
  }

  Future<void> _selectCustomer(CustomerModel customer) async {
    setState(() {
      _selectedCustomer = customer;
      _loadingDetails = true;
    });

    final devices = await _devicesRepo.getByCustomer(customer.id);
    final shopId = await _db.getCurrentShopId();
    final maintenanceRows = await _db.rawQuery(
      '''
      SELECT m.*, c.name AS customer_name, u.name AS technician_name
      FROM maintenance m
      LEFT JOIN customers c ON c.id = m.customer_id AND c.shop_id = m.shop_id
      LEFT JOIN users u ON u.id = m.technician_id
      WHERE m.shop_id = ? AND m.customer_id = ? AND m.deleted_at IS NULL
      ORDER BY m.created_at DESC
      ''',
      [shopId, customer.id],
    );

    if (!mounted) return;
    setState(() {
      _devices = devices;
      _maintenances = maintenanceRows.map(MaintenanceModel.fromMap).toList();
      _loadingDetails = false;
    });
  }

  void _clearSearch() {
    _phoneCtrl.clear();
    _searchToken++;
    setState(() {
      _customers = [];
      _selectedCustomer = null;
      _devices = [];
      _maintenances = [];
      _searching = false;
      _loadingDetails = false;
    });
  }

  String _date(int millis) {
    return DateFormat('yyyy/MM/dd', 'ar')
        .format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final money = NumberFormat('#,##0.00', 'ar');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بحث عن عميل',
                              style: GoogleFonts.cairo(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'اكتب اسم العميل أو رقم الجوال لعرض ملفه وأجهزته وسجلات الصيانة',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go('/dashboard'),
                            icon: const Icon(Icons.dashboard_rounded),
                            label: Text(
                              'دخول البرنامج',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/customers/new'),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                              'إضافة عميل',
                              style: GoogleFonts.cairo(),
                            ),
                          ),
                          if (AppPlatform.supportsWindowControls)
                            OutlinedButton.icon(
                              onPressed: () => windowManager.close(),
                              icon: const Icon(Icons.close_rounded),
                              label: Text(
                                'خروج',
                                style: GoogleFonts.cairo(),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'اسم العميل أو رقم الجوال',
                      hintStyle: GoogleFonts.cairo(
                        color: colors.textSecondary.withAlpha(130),
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _phoneCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                    onChanged: _searchCustomers,
                    onSubmitted: _searchCustomers,
                  ),
                ],
              ),
            ),
            if (_searching) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 20),
            if (_phoneCtrl.text.trim().length < 2)
              const SizedBox(
                height: 260,
                child: EmptyState(
                  message: 'ابدأ بكتابة اسم العميل أو رقم الجوال',
                  subtitle:
                      'ستظهر ملفات العملاء المطابقة هنا مع خيار فتح الملف الكامل',
                  icon: Icons.search_rounded,
                ),
              )
            else if (!_searching && _customers.isEmpty)
              SizedBox(
                height: 260,
                child: EmptyState(
                  message: 'لا يوجد عميل مطابق',
                  subtitle:
                      'تأكد من الاسم أو الرقم أو أضف العميل من شاشة العملاء',
                  icon: Icons.person_off_rounded,
                  action: ElevatedButton.icon(
                    onPressed: () => context.go('/customers/new'),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text('إضافة عميل', style: GoogleFonts.cairo()),
                  ),
                ),
              )
            else ...[
              SectionHeader(
                title: 'نتائج العملاء',
                trailing: StatusBadge(
                  label: '${_customers.length}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              ..._customers.map(
                (customer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CustomerResultCard(
                    customer: customer,
                    selected: _selectedCustomer?.id == customer.id,
                    onTap: () => _selectCustomer(customer),
                    onOpen: () => context.go('/customers/${customer.id}'),
                  ),
                ),
              ),
            ],
            if (_loadingDetails) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_selectedCustomer != null && !_loadingDetails) ...[
              const SizedBox(height: 18),
              _SelectedCustomerCard(
                customer: _selectedCustomer!,
                onOpen: () => context.go('/customers/${_selectedCustomer!.id}'),
                onAddDevice: () => context
                    .go('/customers/${_selectedCustomer!.id}/devices/new'),
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'أجهزة العميل',
                trailing: TextButton.icon(
                  onPressed: () => context
                      .go('/customers/${_selectedCustomer!.id}/devices/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('جهاز جديد', style: GoogleFonts.cairo()),
                ),
              ),
              const SizedBox(height: 10),
              if (_devices.isEmpty)
                const _InlineEmpty(
                  icon: Icons.phone_android_rounded,
                  text: 'لا توجد أجهزة مسجلة لهذا العميل',
                )
              else
                ..._devices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DeviceCard(
                      device: device,
                      onOpen: () => context.go('/devices/${device.id}'),
                      onAddMaintenance: () => context.go(
                        '/maintenance/new?customerId=${device.customerId}&deviceId=${device.id}',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'سجلات الصيانة',
                trailing: StatusBadge(
                  label: '${_maintenances.length}',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(height: 10),
              if (_maintenances.isEmpty)
                const _InlineEmpty(
                  icon: Icons.build_circle_outlined,
                  text: 'لا توجد صيانة مسجلة لهذا العميل',
                )
              else
                ..._maintenances.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final maintenance = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MaintenanceCard(
                        maintenance: maintenance,
                        title: 'صيانة رقم ${index + 1}',
                        date: _date(maintenance.createdAt),
                        total: money.format(maintenance.totalCost),
                        onTap: () =>
                            context.go('/maintenance/${maintenance.id}'),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerResultCard extends StatelessWidget {
  final CustomerModel customer;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _CustomerResultCard({
    required this.customer,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primary.withAlpha(18) : null,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withAlpha(25),
            child: const Icon(Icons.person_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  [customer.phone, customer.phone2]
                      .whereType<String>()
                      .where((p) => p.trim().isNotEmpty)
                      .join(' / '),
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'فتح ملف العميل',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onOpen;
  final VoidCallback onAddDevice;

  const _SelectedCustomerCard({
    required this.customer,
    required this.onOpen,
    required this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_pin_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  customer.phone,
                  style: GoogleFonts.cairo(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text('ملف العميل', style: GoogleFonts.cairo()),
              ),
              ElevatedButton.icon(
                onPressed: onAddDevice,
                icon: const Icon(Icons.add_rounded),
                label: Text('إضافة جهاز', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onOpen;
  final VoidCallback onAddMaintenance;

  const _DeviceCard({
    required this.device,
    required this.onOpen,
    required this.onAddMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  [
                    if (device.imei?.isNotEmpty == true) 'IMEI: ${device.imei}',
                    if (device.color?.isNotEmpty == true) device.color,
                    if (device.storage?.isNotEmpty == true) device.storage,
                  ].join('   '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_rounded),
                label: Text('فتح', style: GoogleFonts.cairo()),
              ),
              ElevatedButton.icon(
                onPressed: onAddMaintenance,
                icon: const Icon(Icons.add_task_rounded),
                label: Text('إضافة صيانة', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceModel maintenance;
  final String title;
  final String date;
  final String total;
  final VoidCallback onTap;

  const _MaintenanceCard({
    required this.maintenance,
    required this.title,
    required this.date,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: maintenance.statusColor.withAlpha(25),
            child: Icon(Icons.build_rounded, color: maintenance.statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    StatusBadge(
                      label: maintenance.statusLabel,
                      color: maintenance.statusColor,
                    ),
                    Text(
                      '#${maintenance.ticketNumber}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${maintenance.brand} ${maintenance.model} - ${maintenance.faultDescription}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total ر.س',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              Text(
                date,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: colors.textSecondary.withAlpha(140)),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.cairo(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
