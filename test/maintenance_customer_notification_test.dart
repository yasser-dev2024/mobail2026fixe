import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_pro/core/constants/app_constants.dart';
import 'package:mobile_shop_pro/features/maintenance/data/maintenance_customer_notification.dart';

void main() {
  test('delivery uses the PDF invoice and never a plain WhatsApp message', () {
    final plan = maintenanceCustomerNotificationForStatus(
      AppConstants.statusDelivered,
    );

    expect(plan.kind, MaintenanceCustomerNotificationKind.invoicePdf);
    expect(plan.whatsappMessageType, isNull);
  });

  test('ready status keeps its existing WhatsApp text message', () {
    final plan = maintenanceCustomerNotificationForStatus(
      AppConstants.statusReady,
    );

    expect(plan.kind, MaintenanceCustomerNotificationKind.whatsappText);
    expect(plan.whatsappMessageType, AppConstants.waMsgReady);
  });
}
