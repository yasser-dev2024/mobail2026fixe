import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/purchase_item_model.dart';
import '../../data/purchase_model.dart';
import '../../data/purchases_repository.dart';

part 'purchases_state.dart';

class PurchasesCubit extends Cubit<PurchasesState> {
  final PurchasesRepository _repo = PurchasesRepository();

  PurchasesCubit() : super(PurchasesInitial());

  Future<void> load({DateTime? from, DateTime? to, String? supplierId}) async {
    emit(PurchasesLoading());
    try {
      final now = DateTime.now();
      final defaultFrom = DateTime(now.year, now.month, 1);
      final purchases = await _repo.getAll(
        from: from ?? defaultFrom,
        to: to,
        supplierId: supplierId,
      );
      final stats = await _repo.getStats(from: from ?? defaultFrom, to: to);
      emit(PurchasesLoaded(purchases, stats));
    } catch (e) {
      emit(PurchasesError('فشل تحميل المشتريات: $e'));
    }
  }

  Future<void> loadDetail(String id) async {
    emit(PurchasesLoading());
    try {
      final purchase = await _repo.getById(id);
      if (purchase == null) {
        emit(PurchasesError('الفاتورة غير موجودة'));
        return;
      }
      final items = await _repo.getItems(id);
      emit(PurchasesDetailLoaded(purchase, items));
    } catch (e) {
      emit(PurchasesError('فشل تحميل تفاصيل الفاتورة: $e'));
    }
  }

  Future<void> create(
    PurchaseModel purchase,
    List<PurchaseItemModel> items,
  ) async {
    emit(PurchasesLoading());
    try {
      await _repo.create(purchase, items);
      emit(PurchasesSaved());
      await load();
    } catch (e) {
      emit(PurchasesError('فشل حفظ الفاتورة: $e'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      await load();
    } catch (e) {
      emit(PurchasesError('فشل حذف الفاتورة: $e'));
    }
  }

  Future<String> generateInvoiceNumber() => _repo.generateInvoiceNumber();
}
