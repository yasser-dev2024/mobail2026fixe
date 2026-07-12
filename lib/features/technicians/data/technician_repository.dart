import '../../../core/database/database_service.dart';
import 'technician_custody_model.dart';

class TechnicianRepository {
  static final TechnicianRepository _instance =
      TechnicianRepository._internal();
  factory TechnicianRepository() => _instance;
  TechnicianRepository._internal();

  final DatabaseService _db = DatabaseService();

  // ---------------------------------------------------------------------------
  // Custody management
  // ---------------------------------------------------------------------------

  /// Insert a new custody record.
  Future<void> addCustody(TechnicianCustodyModel custody) async {
    await _db.insert('technician_custody', custody.toMap());
  }

  /// Get all custody records belonging to [technicianId].
  Future<List<TechnicianCustodyModel>> getCustodiesByTechnician(
      String technicianId) async {
    final rows = await _db.query(
      'technician_custody',
      where: 'technician_id = ?',
      whereArgs: [technicianId],
      orderBy: 'created_at DESC',
    );
    return rows.map(TechnicianCustodyModel.fromMap).toList();
  }

  /// Record that [quantity] parts from custody [custodyId] have been returned.
  ///
  /// Increments quantity_returned by [quantity].
  /// If the total returned now equals quantity_received, sets returned_at to now.
  Future<void> returnParts(String custodyId, int quantity) async {
    // Fetch current record to compute totals.
    final rows = await _db.query(
      'technician_custody',
      where: 'id = ?',
      whereArgs: [custodyId],
      limit: 1,
    );

    if (rows.isEmpty) return;

    final custody = TechnicianCustodyModel.fromMap(rows.first);
    final newReturned = custody.quantityReturned + quantity;
    final allReturned = newReturned >= custody.quantityReceived;

    await _db.update(
      'technician_custody',
      {
        'quantity_returned': newReturned,
        if (allReturned) 'returned_at': DateTime.now().millisecondsSinceEpoch,
      },
      custodyId,
    );
  }

  // ---------------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------------

  /// Get an aggregate summary for [technicianId].
  ///
  /// Returns:
  ///   total_received  – total quantity received across all custody records
  ///   total_used      – total quantity used
  ///   total_returned  – total quantity returned
  ///   balance         – received - used - returned
  ///   active_tickets  – count of maintenance tickets not yet delivered/cancelled
  Future<Map<String, dynamic>> getTechnicianSummary(String technicianId) async {
    // --- Custody aggregates ---
    final custodyRows = await _db.rawQuery(
      '''SELECT
          SUM(quantity_received) as total_received,
          SUM(quantity_used)     as total_used,
          SUM(quantity_returned) as total_returned
         FROM technician_custody
         WHERE technician_id = ?''',
      [technicianId],
    );

    final row =
        custodyRows.isNotEmpty ? custodyRows.first : <String, dynamic>{};

    final totalReceived = (row['total_received'] as num?)?.toInt() ?? 0;
    final totalUsed = (row['total_used'] as num?)?.toInt() ?? 0;
    final totalReturned = (row['total_returned'] as num?)?.toInt() ?? 0;

    // --- Active maintenance tickets ---
    final shopId = await _db.getCurrentShopId();
    final ticketRows = await _db.rawQuery(
      '''SELECT COUNT(*) as active_count
         FROM maintenance
         WHERE shop_id = ?
           AND technician_id = ?
           AND status NOT IN ('delivered', 'cancelled', 'abandoned')
           AND deleted_at IS NULL''',
      [shopId, technicianId],
    );

    final activeTickets = (ticketRows.isNotEmpty
            ? ticketRows.first['active_count'] as int?
            : null) ??
        0;

    return {
      'total_received': totalReceived,
      'total_used': totalUsed,
      'total_returned': totalReturned,
      'balance': totalReceived - totalUsed - totalReturned,
      'active_tickets': activeTickets,
    };
  }
}
