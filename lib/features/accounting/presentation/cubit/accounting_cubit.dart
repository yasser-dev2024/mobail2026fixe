import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/accounting_repository.dart';
import '../../data/transaction_model.dart';

part 'accounting_state.dart';

class AccountingCubit extends Cubit<AccountingState> {
  final AccountingRepository _repo = AccountingRepository();

  AccountingCubit() : super(AccountingInitial());

  Future<void> load({
    String? type,
    String? category,
    DateTime? from,
    DateTime? to,
  }) async {
    emit(AccountingLoading());
    try {
      final transactions = await _repo.getTransactions(
        type: type,
        category: category,
        from: from,
        to: to,
      );
      final summary = await _repo.getSummary(from: from, to: to);
      final chartData = await _repo.getLast6MonthsData();
      emit(AccountingLoaded(transactions, summary, chartData));
    } catch (e) {
      emit(AccountingError('فشل تحميل البيانات المحاسبية: $e'));
    }
  }

  Future<void> addTransaction(TransactionModel tx) async {
    try {
      await _repo.addTransaction(tx);
      emit(AccountingSaved());
      await load();
    } catch (e) {
      emit(AccountingError('فشل إضافة المعاملة: $e'));
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repo.deleteTransaction(id);
      await load();
    } catch (e) {
      emit(AccountingError('فشل حذف المعاملة: $e'));
    }
  }

  Future<Map<String, double>> getExpensesByCategory({
    DateTime? from,
    DateTime? to,
  }) =>
      _repo.getExpensesByCategory(from: from, to: to);
}
