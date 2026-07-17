import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/customer_model.dart';
import '../cubit/customers_cubit.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String? _filterType;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _searchText {
    final value = _searchCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  void _reloadCustomers(BuildContext context) {
    context.read<CustomersCubit>().loadCustomers(
          search: _searchText,
          customerType: _filterType,
        );
  }

  Future<void> _confirmDeleteCustomer(
    BuildContext context,
    CustomerModel customer,
  ) async {
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إخفاء العميل وأجهزته من القوائم، مع بقاء سجلات الصيانة والفواتير محفوظة.',
                        style: GoogleFonts.cairo(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<CustomersCubit>().deleteCustomer(
            customer.id,
            search: _searchText,
            customerType: _filterType,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف ${customer.name}',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف العميل', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomersCubit()..loadCustomers(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'العملاء',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: AppColors.lightText,
                fontSize: 18,
              ),
            ),
          ),
          floatingActionButton: Builder(
            builder: (ctx) => FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              label: Text(
                'عميل جديد',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () async {
                await context.push('/customers/new');
                if (ctx.mounted) {
                  ctx.read<CustomersCubit>().loadCustomers(
                        search:
                            _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
                        customerType: _filterType,
                      );
                }
              },
            ),
          ),
          body: BlocBuilder<CustomersCubit, CustomersState>(
            builder: (ctx, state) {
              return Column(
                children: [
                  // Search + filter bar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.cairo(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'بحث بالاسم أو الجوال...',
                              hintStyle: GoogleFonts.cairo(
                                color: AppColors.lightTextSecondary,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: AppColors.lightBackground,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.lightBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.lightBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                            ),
                            onChanged: (v) =>
                                ctx.read<CustomersCubit>().loadCustomers(
                                      search: v.isEmpty ? null : v,
                                      customerType: _filterType,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'الكل',
                          selected: _filterType == null,
                          onTap: () {
                            setState(() => _filterType = null);
                            ctx.read<CustomersCubit>().loadCustomers(
                                  search: _searchCtrl.text.isEmpty
                                      ? null
                                      : _searchCtrl.text,
                                );
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'مميز',
                          selected: _filterType == 'vip',
                          color: AppColors.warning,
                          onTap: () {
                            setState(() => _filterType = 'vip');
                            ctx.read<CustomersCubit>().loadCustomers(
                                  search: _searchCtrl.text.isEmpty
                                      ? null
                                      : _searchCtrl.text,
                                  customerType: 'vip',
                                );
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'عادي',
                          selected: _filterType == 'regular',
                          color: AppColors.secondary,
                          onTap: () {
                            setState(() => _filterType = 'regular');
                            ctx.read<CustomersCubit>().loadCustomers(
                                  search: _searchCtrl.text.isEmpty
                                      ? null
                                      : _searchCtrl.text,
                                  customerType: 'regular',
                                );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: switch (state) {
                      CustomersLoading() => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      CustomersError(:final message) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 48),
                              const SizedBox(height: 12),
                              Text(message,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.error)),
                            ],
                          ),
                        ),
                      CustomersLoaded(:final customers)
                          when customers.isEmpty =>
                        _EmptyState(
                          onAdd: () async {
                            await context.push('/customers/new');
                            if (ctx.mounted) {
                              _reloadCustomers(ctx);
                            }
                          },
                        ),
                      CustomersLoaded(:final customers) => ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: customers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _CustomerCard(
                            customer: customers[i],
                            onOpen: () async {
                              final changed = await ctx.push<bool>(
                                '/customers/${customers[i].id}',
                              );
                              if (changed == true && ctx.mounted) {
                                _reloadCustomers(ctx);
                              }
                            },
                            onDelete: () =>
                                _confirmDeleteCustomer(ctx, customers[i]),
                          ),
                        ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatefulWidget {
  final CustomerModel customer;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  final _db = DatabaseService();
  // distinct active statuses for this customer's devices
  List<String> _activeStatuses = [];

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.rawQuery(
      '''SELECT DISTINCT status FROM maintenance
         WHERE shop_id = ? AND customer_id = ? AND deleted_at IS NULL
         AND status NOT IN ('delivered', 'cancelled', 'abandoned')''',
      [shopId, widget.customer.id],
    );
    if (mounted) {
      setState(() =>
          _activeStatuses = rows.map((r) => r['status'] as String).toList());
    }
  }

  // Build blinking status dots row
  List<Widget> _buildStatusDots() {
    final dots = <Widget>[];
    if (_activeStatuses.contains('ready')) {
      dots.add(const _StatusDot(
        color: AppColors.success,
        tooltip: 'جهاز جاهز للاستلام',
      ));
    }
    if (_activeStatuses.contains('waiting_part')) {
      dots.add(const _StatusDot(
        color: AppColors.warning,
        tooltip: 'جهاز بانتظار قطعة',
      ));
    }
    final workStatuses = {'new', 'inspecting', 'repairing', 'repaired'};
    if (_activeStatuses.any(workStatuses.contains)) {
      dots.add(const _StatusDot(
        color: AppColors.error,
        tooltip: 'جهاز تحت الصيانة',
      ));
    }
    return dots;
  }

  @override
  Widget build(BuildContext context) {
    final isVip = widget.customer.customerType == 'vip';
    final dots = _buildStatusDots();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: dots.isNotEmpty
            ? BorderSide(
                color: dots.length == 1 && _activeStatuses.contains('ready')
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar with optional pulsing ring
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isVip
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      widget.customer.name.isNotEmpty
                          ? widget.customer.name[0]
                          : '?',
                      style: GoogleFonts.cairo(
                        color: isVip ? AppColors.warning : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  // Pulsing ring when device is ready
                  if (_activeStatuses.contains('ready'))
                    Positioned.fill(
                      child: const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).custom(
                            duration: 800.ms,
                            builder: (_, v, child) => Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.success
                                      .withValues(alpha: v * 0.9),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + VIP + status dots
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.customer.name,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.lightText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.warning, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  'مميز',
                                  style: GoogleFonts.cairo(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (dots.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ...dots.map((d) => Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: d,
                              )),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.customer.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    // Active device status labels
                    if (dots.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (_activeStatuses.contains('ready'))
                            const _MiniStatusBadge(
                                label: '✅ جهاز جاهز', color: AppColors.success),
                          if (_activeStatuses.contains('waiting_part'))
                            const _MiniStatusBadge(
                                label: '⏳ بانتظار قطعة',
                                color: AppColors.warning),
                          if (_activeStatuses.any({
                            'new',
                            'inspecting',
                            'repairing',
                            'repaired'
                          }.contains))
                            const _MiniStatusBadge(
                                label: '🔧 تحت الصيانة',
                                color: AppColors.error),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.customer.totalSpent.toStringAsFixed(0)} ر.س',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.customer.visitCount} زيارة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: AppColors.lightTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'حذف العميل',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: widget.onDelete,
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing status dot
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final Color color;
  final String tooltip;
  const _StatusDot({required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.6, end: 1.4, duration: 750.ms)
          .fade(begin: 0.4, end: 1.0, duration: 750.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini status badge under customer name
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              size: 72,
              color: AppColors.lightTextSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'لا يوجد عملاء',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف أول عميل لبدء إدارة البيانات',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_outlined),
            label: Text('إضافة عميل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
