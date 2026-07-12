import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sale_item_model.dart';
import '../../data/sale_model.dart';
import '../../data/sales_repository.dart';

part 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository _repo = SalesRepository();

  SalesCubit() : super(SalesInitial());

  Future<void> load({DateTime? from, DateTime? to, String? customerId}) async {
    emit(SalesLoading());
    try {
      final sales =
          await _repo.getAll(from: from, to: to, customerId: customerId);
      final stats = await _repo.getTodayStats();
      emit(SalesLoaded(sales, stats));
    } catch (e) {
      emit(SalesError('فشل تحميل المبيعات: $e'));
    }
  }

  Future<void> loadDetail(String id) async {
    emit(SalesLoading());
    try {
      final sale = await _repo.getById(id);
      if (sale == null) {
        emit(SalesError('الفاتورة غير موجودة'));
        return;
      }
      final items = await _repo.getItems(id);
      emit(SalesDetailLoaded(sale, items));
    } catch (e) {
      emit(SalesError('فشل تحميل تفاصيل الفاتورة: $e'));
    }
  }

  Future<void> create(SaleModel sale, List<SaleItemModel> items) async {
    emit(SalesLoading());
    try {
      await _repo.create(sale, items);
      emit(SalesSaved());
      await load();
    } catch (e) {
      emit(SalesError('فشل حفظ الفاتورة: $e'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      await load();
    } catch (e) {
      emit(SalesError('فشل حذف الفاتورة: $e'));
    }
  }

  Future<String> generateInvoiceNumber() => _repo.generateInvoiceNumber();
}
