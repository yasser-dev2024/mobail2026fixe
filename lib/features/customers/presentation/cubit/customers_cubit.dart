import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/customers_repository.dart';
import '../../data/customer_model.dart';

part 'customers_state.dart';

class CustomersCubit extends Cubit<CustomersState> {
  final CustomersRepository _repo;

  CustomersCubit({CustomersRepository? repo})
      : _repo = repo ?? CustomersRepository(),
        super(CustomersInitial());

  Future<void> loadCustomers({String? search, String? customerType}) async {
    emit(CustomersLoading());
    try {
      final customers = await _repo.getAll(
        search: search,
        customerType: customerType,
      );
      emit(CustomersLoaded(customers, customers.length));
    } catch (e) {
      emit(CustomersError('فشل في تحميل العملاء: ${e.toString()}'));
    }
  }

  Future<void> createCustomer(CustomerModel customer) async {
    try {
      await _repo.create(customer);
      await loadCustomers();
    } catch (e) {
      emit(CustomersError('فشل في إضافة العميل: ${e.toString()}'));
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      await _repo.update(customer);
      await loadCustomers();
    } catch (e) {
      emit(CustomersError('فشل في تحديث العميل: ${e.toString()}'));
    }
  }

  Future<void> deleteCustomer(
    String id, {
    String? search,
    String? customerType,
  }) async {
    try {
      await _repo.delete(id);
      await loadCustomers(search: search, customerType: customerType);
    } catch (e) {
      emit(CustomersError('فشل في حذف العميل: ${e.toString()}'));
      rethrow;
    }
  }
}
