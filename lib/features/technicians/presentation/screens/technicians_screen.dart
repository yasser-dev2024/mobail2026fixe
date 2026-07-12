import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/data/user_model.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/product_model.dart';
import '../../data/technician_custody_model.dart';
import '../../data/technician_repository.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final _db = DatabaseService();
  final _repo = TechnicianRepository();
  final _inventoryRepo = InventoryRepository();
  List<UserModel> _technicians = [];
  List<ProductModel> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await _db.query(
      'users',
      where: 'deleted_at IS NULL AND role = ?',
      whereArgs: [AppConstants.roleTechnician],
      orderBy: 'name ASC',
    );
    final products = await _inventoryRepo.getAll();
    if (!mounted) return;
    setState(() {
      _technicians = users.map(UserModel.fromMap).toList();
      _products = products.where((p) => !p.isService).toList();
      _loading = false;
    });
  }

  Future<void> _openCustodyDialog() async {
    if (_technicians.isEmpty || _products.isEmpty) return;
    UserModel technician = _technicians.first;
    ProductModel product = _products.first;
    final qtyCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إسناد عهدة لفني'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<UserModel>(
                    value: technician,
                    decoration: const InputDecoration(labelText: 'الفني'),
                    items: _technicians
                        .map((user) => DropdownMenuItem(
                            value: user, child: Text(user.name)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => technician = value ?? technician),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductModel>(
                    value: product,
                    decoration: const InputDecoration(labelText: 'القطعة'),
                    items: _products
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                  '${item.name} - المتاح: ${item.quantity}'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => product = value ?? product),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0 || qty > product.quantity) return;
                  final now = DateTime.now().millisecondsSinceEpoch;
                  await _repo.addCustody(
                    TechnicianCustodyModel(
                      id: const Uuid().v4(),
                      technicianId: technician.id,
                      productId: product.id,
                      productName: product.name,
                      quantityReceived: qty,
                      quantityUsed: 0,
                      quantityReturned: 0,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      receivedAt: now,
                      createdAt: now,
                    ),
                  );
                  await _inventoryRepo.decreaseQuantity(product.id, qty);
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    qtyCtrl.dispose();
    notesCtrl.dispose();
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'عدد الفنيين',
                        value: '${_technicians.length}',
                        icon: Icons.engineering_rounded,
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'قطع متاحة للعهدة',
                        value: '${_products.length}',
                        icon: Icons.handyman_rounded,
                        gradient: AppColors.tealGradient,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'الفنيون والعهدة',
                        trailing: ElevatedButton.icon(
                          onPressed: _technicians.isEmpty || _products.isEmpty
                              ? null
                              : _openCustodyDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إسناد عهدة'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_technicians.isEmpty)
                        EmptyState(
                          message: 'لا يوجد مستخدمون بدور فني',
                          icon: Icons.engineering_outlined,
                          action: ElevatedButton.icon(
                            onPressed: () => context.go('/users'),
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Text('إضافة فني'),
                          ),
                        )
                      else
                        ..._technicians.map(
                            (user) => _TechnicianCard(user: user, repo: _repo)),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _technicians.isEmpty || _products.isEmpty
            ? null
            : _openCustodyDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('عهدة جديدة'),
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final UserModel user;
  final TechnicianRepository repo;

  const _TechnicianCard({required this.user, required this.repo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.getTechnicianSummary(user.id),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: const Icon(Icons.engineering_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(user.phone ?? user.username),
                    ],
                  ),
                ),
                _miniStat('مستلم', '${data['total_received'] ?? 0}'),
                _miniStat('مستخدم', '${data['total_used'] ?? 0}'),
                _miniStat('الرصيد', '${data['balance'] ?? 0}'),
                _miniStat('تذاكر نشطة', '${data['active_tickets'] ?? 0}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
