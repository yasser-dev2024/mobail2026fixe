import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/services/alert_sound_service.dart';

void main() {
  test('delayed maintenance uses the fixed sound 1', () {
    expect(
      AlertSoundService.assetForType('maintenance_overdue_20260728'),
      'sounds/1.mp3',
    );
    expect(
      AlertSoundService.assetForType('device_stay_two_days'),
      'sounds/1.mp3',
    );
  });

  test('expired and expiring warranty alerts use the fixed sound 2', () {
    expect(
      AlertSoundService.assetForType('warranty_expired'),
      'sounds/2.mp3',
    );
    expect(
      AlertSoundService.assetForType('warranty_expiring_tomorrow'),
      'sounds/2.mp3',
    );
  });

  test('unrelated notifications do not reuse either approved sound', () {
    expect(AlertSoundService.assetForType('low_stock'), isNull);
    expect(AlertSoundService.assetForType('maintenance_ready'), isNull);
  });
}
