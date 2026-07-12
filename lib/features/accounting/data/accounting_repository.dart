import '../../../core/database/database_service.dart';
import 'transaction_model.dart';

class AccountingRepository {
  static final AccountingRepository _instance =
      AccountingRepository._internal();
  factory AccountingRepository() => _instance;
  AccountingRepository._internal();

  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // Core CRUD
  // ---------------------------------------------------------------------------

  /// Insert a transaction record.
  Future<void> addTransaction(TransactionModel tx) async {
    await _db.insert('transactions', tx.toMap());
  }

  /// Soft-delete a transaction by [id].
  Future<void> deleteTransaction(String id) async {
    await _db.softDelete('transactions', id);
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Get transactions with optional filters.
  /// [type]     – 'income' or 'expense'
  /// [category] – specific category string
  /// [from]/[to] – date range based on transaction_date field (epoch ms)
  /// Excludes soft-deleted records (deleted_at IS NULL).
  /// Orders by transaction_date DESC.
  Future<List<TransactionModel>> getTransactions({
    String? type,
    String? category,
    DateTime? from,
    DateTime? to,
  }) async {
    final conditions = <String>['deleted_at IS NULL'];
    final args = <dynamic>[];

    if (type != null && type.isNotEmpty) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (from != null) {
      conditions.add('transaction_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
      conditions.add('transaction_date <= ?');
      args.add(endOfDay.millisecondsSinceEpoch);
    }

    final rows = await _db.rawQuery(
      'SELECT * FROM transactions WHERE ${conditions.join(' AND ')} ORDER BY transaction_date DESC',
      args.isEmpty ? null : args,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Summaries
  // ---------------------------------------------------------------------------

  /// Summary for a date range.
  /// Returns: total_income, total_expense, net_profit, transaction_count.
  Future<Map<String, dynamic>> getSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final conditions = <String>['deleted_at IS NULL'];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('transaction_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
      conditions.add('transaction_date <= ?');
      args.add(endOfDay.millisecondsSinceEpoch);
    }

    final where = conditions.join(' AND ');

    final rows = await _db.rawQuery(
      '''SELECT
          SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as total_income,
          SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as total_expense,
          COUNT(*) as transaction_count
         FROM transactions
         WHERE $where''',
      args.isEmpty ? null : args,
    );

    final row = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    final totalIncome = (row['total_income'] as num?)?.toDouble() ?? 0.0;
    final totalExpense = (row['total_expense'] as num?)?.toDouble() ?? 0.0;
    final count = (row['transaction_count'] as num?)?.toInt() ?? 0;

    return {
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'net_profit': totalIncome - totalExpense,
      'transaction_count': count,
    };
  }

  /// Daily summary for a specific date.
  /// Returns the same structure as [getSummary].
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return getSummary(from: start, to: end);
  }

  /// Monthly report: returns a list of maps, one per day that has transactions.
  /// Each map has keys: date (YYYY-MM-DD), income: double, expense: double, net: double.
  Future<List<Map<String, dynamic>>> getMonthlyReport(
      int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final startOfNextMonth = DateTime(year, month + 1, 1);

    final rows = await _db.rawQuery(
      '''SELECT
          strftime('%Y-%m-%d', datetime(transaction_date / 1000, 'unixepoch', 'localtime')) as date,
          SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income,
          SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expense
         FROM transactions
         WHERE deleted_at IS NULL
           AND transaction_date >= ?
           AND transaction_date < ?
         GROUP BY strftime('%Y-%m-%d', datetime(transaction_date / 1000, 'unixepoch', 'localtime'))
         ORDER BY date ASC''',
      [
        startOfMonth.millisecondsSinceEpoch,
        startOfNextMonth.millisecondsSinceEpoch,
      ],
    );

    return rows.map((r) {
      final income = (r['income'] as num?)?.toDouble() ?? 0.0;
      final expense = (r['expense'] as num?)?.toDouble() ?? 0.0;
      return {
        'date': r['date'] as String,
        'income': income,
        'expense': expense,
        'net': income - expense,
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Additional helpers
  // ---------------------------------------------------------------------------

  /// Returns expense totals grouped by category for a date range.
  Future<Map<String, double>> getExpensesByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final conditions = <String>["deleted_at IS NULL AND type = 'expense'"];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('transaction_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
      conditions.add('transaction_date <= ?');
      args.add(endOfDay.millisecondsSinceEpoch);
    }

    final rows = await _db.rawQuery(
      '''SELECT category, COALESCE(SUM(amount), 0) as total
         FROM transactions
         WHERE ${conditions.join(' AND ')}
         GROUP BY category
         ORDER BY total DESC''',
      args.isEmpty ? null : args,
    );

    final map = <String, double>{};
    for (final row in rows) {
      final cat = (row['category'] as String?) ?? 'other';
      map[cat] = (row['total'] as num?)?.toDouble() ?? 0.0;
    }
    return map;
  }

  /// Returns monthly income/expense aggregates for the last 6 months.
  Future<List<Map<String, dynamic>>> getLast6MonthsData() async {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd =
          DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);

      final rows = await _db.rawQuery(
        '''SELECT
            COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
            COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expenses
           FROM transactions
           WHERE deleted_at IS NULL
             AND transaction_date >= ?
             AND transaction_date <= ?''',
        [
          monthStart.millisecondsSinceEpoch,
          monthEnd.millisecondsSinceEpoch,
        ],
      );

      final income = (rows.first['income'] as num?)?.toDouble() ?? 0.0;
      final expenses = (rows.first['expenses'] as num?)?.toDouble() ?? 0.0;
      result.add({
        'month': monthStart,
        'income': income,
        'expenses': expenses,
        'profit': income - expenses,
      });
    }
    return result;
  }
}
