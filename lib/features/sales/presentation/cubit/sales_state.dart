part of 'sales_cubit.dart';

abstract class SalesState {}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesLoaded extends SalesState {
  final List<SaleModel> sales;
  final Map<String, dynamic> stats;
  SalesLoaded(this.sales, this.stats);
}

class SalesError extends SalesState {
  final String message;
  SalesError(this.message);
}

class SalesSaved extends SalesState {}

class SalesDetailLoaded extends SalesState {
  final SaleModel sale;
  final List<SaleItemModel> items;
  SalesDetailLoaded(this.sale, this.items);
}
