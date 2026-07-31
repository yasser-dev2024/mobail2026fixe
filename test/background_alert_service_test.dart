import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/services/background_alert_service.dart';

void main() {
  group('normalizeBackgroundAlertRoute', () {
    test('accepts supported alert destinations', () {
      expect(normalizeBackgroundAlertRoute('/devices/device-1'),
          '/devices/device-1');
      expect(
        normalizeBackgroundAlertRoute('/maintenance/ticket_2'),
        '/maintenance/ticket_2',
      );
      expect(normalizeBackgroundAlertRoute('/warranty'), '/warranty');
    });

    test('rejects routes outside alert-owned destinations', () {
      expect(normalizeBackgroundAlertRoute('/settings'), isNull);
      expect(normalizeBackgroundAlertRoute('/devices/../../settings'), isNull);
      expect(normalizeBackgroundAlertRoute('/devices/device-1?edit=1'), isNull);
      expect(normalizeBackgroundAlertRoute(null), isNull);
    });
  });

  group('BackgroundAlertPermissionStatus', () {
    test('keeps full-screen alerts enabled for older native bridges', () {
      final status = BackgroundAlertPermissionStatus.fromMap(const {
        'notificationsGranted': true,
        'exactAlarmsGranted': true,
      });

      expect(status.fullScreenAlertsGranted, isTrue);
    });

    test('reports when Android has disabled full-screen alerts', () {
      final status = BackgroundAlertPermissionStatus.fromMap(const {
        'fullScreenAlertsGranted': false,
      });

      expect(status.fullScreenAlertsGranted, isFalse);
    });
  });
}
