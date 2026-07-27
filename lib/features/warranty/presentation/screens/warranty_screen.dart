import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../data/warranty_model.dart';
import '../cubit/warranty_cubit.dart';

class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key});

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final WarrantyCubit _cubit;
  final _nameSearchController = TextEditingController();
  final _phoneSearchController = TextEditingController();
  final _recordSearchController = TextEditingController();
  _DurationFilter _durationFilter = _DurationFilter.all;
  String _nameQuery = '';
  String _phoneQuery = '';
  String _recordQuery = '';

  static const _tabs = [
    _TabDef('الكل', null),
    _TabDef('ساري', 'active'),
    _TabDef('ينتهي قريباً', 'expiring'),
    _TabDef('منتهي', 'expired'),
  ];

  @override
  void initState() {
    super.initState();
    _cubit = WarrantyCubit()..loadAll();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _cubit.loadAll(status: _tabs[_tabController.index].status);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cubit.close();
    _nameSearchController.dispose();
    _phoneSearchController.dispose();
    _recordSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: colors.background,
        body: BlocBuilder<WarrantyCubit, WarrantyState>(
          builder: (context, state) {
            final stats =
                state is WarrantyLoaded ? state.stats : <String, dynamic>{};
            final compactHeight = MediaQuery.sizeOf(context).height < 600;

            return Column(
              children: [
                // ── Stats cards ────────────────────────────────────────────────
                if (!compactHeight)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _StatCard(
                          label: 'ساري',
                          value: '${stats['active'] ?? 0}',
                          color: AppColors.warrantyActive,
                          icon: Icons.verified_user_rounded,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'ينتهي قريباً',
                          value: '${stats['expiringSoon'] ?? 0}',
                          color: AppColors.warrantyExpiringSoon,
                          icon: Icons.timer_rounded,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'منتهي',
                          value: '${stats['expired'] ?? 0}',
                          color: AppColors.warrantyExpired,
                          icon: Icons.cancel_rounded,
                        ),
                      ],
                    ),
                  ),

                // ── Tabs ───────────────────────────────────────────────────────
                Container(
                  color: colors.surface,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: GoogleFonts.cairo(
                      fontSize: compactHeight ? 11 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle:
                        GoogleFonts.cairo(fontSize: compactHeight ? 11 : 13),
                    tabs: _tabs
                        .map(
                          (t) => Tab(
                            height: compactHeight ? 38 : null,
                            text: t.label,
                          ),
                        )
                        .toList(),
                  ),
                ),

                _buildFilters(compactHeight: compactHeight),
                Expanded(
                  child: _buildContent(
                    context,
                    state,
                    compactHeight: compactHeight,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters({required bool compactHeight}) {
    return Padding(
      padding: compactHeight
          ? const EdgeInsets.fromLTRB(8, 6, 8, 4)
          : const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrowDurationSelector = constraints.maxWidth < 520;
              final durationControl = SegmentedButton<_DurationFilter>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _DurationFilter.all,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: Text(
                      narrowDurationSelector ? 'الكل' : 'كل الضمانات',
                    ),
                  ),
                  ButtonSegment(
                    value: _DurationFilter.short,
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(
                      narrowDurationSelector ? 'قصيرة' : 'الضمانات القصيرة',
                    ),
                  ),
                  ButtonSegment(
                    value: _DurationFilter.long,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      narrowDurationSelector ? 'طويلة' : 'الضمانات الطويلة',
                    ),
                  ),
                ],
                selected: {_durationFilter},
                onSelectionChanged: (selection) {
                  setState(() => _durationFilter = selection.first);
                },
              );
              final durationSelector = narrowDurationSelector
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: durationControl,
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: durationControl,
                    );
              final fields = [
                _WarrantySearchField(
                  controller: _nameSearchController,
                  label: 'بحث باسم العميل',
                  icon: Icons.person_search_rounded,
                  onChanged: (value) => setState(() => _nameQuery = value),
                  onClear: () => setState(() {
                    _nameSearchController.clear();
                    _nameQuery = '';
                  }),
                ),
                _WarrantySearchField(
                  controller: _phoneSearchController,
                  label: 'بحث برقم الجوال',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  onChanged: (value) => setState(() => _phoneQuery = value),
                  onClear: () => setState(() {
                    _phoneSearchController.clear();
                    _phoneQuery = '';
                  }),
                ),
                _WarrantySearchField(
                  controller: _recordSearchController,
                  label: 'الجهاز أو رقم الطلب',
                  icon: Icons.manage_search_rounded,
                  onChanged: (value) => setState(() => _recordQuery = value),
                  onClear: () => setState(() {
                    _recordSearchController.clear();
                    _recordQuery = '';
                  }),
                ),
              ];

              if (compactHeight && constraints.maxWidth >= 680) {
                return Row(
                  children: [
                    SizedBox(width: 330, child: durationSelector),
                    const SizedBox(width: 8),
                    for (var i = 0; i < fields.length; i++) ...[
                      Expanded(child: fields[i]),
                      if (i != fields.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                );
              }

              final searchFields = constraints.maxWidth < 680
                  ? Column(
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          fields[i],
                          if (i != fields.length - 1) const SizedBox(height: 8),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          Expanded(child: fields[i]),
                          if (i != fields.length - 1) const SizedBox(width: 10),
                        ],
                      ],
                    );

              return Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: durationSelector,
                  ),
                  const SizedBox(height: 10),
                  searchFields,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WarrantyState state, {
    required bool compactHeight,
  }) {
    if (state is WarrantyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is WarrantyError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(state.message,
                style: GoogleFonts.cairo(fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<WarrantyCubit>().loadAll(),
              child: Text('إعادة المحاولة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    if (state is WarrantyLoaded) {
      final durationItems = _filterByDuration(state.items);
      final items = filterWarrantyRows(
        durationItems,
        nameQuery: _nameQuery,
        phoneQuery: _phoneQuery,
        recordQuery: _recordQuery,
      );
      if (durationItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 72,
                  color:
                      context.appColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('لا توجد ضمانات',
                  style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textSecondary)),
            ],
          ),
        );
      }
      if (items.isEmpty) {
        return _EmptyWarrantySearch(
          onClear: () => setState(() {
            _nameSearchController.clear();
            _phoneSearchController.clear();
            _recordSearchController.clear();
            _nameQuery = '';
            _phoneQuery = '';
            _recordQuery = '';
          }),
        );
      }
      return Padding(
        padding: compactHeight
            ? const EdgeInsets.fromLTRB(8, 2, 8, 6)
            : const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: _WarrantyTable(
          items: items,
          totalCount: durationItems.length,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<WarrantyModel> _filterByDuration(List<WarrantyModel> items) {
    switch (_durationFilter) {
      case _DurationFilter.short:
        return items
            .where((item) =>
                item.warrantyDays <= AppConstants.longWarrantyThresholdDays)
            .toList();
      case _DurationFilter.long:
        return items.where((item) => item.isLongWarranty).toList();
      case _DurationFilter.all:
        return items;
    }
  }
}

enum _DurationFilter { all, short, long }

List<WarrantyModel> filterWarrantyRows(
  List<WarrantyModel> items, {
  String nameQuery = '',
  String phoneQuery = '',
  String recordQuery = '',
}) {
  final name = nameQuery.trim().toLowerCase();
  final phone = _searchDigits(phoneQuery);
  final record = recordQuery.trim().toLowerCase();

  return items.where((item) {
    final matchesName =
        name.isEmpty || (item.customerName ?? '').toLowerCase().contains(name);
    final matchesPhone = phone.isEmpty ||
        _searchDigits(item.customerPhone ?? '').contains(phone);
    final matchesRecord = record.isEmpty ||
        (item.ticketNumber ?? '').toLowerCase().contains(record) ||
        item.deviceInfo.toLowerCase().contains(record);
    return matchesName && matchesPhone && matchesRecord;
  }).toList(growable: false);
}

String _searchDigits(String value) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  final western = value.split('').map((character) {
    final arabicIndex = arabicDigits.indexOf(character);
    if (arabicIndex >= 0) return arabicIndex.toString();
    final persianIndex = persianDigits.indexOf(character);
    if (persianIndex >= 0) return persianIndex.toString();
    return character;
  }).join();
  return western.replaceAll(RegExp(r'[^0-9]'), '');
}

class _WarrantySearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _WarrantySearchField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    required this.onClear,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        isDense: true,
      ),
    );
  }
}

class _EmptyWarrantySearch extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyWarrantySearch({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colors.textSecondary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد نتائج مطابقة',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text('مسح البحث', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

class _WarrantyTable extends StatefulWidget {
  final List<WarrantyModel> items;
  final int totalCount;

  const _WarrantyTable({
    required this.items,
    required this.totalCount,
  });

  @override
  State<_WarrantyTable> createState() => _WarrantyTableState();
}

class _WarrantyTableState extends State<_WarrantyTable> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < 1080 ? 1080.0 : constraints.maxWidth;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  widget.items.length == widget.totalCount
                      ? '${widget.items.length} ضمان'
                      : 'عرض ${widget.items.length} من ${widget.totalCount} ضمان',
                  style: GoogleFonts.cairo(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: constraints.maxHeight - 39,
                      child: Column(
                        children: [
                          const _WarrantyTableHeader(),
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: widget.items.length > 8,
                              child: ListView.separated(
                                controller: _verticalController,
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: widget.items.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: colors.border.withValues(alpha: 0.55),
                                ),
                                itemBuilder: (context, index) =>
                                    _WarrantyTableRow(
                                  warranty: widget.items[index],
                                  shaded: index.isOdd,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WarrantyTableHeader extends StatelessWidget {
  const _WarrantyTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: AppColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Row(
        children: [
          _WarrantyCell(text: 'رقم الطلب', flex: 2, header: true),
          _WarrantyCell(text: 'اسم العميل', flex: 3, header: true),
          _WarrantyCell(text: 'الجوال', flex: 2, header: true),
          _WarrantyCell(text: 'الجهاز', flex: 4, header: true),
          _WarrantyCell(text: 'الحالة', flex: 2, header: true),
          _WarrantyCell(text: 'المدة', flex: 2, header: true),
          _WarrantyCell(text: 'تاريخ الانتهاء', flex: 2, header: true),
          _WarrantyCell(text: 'المتبقي', flex: 2, header: true),
          SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _WarrantyTableRow extends StatelessWidget {
  final WarrantyModel warranty;
  final bool shaded;

  const _WarrantyTableRow({
    required this.warranty,
    required this.shaded,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = switch (warranty.status) {
      'active' => AppColors.warrantyActive,
      'expiring' => AppColors.warrantyExpiringSoon,
      _ => AppColors.warrantyExpired,
    };
    final endDate = DateTime.fromMillisecondsSinceEpoch(warranty.endDate);

    return Semantics(
      button: true,
      label:
          '${warranty.customerName}, ${warranty.customerPhone}, ${warranty.deviceInfo}',
      child: Material(
        color: shaded
            ? colors.surface.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/maintenance/${warranty.maintenanceId}'),
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _WarrantyCell(
                    text: warranty.ticketNumber ?? '—',
                    flex: 2,
                    color: AppColors.primary,
                    weight: FontWeight.w800,
                  ),
                  _WarrantyCell(
                    text: warranty.customerName ?? 'عميل غير محدد',
                    flex: 3,
                    weight: FontWeight.w700,
                  ),
                  _WarrantyCell(
                    text: warranty.customerPhone?.trim().isNotEmpty == true
                        ? warranty.customerPhone!
                        : 'بدون رقم',
                    flex: 2,
                    ltr: true,
                  ),
                  _WarrantyCell(text: warranty.deviceInfo, flex: 4),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          warranty.statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _WarrantyCell(
                    text: '${warranty.warrantyDays} يوم',
                    flex: 2,
                  ),
                  _WarrantyCell(
                    text: DateFormat('yyyy/MM/dd').format(endDate),
                    flex: 2,
                    ltr: true,
                  ),
                  _WarrantyCell(
                    text: _remainingWarrantyLabel(warranty),
                    flex: 2,
                    color: statusColor,
                    weight: FontWeight.w800,
                  ),
                  const SizedBox(
                    width: 38,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarrantyCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool header;
  final bool ltr;
  final Color? color;
  final FontWeight? weight;

  const _WarrantyCell({
    required this.text,
    required this.flex,
    this.header = false,
    this.ltr = false,
    this.color,
    this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ltr ? TextDirection.ltr : null,
          textAlign: ltr ? TextAlign.right : null,
          style: GoogleFonts.cairo(
            color:
                color ?? (header ? colors.textPrimary : colors.textSecondary),
            fontSize: header ? 12 : 12.5,
            fontWeight: weight ?? (header ? FontWeight.w800 : FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

String _remainingWarrantyLabel(WarrantyModel warranty) {
  if (warranty.isVoid) return 'ملغي';
  if (warranty.expiryApproved) return 'منتهي ومعتمد';
  final days = warranty.calendarDaysRemaining;
  if (days < 0) return 'منذ ${days.abs()} يوم';
  if (days == 0) return 'ينتهي اليوم';
  return '$days يوم';
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Warranty card
// ─────────────────────────────────────────────────────────────────────────────

// Kept temporarily for backwards-compatible visual reference while the new
// tablet-friendly circular grid is rolled out.
// ignore: unused_element
class _WarrantyCard extends StatelessWidget {
  final WarrantyModel warranty;
  const _WarrantyCard({required this.warranty});

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return AppColors.warrantyActive;
      case 'expiring':
        return AppColors.warrantyExpiringSoon;
      default:
        return AppColors.warrantyExpired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _statusColor(warranty.status);
    final startDate = DateTime.fromMillisecondsSinceEpoch(warranty.startDate);
    final endDate = DateTime.fromMillisecondsSinceEpoch(warranty.endDate);
    final remainingLabel = _remainingLabel(endDate, warranty.isVoid);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to the maintenance detail
          context.go('/maintenance/${warranty.maintenanceId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  if (warranty.ticketNumber != null)
                    Text(
                      warranty.ticketNumber!,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      warranty.statusLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Customer name
              Text(
                warranty.customerName ?? 'عميل غير محدد',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // Device info
              Text(
                warranty.deviceInfo,
                style: GoogleFonts.cairo(
                    fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),
              if (warranty.expiryApproved) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'انتهى الضمان - تاريخ الانتهاء: ${_dualDate(endDate)} - تاريخ الاعتماد: ${warranty.expiryApprovedAt == null ? 'غير محدد' : _dualDate(DateTime.fromMillisecondsSinceEpoch(warranty.expiryApprovedAt!))}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DatePill(
                    icon: Icons.play_arrow_rounded,
                    label: 'البداية',
                    value: _dualDate(startDate),
                  ),
                  _DatePill(
                    icon: Icons.flag_rounded,
                    label: 'النهاية',
                    value: _dualDate(endDate),
                  ),
                  _DatePill(
                    icon: Icons.verified_user_rounded,
                    label: 'المدة',
                    value: '${warranty.warrantyDays} يوم',
                  ),
                  _DatePill(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'المتبقي',
                    value: remainingLabel,
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dualDate(DateTime date) {
    final gregorian = DateFormat('yyyy/MM/dd', 'ar').format(date);
    final hijri = HijriDate.fromGregorian(date).format();
    return 'م $gregorian | هـ $hijri';
  }

  String _remainingLabel(DateTime endDate, bool isVoid) {
    if (isVoid) return 'ملغي';
    final today = DateTime.now();
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = endDay.difference(todayDay).inDays;
    if (days > 0) return '$days يوم';
    if (days == 0) return 'ينتهي اليوم';
    return 'منتهي منذ ${days.abs()} يوم';
  }
}

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _DatePill({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final String? status;
  const _TabDef(this.label, this.status);
}
