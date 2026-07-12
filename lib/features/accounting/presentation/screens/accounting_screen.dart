import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../maintenance/data/maintenance_repository.dart';
import '../../data/accounting_repository.dart';
import '../../data/transaction_model.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final _repo = AccountingRepository();
  final _maintenanceRepo = MaintenanceRepository();
  List<TransactionModel> _transactions = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    await _maintenanceRepo.syncAllFinancials();
    final transactions = await _repo.getTransactions(from: start, to: now);
    final summary = await _repo.getSummary(from: start, to: now);
    if (!mounted) return;
    setState(() {
      _transactions = transactions;
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _openAddDialog() async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'expense';
    String category = 'other';
    String payment = 'cash';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إضافة عملية مالية'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration:
                          const InputDecoration(labelText: 'نوع العملية'),
                      items: const [
                        DropdownMenuItem(value: 'income', child: Text('دخل')),
                        DropdownMenuItem(
                            value: 'expense', child: Text('مصروف')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          type = value ?? 'expense';
                          category = type == 'income' ? 'sales' : 'other';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'التصنيف'),
                      items: _categories(type)
                          .map((item) => DropdownMenuItem(
                              value: item.$1, child: Text(item.$2)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? 'other'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: payment,
                      decoration:
                          const InputDecoration(labelText: 'طريقة الدفع'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                        DropdownMenuItem(value: 'card', child: Text('شبكة')),
                        DropdownMenuItem(
                            value: 'transfer', child: Text('تحويل')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => payment = value ?? 'cash'),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (descCtrl.text.trim().isEmpty || amount <= 0) return;
                  await _repo.addTransaction(
                    TransactionModel.create(
                      type: type,
                      category: category,
                      description: descCtrl.text.trim(),
                      amount: amount,
                      paymentMethod: payment,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      createdBy: 'admin',
                    ),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    descCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (saved == true) _load();
  }

  List<(String, String)> _categories(String type) {
    if (type == 'income') {
      return const [
        ('sales', 'مبيعات'),
        ('maintenance', 'صيانة'),
        ('other', 'أخرى')
      ];
    }
    return const [
      ('salary', 'رواتب'),
      ('rent', 'إيجار'),
      ('utilities', 'خدمات'),
      ('purchase', 'مشتريات'),
      ('maintenance', 'صيانة'),
      ('other', 'أخرى'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final money = NumberFormat('#,##0.00', 'ar');
    final income = (_summary['total_income'] as num?)?.toDouble() ?? 0;
    final expense = (_summary['total_expense'] as num?)?.toDouble() ?? 0;
    final net = (_summary['net_profit'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'دخل الشهر',
                          value: '${money.format(income)} ر.س',
                          icon: Icons.trending_up_rounded,
                          gradient: AppColors.successGradient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'مصروفات الشهر',
                          value: '${money.format(expense)} ر.س',
                          icon: Icons.trending_down_rounded,
                          gradient: AppColors.errorGradient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'صافي الربح',
                          value: '${money.format(net)} ر.س',
                          icon: Icons.account_balance_wallet_rounded,
                          gradient: net >= 0
                              ? AppColors.primaryGradient
                              : AppColors.warningGradient,
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
                          title: 'سجل العمليات',
                          trailing: ElevatedButton.icon(
                            onPressed: _openAddDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('إضافة عملية'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_transactions.isEmpty)
                          const EmptyState(
                            message: 'لا توجد عمليات مالية هذا الشهر',
                            icon: Icons.receipt_long_rounded,
                          )
                        else
                          ..._transactions
                              .map((tx) => _TransactionTile(tx: tx)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('عملية جديدة'),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final money = NumberFormat('#,##0.00', 'ar');
    final date = DateFormat('dd/MM/yyyy HH:mm', 'ar')
        .format(DateTime.fromMillisecondsSinceEpoch(tx.transactionDate));
    final isIncome = tx.type == 'income';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            (isIncome ? AppColors.success : AppColors.error).withAlpha(25),
        child: Icon(
          isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: isIncome ? AppColors.success : AppColors.error,
        ),
      ),
      title: Text(tx.description,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${tx.categoryLabel} | $date'),
      trailing: Text(
        '${isIncome ? '+' : '-'}${money.format(tx.amount)} ر.س',
        style: TextStyle(
          color: isIncome ? AppColors.success : AppColors.error,
          fontWeight: FontWeight.w800,
        ),
      ),
      textColor: colors.textPrimary,
    );
  }
}
