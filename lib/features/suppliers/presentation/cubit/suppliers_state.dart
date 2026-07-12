part of 'suppliers_cubit.dart';

abstract class SuppliersState {}

class SuppliersInitial extends SuppliersState {}

class SuppliersLoading extends SuppliersState {}

class SuppliersLoaded extends SuppliersState {
  final List<SupplierModel> suppliers;
  SuppliersLoaded(this.suppliers);
}

class SuppliersError extends SuppliersState {
  final String message;
  SuppliersError(this.message);
}

class SuppliersSaved extends SuppliersState {}
