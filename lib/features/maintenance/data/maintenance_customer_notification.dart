import '../../../core/constants/app_constants.dart';

enum MaintenanceCustomerNotificationKind {
  none,
  whatsappText,
  invoicePdf,
}

class MaintenanceCustomerNotificationPlan {
  const MaintenanceCustomerNotificationPlan._(
    this.kind, {
    this.whatsappMessageType,
  });

  const MaintenanceCustomerNotificationPlan.none()
      : this._(MaintenanceCustomerNotificationKind.none);

  const MaintenanceCustomerNotificationPlan.whatsappText(
    String whatsappMessageType,
  ) : this._(
          MaintenanceCustomerNotificationKind.whatsappText,
          whatsappMessageType: whatsappMessageType,
        );

  const MaintenanceCustomerNotificationPlan.invoicePdf()
      : this._(MaintenanceCustomerNotificationKind.invoicePdf);

  final MaintenanceCustomerNotificationKind kind;
  final String? whatsappMessageType;
}

MaintenanceCustomerNotificationPlan maintenanceCustomerNotificationForStatus(
  String status,
) {
  switch (status) {
    case AppConstants.statusNew:
    case AppConstants.statusWaitingInspection:
      return const MaintenanceCustomerNotificationPlan.whatsappText(
        AppConstants.waMsgReceived,
      );
    case AppConstants.statusRepaired:
    case AppConstants.statusReady:
      return const MaintenanceCustomerNotificationPlan.whatsappText(
        AppConstants.waMsgReady,
      );
    case AppConstants.statusWaitingPart:
      return const MaintenanceCustomerNotificationPlan.whatsappText(
        AppConstants.waMsgNeedsPart,
      );
    case AppConstants.statusUnrepairable:
      return const MaintenanceCustomerNotificationPlan.whatsappText(
        AppConstants.waMsgUnrepairable,
      );
    case AppConstants.statusDelivered:
      return const MaintenanceCustomerNotificationPlan.invoicePdf();
    case AppConstants.statusWarrantyReturn:
      return const MaintenanceCustomerNotificationPlan.whatsappText(
        AppConstants.waMsgWarrantyClaim,
      );
    default:
      return const MaintenanceCustomerNotificationPlan.none();
  }
}
