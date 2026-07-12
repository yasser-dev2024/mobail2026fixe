import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/supplier_model.dart';
import '../../data/suppliers_repository.dart';

part 'suppliers_state.dart';

class SuppliersCubit extends Cubit<SuppliersState> {
  final SuppliersRepository _repo = SuppliersRepository();

  SuppliersCubit() : super(SuppliersInitial());

  Future<void> load({String? search}) async {
    emit(SuppliersLoading());
    try {
      final suppliers = await _repo.getAll(search: search);
      emit(SuppliersLoaded(suppliers));
    } catch (e) {
      emit(SuppliersError('فشل تحميل الموردين: $e'));
    }
  }

  Future<void> save(SupplierModel supplier, {bool isNew = true}) async {
    try {
      if (isNew) {
        await _repo.create(supplier);
      } else {
        await _repo.update(supplier);
      }
      emit(SuppliersSaved());
      await load();
    } catch (e) {
      emit(SuppliersError('فشل حفظ المورد: $e'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      await load();
    } catch (e) {
      emit(SuppliersError('فشل حذف المورد: $e'));
    }
  }
}
