import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/product_model.dart';
import '../cubit/inventory_cubit.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  static const _categories = [
    _CatDef(null, 'الكل', Icons.apps_rounded),
    _CatDef('phones', 'جوالات', Icons.phone_android_rounded),
    _CatDef('screens', 'شاشات', Icons.phone_iphone_rounded),
    _CatDef('batteries', 'بطاريات', Icons.battery_charging_full_rounded),
    _CatDef('chargers', 'شواحن', Icons.cable_rounded),
    _CatDef('earphones', 'سماعات', Icons.headphones_rounded),
    _CatDef('cases', 'كفرات', Icons.cases_rounded),
    _CatDef('spare_parts', 'قطع غيار', Icons.settings_rounded),
    _CatDef('services', 'خدمات', Icons.miscellaneous_services_rounded),
  ];

  @override
  void initState() {
    super.initState();
    context.read<InventoryCubit>().loadAll();
  }

  void _reload() {
    context.read<InventoryCubit>().loadAll(
          categoryKey: _selectedCategory,
          search: _searchQuery.isEmpty ? null : _searchQuery,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventoryDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم حذف المنتج', style: GoogleFonts.cairo()),
                backgroundColor: AppColors.success,
              ),
            );
            _reload();
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: GoogleFonts.cairo()),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final stats =
              state is InventoryLoaded ? state.stats : <String, dynamic>{};
          final items =
              state is InventoryLoaded ? state.items : <ProductModel>[];
          final isLoading = state is InventoryLoading;

          return Column(
            children: [
              // ── Stats ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _StatCard(
                      label: 'إجمالي المنتجات',
                      value: '${stats['totalProducts'] ?? 0}',
                      color: AppColors.primary,
                      icon: Icons.inventory_2_rounded,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      label: 'مخزون منخفض',
                      value: '${stats['lowStock'] ?? 0}',
                      color: AppColors.warning,
                      icon: Icons.warning_amber_rounded,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      label: 'نفذ المخزون',
                      value: '${stats['outOfStock'] ?? 0}',
                      color: AppColors.error,
                      icon: Icons.remove_shopping_cart_rounded,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      label: 'إجمالي القيمة',
                      value:
                          '${((stats['totalValue'] as num?) ?? 0).toStringAsFixed(0)} ر.س',
                      color: AppColors.success,
                      icon: Icons.attach_money_rounded,
                    ),
                  ],
                ),
              ),

              // ── Search ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _reload();
                  },
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم، الباركود...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _reload();
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // ── Category tabs ─────────────────────────────────────────────
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final selected = _selectedCategory == cat.key;
                    return FilterChip(
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat.key);
                        _reload();
                      },
                      avatar: Icon(cat.icon,
                          size: 16,
                          color: selected ? Colors.white : AppColors.primary),
                      label: Text(cat.label,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : null,
                          )),
                      selectedColor: AppColors.primary,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.08),
                      checkmarkColor: Colors.white,
                      showCheckmark: false,
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // ── Product grid / list ───────────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? _EmptyView(onAdd: () => context.go('/inventory/new'))
                        : _ProductGrid(
                            items: items,
                            onDelete: (id) {
                              _showDeleteDialog(context, id);
                            },
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/inventory/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('إضافة منتج',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف المنتج',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        content: Text('هل تريد حذف هذا المنتج؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventoryCubit>().delete(productId);
            },
            child: Text('حذف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product grid
// ─────────────────────────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  final List<ProductModel> items;
  final void Function(String id) onDelete;

  const _ProductGrid({required this.items, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 312,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _ProductCard(product: items[index], onDelete: onDelete),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final ProductModel product;
  final void Function(String id) onDelete;

  const _ProductCard({required this.product, required this.onDelete});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  late int _localQty;

  @override
  void initState() {
    super.initState();
    _localQty = widget.product.quantity;
  }

  @override
  void didUpdateWidget(_ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.quantity != widget.product.quantity) {
      _localQty = widget.product.quantity;
    }
  }

  void _adjustQty(int delta) {
    if (delta < 0 && _localQty <= 0) return;
    setState(() => _localQty += delta);
    context.read<InventoryCubit>().adjustQuantity(widget.product.id, delta);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final colors = context.appColors;
    final isLow = product.isLowStock;
    final isOut = product.isOutOfStock;

    Color qtyColor = colors.textPrimary;
    if (isOut) {
      qtyColor = AppColors.error;
    } else if (isLow) {
      qtyColor = AppColors.warning;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/inventory/${product.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image / icon area
              Expanded(
                child: Center(
                  child: product.imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            product.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.inventory_2_rounded,
                                size: 48,
                                color: AppColors.primary),
                          ),
                        )
                      : Icon(
                          product.isService
                              ? Icons.miscellaneous_services_rounded
                              : Icons.inventory_2_rounded,
                          size: 48,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                ),
              ),

              const SizedBox(height: 8),

              // Category label
              Text(
                product.categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 10, color: colors.textSecondary),
              ),

              // Product name
              Text(
                product.name,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Sale price
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${product.salePrice.toStringAsFixed(0)} ر.س',
                  maxLines: 1,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // Cost + profit indicator
              if (!product.isService && product.purchasePrice > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'تكلفة: ${product.purchasePrice.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: colors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: product.profit >= 0
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.profit >= 0 ? '+' : ''}${product.profitMargin.toStringAsFixed(0)}%',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: product.profit >= 0
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              // Quantity row: badge only (number shown in +/- row below)
              if (!product.isService)
                Row(
                  children: [
                    Text(
                      'المخزون',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: colors.textSecondary),
                    ),
                    const Spacer(),
                    if (isOut)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('نفذ',
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.w700)),
                      )
                    else if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('منخفض',
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                )
              else
                Text('خدمة',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: colors.textSecondary)),

              const SizedBox(height: 4),

              // Quantity adjust + actions row
              Row(
                children: [
                  if (!product.isService) ...[
                    // Decrease button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _localQty > 0 ? () => _adjustQty(-1) : null,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _localQty > 0
                              ? AppColors.error.withValues(alpha: 0.1)
                              : colors.border.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 14,
                          color: _localQty > 0
                              ? AppColors.error
                              : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    // Quantity number
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '$_localQty',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: qtyColor,
                        ),
                      ),
                    ),
                    // Increase button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _adjustQty(1),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 14, color: AppColors.success),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Edit
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.go('/inventory/${product.id}/edit'),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Delete
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onDelete(product.id),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.cairo(fontSize: 10, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72,
              color: context.appColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('لا توجد منتجات',
              style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text('إضافة منتج',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CatDef {
  final String? key;
  final String label;
  final IconData icon;
  const _CatDef(this.key, this.label, this.icon);
}
