part of 'warranty_cubit.dart';

abstract class WarrantyState {}

class WarrantyInitial extends WarrantyState {}

class WarrantyLoading extends WarrantyState {}

class WarrantyLoaded extends WarrantyState {
  final List<WarrantyModel> items;
  final Map<String, dynamic> stats;

  WarrantyLoaded({required this.items, required this.stats});
}

class WarrantyError extends WarrantyState {
  final String message;
  WarrantyError(this.message);
}

class WarrantySaved extends WarrantyState {
  final String id;
  WarrantySaved(this.id);
}

class WarrantyVoided extends WarrantyState {}
