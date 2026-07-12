part of 'devices_cubit.dart';

abstract class DevicesState {}

class DevicesInitial extends DevicesState {}

class DevicesLoading extends DevicesState {}

class DevicesLoaded extends DevicesState {
  final List<DeviceModel> devices;
  DevicesLoaded(this.devices);
}

class DevicesError extends DevicesState {
  final String message;
  DevicesError(this.message);
}
