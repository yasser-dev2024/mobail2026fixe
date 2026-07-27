import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/notifications/data/notification_model.dart';

NotificationModel _notification({
  bool isRead = false,
  bool alertStopped = false,
  int? snoozedUntil,
}) {
  return NotificationModel(
    id: 'notification-1',
    title: 'تنبيه',
    message: 'رسالة التنبيه',
    type: 'maintenance_overdue',
    priority: 'high',
    isRead: isRead,
    alertStopped: alertStopped,
    snoozedUntil: snoozedUntil,
    createdAt: 1000,
  );
}

void main() {
  const now = 100000;

  test('unread alert without snooze or stop is active', () {
    expect(_notification().isAlertActiveAt(now), isTrue);
  });

  test('future snooze removes alert from active group', () {
    final notification = _notification(snoozedUntil: now + 60000);

    expect(notification.isSnoozedAt(now), isTrue);
    expect(notification.isAlertActiveAt(now), isFalse);
  });

  test('expired snooze makes alert active again', () {
    final notification = _notification(snoozedUntil: now - 1);

    expect(notification.isSnoozedAt(now), isFalse);
    expect(notification.isAlertActiveAt(now), isTrue);
  });

  test('read or stopped alerts are not active', () {
    expect(_notification(isRead: true).isAlertActiveAt(now), isFalse);
    expect(_notification(alertStopped: true).isAlertActiveAt(now), isFalse);
  });
}
