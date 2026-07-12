import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_service.dart';
import 'purchase_item_model.dart';
import 'purchase_model.dart';

class PurchasesRepository {
  static final PurchasesRepository _instance = PurchasesRepository._internal();
  factory PurchasesRepository() => _instance;
  PurchasesRepository._internal();

  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns all purchases that have not been soft-deleted.
  /// Optionally filtered by [from] / [to] (inclusive, compared against
  /// created_at milliseconds-since-epoch) and by [supplierId].
  Future<List<PurchaseModel>> getAll({
    DateTime? from,
    DateTime? to,
    String? supplierId,
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
    if (supplierId != null && supplierId.isNotEmpty) {
      conditions.add('supplier_id = ?');
      args.add(supplierId);
    }

    final rows = await _db.rawQuery(
      'SELECT * FROM purchases WHERE ${conditions.join(' AND ')} ORDER BY created_at DESC',
      args.isEmpty ? null : args,
    );
    return rows.map(PurchaseModel.fromMap).toList();
  }

  /// Returns the purchase with [id] (not soft-deleted), with its items
  /// already loaded into [PurchaseModel.items].  Returns null when not found.
  Future<PurchaseModel?> getById(String id) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM purchases WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;

    final purchase = PurchaseModel.fromMap(rows.first);
    final items = await getItems(id);
    return purchase.copyWith(items: items);
  }

  /// Loads the line-items for the purchase identified by [purchaseId].
  Future<List<PurchaseItemModel>> getItems(String purchaseId) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM purchase_items WHERE purchase_id = ?',
      [purchaseId],
    );
    return rows.map(PurchaseItemModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Creates a purchase together with all of its [items] inside a single
  /// SQLite transaction.
  ///
  /// Steps performed atomically:
  ///   1. Insert the purchase record.
  ///   2. Insert every purchase item.
  ///   3. For each item whose [PurchaseItemModel.productId] is non-null,
  ///      increase the product's quantity in the `products` table.
  ///
  /// Returns the newly created purchase id.
  Future<String> create(
    PurchaseModel purchase,
    List<PurchaseItemModel> items,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final database = await _db.db;

    await database.transaction((txn) async {
      // 1. Insert the purchase record.
      await txn.insert(
        'purchases',
        purchase.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2 & 3. Insert items and update product inventory.
      for (final item in items) {
        await txn.insert(
          'purchase_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (item.productId != null) {
          // Increase stock AND update purchase_price to latest cost paid.
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ?, purchase_price = ?, updated_at = ? WHERE id = ?',
            [item.quantity, item.unitPrice, now, item.productId],
          );
        }
      }
    });

    return purchase.id;
  }

  /// Soft-deletes the purchase with [id].
  ///
  /// Note: this does NOT reverse the inventory changes that were applied when
  /// the purchase was originally created.
  Future<void> delete(String id) async {
    await _db.softDelete('purchases', id);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Generates a unique invoice number in the format **PUR-YYYYMMDD-XXXX**
  /// where XXXX is a zero-padded daily sequence number.
  Future<String> generateInvoiceNumber() async {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);
    final prefix = 'PUR-$datePart-';

    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    // Count all purchases created today (including soft-deleted ones) to avoid
    // re-using sequence numbers after a deletion.
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM purchases WHERE created_at >= ? AND created_at <= ?',
      [startOfDay, endOfDay],
    );
    final count = (rows.first['cnt'] as int? ?? 0) + 1;
    final seq = count.toString().padLeft(4, '0');
    return '$prefix$seq';
  }

  /// Returns aggregate statistics for purchases in the optional date range.
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
      'SELECT COUNT(*) AS count, COALESCE(SUM(total), 0) AS total FROM purchases WHERE $where',
      args.isEmpty ? null : args,
    );

    return {
      'count': (rows.first['count'] as int?) ?? 0,
      'total': (rows.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
