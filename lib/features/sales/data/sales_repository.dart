import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import 'sale_item_model.dart';
import 'sale_model.dart';

class SalesRepository {
  static final SalesRepository _instance = SalesRepository._internal();
  factory SalesRepository() => _instance;
  SalesRepository._internal();

  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns all sales that have not been soft-deleted.
  /// Optionally filtered by [from] / [to] (inclusive, compared against
  /// created_at milliseconds-since-epoch) and by [customerId].
  Future<List<SaleModel>> getAll({
    DateTime? from,
    DateTime? to,
    String? customerId,
  }) async {
    final conditions = <String>['deleted_at IS NULL'];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      conditions.add('created_at <= ?');
      args.add(endOfDay.millisecondsSinceEpoch);
    }
    if (customerId != null && customerId.isNotEmpty) {
      conditions.add('customer_id = ?');
      args.add(customerId);
    }

    final rows = await _db.rawQuery(
      'SELECT * FROM sales WHERE ${conditions.join(' AND ')} ORDER BY created_at DESC',
      args.isEmpty ? null : args,
    );
    return rows.map(SaleModel.fromMap).toList();
  }

  /// Returns the sale with [id] (not soft-deleted), with its items already
  /// loaded into [SaleModel.items].  Returns null when not found.
  Future<SaleModel?> getById(String id) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM sales WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;

    final sale = SaleModel.fromMap(rows.first);
    final items = await getItems(id);
    return sale.copyWith(items: items);
  }

  /// Loads the line-items for the sale identified by [saleId].
  Future<List<SaleItemModel>> getItems(String saleId) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM sale_items WHERE sale_id = ?',
      [saleId],
    );
    return rows.map(SaleItemModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Creates a sale together with all of its [items] inside a single SQLite
  /// transaction.
  ///
  /// Steps performed atomically:
  ///   1. Insert the sale record.
  ///   2. Insert every sale item.
  ///   3. For each item whose [SaleItemModel.productId] is non-null, decrease
  ///      the product's quantity in the `products` table (floored at 0).
  ///   4. If [SaleModel.customerId] is set, update the customer's
  ///      total_spent, visit_count, and last_visit.
  ///   5. Insert an income record into the `transactions` table.
  ///
  /// Returns the newly created sale id.
  Future<String> create(SaleModel sale, List<SaleItemModel> items) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final database = await _db.db;

    await database.transaction((txn) async {
      // 1. Insert the sale record.
      await txn.insert(
        'sales',
        sale.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2 & 3. Insert items and decrease product inventory.
      for (final item in items) {
        await txn.insert(
          'sale_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (item.productId != null) {
          await txn.rawUpdate(
            'UPDATE products '
            'SET quantity = MAX(0, quantity - ?), updated_at = ? '
            'WHERE id = ?',
            [item.quantity, now, item.productId],
          );
        }
      }

      // 4. Update customer stats when the sale is linked to a customer.
      if (sale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers '
          'SET total_spent = total_spent + ?, '
          '    visit_count = visit_count + 1, '
          '    last_visit  = ?, '
          '    updated_at  = ? '
          'WHERE id = ?',
          [sale.total, now, now, sale.customerId],
        );
      }

      // 5. Record the income transaction.
      final txId = const Uuid().v4();
      await txn.insert(
        'transactions',
        {
          'id': txId,
          'type': 'income',
          'category': 'sales',
          'description': 'مبيعات - ${sale.invoiceNumber}',
          'amount': sale.total,
          'reference_id': sale.id,
          'reference_type': 'sale',
          'payment_method': sale.paymentMethod,
          'transaction_date': now,
          'notes': null,
          'created_by': sale.createdBy,
          'created_at': now,
          'deleted_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return sale.id;
  }

  /// Soft-deletes the sale with [id].
  Future<void> delete(String id) async {
    await _db.softDelete('sales', id);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Generates a unique invoice number in the format **INV-YYYYMMDD-XXXX**
  /// where XXXX is a zero-padded daily sequence number.
  Future<String> generateInvoiceNumber() async {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);

    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    // Count all sales created today (including soft-deleted) to avoid reusing
    // sequence numbers after a deletion.
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sales WHERE created_at >= ? AND created_at <= ?',
      [startOfDay, endOfDay],
    );
    final count = (rows.first['cnt'] as int? ?? 0) + 1;
    final seq = count.toString().padLeft(4, '0');
    return 'INV-$datePart-$seq';
  }

  /// Returns today's aggregate sales statistics.
  ///
  /// The returned map contains:
  /// - `totalSales`   – number of sales today (int)
  /// - `totalRevenue` – sum of sale totals today (double)
  /// - `totalProfit`  – revenue minus cost-of-goods-sold today (double)
  ///
  /// Profit per item = (unit_price − purchase_price) × quantity.
  /// When a product has no purchase_price on record the item contributes 0 to
  /// the cost (i.e. full unit_price is treated as profit).
  Future<Map<String, dynamic>> getTodayStats() async {
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    // Total number of sales and revenue for today.
    final salesRows = await _db.rawQuery(
      '''
      SELECT
        COUNT(*)                   AS total_sales,
        COALESCE(SUM(total), 0)   AS total_revenue
      FROM sales
      WHERE deleted_at IS NULL
        AND created_at >= ?
        AND created_at <= ?
      ''',
      [startOfDay, endOfDay],
    );

    // Profit = SUM((unit_price - purchase_price) * quantity) across all items
    // belonging to today's non-deleted sales.  Items linked to products that
    // have no purchase_price default purchase_price to 0 so the full
    // unit_price counts as profit.
    final profitRows = await _db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          (si.unit_price - COALESCE(p.purchase_price, 0)) * si.quantity
        ), 0
      ) AS total_profit
      FROM sale_items si
      LEFT JOIN products p ON p.id = si.product_id
      WHERE si.sale_id IN (
        SELECT id
        FROM   sales
        WHERE  deleted_at IS NULL
          AND  created_at >= ?
          AND  created_at <= ?
      )
      ''',
      [startOfDay, endOfDay],
    );

    return {
      'totalSales': (salesRows.first['total_sales'] as int?) ?? 0,
      'totalRevenue':
          (salesRows.first['total_revenue'] as num?)?.toDouble() ?? 0.0,
      'totalProfit':
          (profitRows.first['total_profit'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Returns aggregate statistics for sales in the optional date range.
  Future<Map<String, dynamic>> getStats({DateTime? from, DateTime? to}) async {
    final conditions = <String>['deleted_at IS NULL'];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      conditions.add('created_at <= ?');
      args.add(endOfDay.millisecondsSinceEpoch);
    }

    final where = conditions.join(' AND ');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count, COALESCE(SUM(total), 0) AS revenue FROM sales WHERE $where',
      args.isEmpty ? null : args,
    );

    return {
      'count': (rows.first['count'] as int?) ?? 0,
      'revenue': (rows.first['revenue'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
