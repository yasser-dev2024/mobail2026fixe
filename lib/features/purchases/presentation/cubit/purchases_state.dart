part of 'purchases_cubit.dart';

abstract class PurchasesState {}

class PurchasesInitial extends PurchasesState {}

class PurchasesLoading extends PurchasesState {}

class PurchasesLoaded extends PurchasesState {
  final List<PurchaseModel> purchases;
  final Map<String, dynamic> stats;
  PurchasesLoaded(this.purchases, this.stats);
}

class PurchasesError extends PurchasesState {
  final String message;
  PurchasesError(this.message);
}

class PurchasesSaved extends PurchasesState {}

class PurchasesDetailLoaded extends PurchasesState {
  final PurchaseModel purchase;
  final List<PurchaseItemModel> items;
  PurchasesDetailLoaded(this.purchase, this.items);
}
