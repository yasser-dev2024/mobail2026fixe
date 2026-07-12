import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/constants/app_constants.dart';
import 'package:mobile_shop_pro/features/device_photos/data/device_photo_model.dart';

void main() {
  test('device photo keeps stage metadata', () {
    final photo = DevicePhotoModel.create(
      shopId: 'default_shop',
      customerId: 'customer',
      deviceId: 'device',
      maintenanceId: 'maintenance',
      originalPath: r'C:\photos\front.jpg',
      fileName: 'front.jpg',
      fileSize: 120,
      stage: AppConstants.photoStageIntake,
      photoType: 'الواجهة الأمامية',
    );

    expect(photo.stageLabel, 'عند الاستلام');
    expect(photo.toMap()['photo_type'], 'الواجهة الأمامية');
  });
}
