part of 'accounting_cubit.dart';

abstract class AccountingState {}

class AccountingInitial extends AccountingState {}

class AccountingLoading extends AccountingState {}

class AccountingLoaded extends AccountingState {
  final List<TransactionModel> transactions;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> chartData;
  AccountingLoaded(this.transactions, this.summary, this.chartData);
}

class AccountingError extends AccountingState {
  final String message;
  AccountingError(this.message);
}

class AccountingSaved extends AccountingState {}
