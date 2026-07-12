part of 'inventory_cubit.dart';

abstract class InventoryState {}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<ProductModel> items;
  final Map<String, dynamic> stats;

  InventoryLoaded({required this.items, required this.stats});
}

class InventoryError extends InventoryState {
  final String message;
  InventoryError(this.message);
}

class InventorySaved extends InventoryState {
  final String id;
  InventorySaved(this.id);
}

class InventoryDeleted extends InventoryState {}
