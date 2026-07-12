import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/maintenance_repository.dart';
import '../../data/maintenance_model.dart';
import '../../data/maintenance_part_model.dart';
import '../../data/maintenance_image_model.dart';
import '../../../device_photos/data/device_photo_repository.dart';

part 'maintenance_state.dart';

class MaintenanceCubit extends Cubit<MaintenanceState> {
  final MaintenanceRepository _repo;

  MaintenanceCubit({MaintenanceRepository? repo})
      : _repo = repo ?? MaintenanceRepository(),
        super(MaintenanceInitial());

  // ---------------------------------------------------------------------------
  // LOAD LIST
  // ---------------------------------------------------------------------------

  Future<void> loadAll({
    String? status,
    List<String>? statuses,
    String? search,
  }) async {
    emit(MaintenanceLoading());
    try {
      final items = await _repo.getAll(
        status: status,
        statuses: statuses,
        search: search,
      );
      final stats = await _repo.getDashboardStats();
      emit(MaintenanceLoaded(items: items, stats: stats));
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD SINGLE
  // ---------------------------------------------------------------------------

  Future<void> loadById(String id) async {
    emit(MaintenanceLoading());
    try {
      final maintenance = await _repo.getById(id);
      if (maintenance == null) {
        emit(MaintenanceError('السجل غير موجود'));
        return;
      }
      final parts = await _repo.getParts(id);
      final images = await _repo.getImages(id);
      emit(MaintenanceSingleLoaded(
        maintenance: maintenance,
        parts: parts,
        images: images,
      ));
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<void> create(
    MaintenanceModel maintenance,
    List<MaintenancePartModel> parts,
    List<String> imagePaths,
  ) async {
    emit(MaintenanceLoading());
    try {
      final id = await _repo.create(maintenance);

      for (final part in parts) {
        await _repo.addPart(part.copyWith(maintenanceId: id));
      }

      for (final path in imagePaths) {
        await DevicePhotoRepository().saveFromSource(
          sourcePath: path,
          customerId: maintenance.customerId,
          deviceId: maintenance.deviceId,
          maintenanceId: id,
        );
      }

      emit(MaintenanceSaved(id));
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> update(MaintenanceModel maintenance) async {
    emit(MaintenanceLoading());
    try {
      await _repo.update(maintenance);
      emit(MaintenanceSaved(maintenance.id));
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE STATUS
  // ---------------------------------------------------------------------------

  Future<void> updateStatus(
    String id,
    String newStatus, {
    String? reason,
    String? notes,
  }) async {
    try {
      final deliveredAt = newStatus == 'delivered'
          ? DateTime.now().millisecondsSinceEpoch
          : null;
      await _repo.updateStatus(
        id,
        newStatus,
        deliveredAt: deliveredAt,
        reason: reason,
        notes: notes,
      );
      emit(MaintenanceStatusUpdated());
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      emit(MaintenanceDeleted());
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // PARTS
  // ---------------------------------------------------------------------------

  Future<void> addPart(MaintenancePartModel part) async {
    try {
      await _repo.addPart(part);
      // Reload the single maintenance to refresh parts list
      await loadById(part.maintenanceId);
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  Future<void> removePart(String partId, String maintenanceId) async {
    try {
      await _repo.removePart(partId);
      await loadById(maintenanceId);
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD STATS
  // ---------------------------------------------------------------------------

  Future<void> loadDashboardStats() async {
    emit(MaintenanceLoading());
    try {
      final stats = await _repo.getDashboardStats();
      emit(MaintenanceLoaded(items: const [], stats: stats));
    } catch (e) {
      emit(MaintenanceError(e.toString()));
    }
  }
}
