part of 'customers_cubit.dart';

abstract class CustomersState {}

class CustomersInitial extends CustomersState {}

class CustomersLoading extends CustomersState {}

class CustomersLoaded extends CustomersState {
  final List<CustomerModel> customers;
  final int total;
  CustomersLoaded(this.customers, this.total);
}

class CustomersError extends CustomersState {
  final String message;
  CustomersError(this.message);
}
