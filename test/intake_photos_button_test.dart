import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/constants/app_constants.dart';
import 'package:mobile_shop_pro/features/device_photos/data/device_photo_model.dart';
import 'package:mobile_shop_pro/features/repair_board/presentation/screens/repair_board_screen.dart';

void main() {
  testWidgets('intake photos button remains visible with a fixed height',
      (tester) async {
    final photo = DevicePhotoModel.create(
      shopId: 'default_shop',
      customerId: 'customer',
      deviceId: 'device',
      maintenanceId: 'maintenance',
      originalPath: r'C:\photos\intake.jpg',
      fileName: 'intake.jpg',
      fileSize: 120,
      stage: AppConstants.photoStageIntake,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: IntakePhotosButton(
                maintenanceId: 'maintenance',
                photosFuture: Future.value([photo]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('عرض صور الجهاز (1)'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('intake_photos_button'))).height,
      54,
    );
  });
}
