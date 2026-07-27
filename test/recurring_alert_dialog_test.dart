import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/features/notifications/data/notification_model.dart';
import 'package:mobile_shop_pro/features/notifications/presentation/widgets/recurring_alert_dialog.dart';

NotificationModel _alert(String id, String title) {
  return NotificationModel(
    id: id,
    title: title,
    message: 'تفاصيل $title',
    type: 'maintenance_overdue',
    priority: 'high',
    createdAt: 1000,
  );
}

void main() {
  testWidgets('multiple due alerts use one combined management dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringAlertsDialog(
            notifications: [
              _alert('one', 'التنبيه الأول'),
              _alert('two', 'التنبيه الثاني'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 تنبيهات تحتاج مراجعة'), findsOneWidget);
    expect(find.text('التنبيه الأول'), findsOneWidget);
    expect(find.text('التنبيه الثاني'), findsOneWidget);
    expect(find.text('تأجيل الكل (2)'), findsOneWidget);
    expect(find.text('إدارة التنبيهات'), findsOneWidget);
  });
}
