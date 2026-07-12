part of 'maintenance_cubit.dart';

abstract class MaintenanceState {}

class MaintenanceInitial extends MaintenanceState {}

class MaintenanceLoading extends MaintenanceState {}

class MaintenanceLoaded extends MaintenanceState {
  final List<MaintenanceModel> items;
  final Map<String, dynamic> stats;

  MaintenanceLoaded({required this.items, required this.stats});
}

class MaintenanceSingleLoaded extends MaintenanceState {
  final MaintenanceModel maintenance;
  final List<MaintenancePartModel> parts;
  final List<MaintenanceImageModel> images;

  MaintenanceSingleLoaded({
    required this.maintenance,
    required this.parts,
    required this.images,
  });
}

class MaintenanceError extends MaintenanceState {
  final String message;
  MaintenanceError(this.message);
}

class MaintenanceSaved extends MaintenanceState {
  final String id;
  MaintenanceSaved(this.id);
}

class MaintenanceStatusUpdated extends MaintenanceState {}

class MaintenanceDeleted extends MaintenanceState {}
