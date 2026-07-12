import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/warranty_repository.dart';
import '../../data/warranty_model.dart';
import '../../data/warranty_claim_model.dart';

part 'warranty_state.dart';

class WarrantyCubit extends Cubit<WarrantyState> {
  final WarrantyRepository _repo;

  WarrantyCubit({WarrantyRepository? repo})
      : _repo = repo ?? WarrantyRepository(),
        super(WarrantyInitial());

  // ---------------------------------------------------------------------------
  // LOAD LIST
  // ---------------------------------------------------------------------------

  Future<void> loadAll({String? status, DateTime? from, DateTime? to}) async {
    emit(WarrantyLoading());
    try {
      final items = await _repo.getAll(status: status, from: from, to: to);
      final stats = await _repo.getStats();
      emit(WarrantyLoaded(items: items, stats: stats));
    } catch (e) {
      emit(WarrantyError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<void> create(WarrantyModel warranty) async {
    emit(WarrantyLoading());
    try {
      final id = await _repo.create(warranty);
      emit(WarrantySaved(id));
    } catch (e) {
      emit(WarrantyError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> update(WarrantyModel warranty) async {
    emit(WarrantyLoading());
    try {
      await _repo.update(warranty);
      emit(WarrantySaved(warranty.id));
    } catch (e) {
      emit(WarrantyError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // VOID
  // ---------------------------------------------------------------------------

  Future<void> voidWarranty(String id) async {
    try {
      await _repo.voidWarranty(id);
      emit(WarrantyVoided());
    } catch (e) {
      emit(WarrantyError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // CLAIMS
  // ---------------------------------------------------------------------------

  Future<void> addClaim(WarrantyClaimModel claim) async {
    try {
      await _repo.addClaim(claim);
    } catch (e) {
      emit(WarrantyError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // STATS ONLY
  // ---------------------------------------------------------------------------

  Future<void> loadStats() async {
    emit(WarrantyLoading());
    try {
      final stats = await _repo.getStats();
      emit(WarrantyLoaded(items: const [], stats: stats));
    } catch (e) {
      emit(WarrantyError(e.toString()));
    }
  }
}
