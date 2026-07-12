import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/devices_repository.dart';
import '../../data/device_model.dart';

part 'devices_state.dart';

class DevicesCubit extends Cubit<DevicesState> {
  final DevicesRepository _repo;

  DevicesCubit({DevicesRepository? repo})
      : _repo = repo ?? DevicesRepository(),
        super(DevicesInitial());

  Future<void> loadDevices(String customerId) async {
    emit(DevicesLoading());
    try {
      final devices = await _repo.getByCustomer(customerId);
      emit(DevicesLoaded(devices));
    } catch (e) {
      emit(DevicesError('فشل في تحميل الأجهزة: ${e.toString()}'));
    }
  }

  Future<void> loadAll({String? search}) async {
    emit(DevicesLoading());
    try {
      final devices = await _repo.getAll(search: search);
      emit(DevicesLoaded(devices));
    } catch (e) {
      emit(DevicesError('فشل في تحميل الأجهزة: ${e.toString()}'));
    }
  }

  Future<void> createDevice(DeviceModel device) async {
    try {
      await _repo.create(device);
      await loadDevices(device.customerId);
    } catch (e) {
      emit(DevicesError('فشل في إضافة الجهاز: ${e.toString()}'));
    }
  }

  Future<void> updateDevice(DeviceModel device) async {
    try {
      await _repo.update(device);
      await loadDevices(device.customerId);
    } catch (e) {
      emit(DevicesError('فشل في تحديث الجهاز: ${e.toString()}'));
    }
  }

  Future<void> deleteDevice(
    String id, {
    String? customerId,
    String? search,
  }) async {
    try {
      await _repo.delete(id);
      if (customerId != null) {
        await loadDevices(customerId);
      } else {
        await loadAll(search: search);
      }
    } catch (e) {
      emit(DevicesError('فشل في حذف الجهاز: ${e.toString()}'));
      rethrow;
    }
  }
}
