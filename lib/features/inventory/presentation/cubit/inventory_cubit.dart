import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/inventory_repository.dart';
import '../../data/product_model.dart';

part 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository _repo;

  // Track last filter params for silent reloads (no loading spinner).
  String? _lastCategory;
  String? _lastSearch;
  bool? _lastLowStock;
  bool? _lastOutOfStock;

  InventoryCubit({InventoryRepository? repo})
      : _repo = repo ?? InventoryRepository(),
        super(InventoryInitial());

  // ---------------------------------------------------------------------------
  // LOAD LIST
  // ---------------------------------------------------------------------------

  Future<void> loadAll({
    String? categoryKey,
    String? search,
    bool? lowStock,
    bool? outOfStock,
  }) async {
    _lastCategory = categoryKey;
    _lastSearch = search;
    _lastLowStock = lowStock;
    _lastOutOfStock = outOfStock;
    emit(InventoryLoading());
    try {
      final items = await _repo.getAll(
        categoryKey: categoryKey,
        search: search,
        lowStock: lowStock,
        outOfStock: outOfStock,
      );
      final stats = await _repo.getStats();
      emit(InventoryLoaded(items: items, stats: stats));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<void> create(ProductModel product) async {
    emit(InventoryLoading());
    try {
      final id = await _repo.create(product);
      emit(InventorySaved(id));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> update(ProductModel product) async {
    emit(InventoryLoading());
    try {
      await _repo.update(product);
      emit(InventorySaved(product.id));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      emit(InventoryDeleted());
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // QUANTITY
  // ---------------------------------------------------------------------------

  Future<void> decreaseQuantity(String productId, int qty) async {
    try {
      await _repo.decreaseQuantity(productId, qty);
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> increaseQuantity(String productId, int qty) async {
    try {
      await _repo.increaseQuantity(productId, qty);
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  /// Adjust quantity by [delta] (+/-) then silently reload with last filters
  /// — no InventoryLoading emitted so cards don't flicker.
  Future<void> adjustQuantity(String productId, int delta) async {
    try {
      if (delta > 0) {
        await _repo.increaseQuantity(productId, delta);
      } else if (delta < 0) {
        await _repo.decreaseQuantity(productId, delta.abs());
      }
      final items = await _repo.getAll(
        categoryKey: _lastCategory,
        search: _lastSearch,
        lowStock: _lastLowStock,
        outOfStock: _lastOutOfStock,
      );
      final stats = await _repo.getStats();
      emit(InventoryLoaded(items: items, stats: stats));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // STATS ONLY
  // ---------------------------------------------------------------------------

  Future<void> loadStats() async {
    emit(InventoryLoading());
    try {
      final stats = await _repo.getStats();
      emit(InventoryLoaded(items: const [], stats: stats));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }
}
