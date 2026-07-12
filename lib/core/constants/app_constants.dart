class AppConstants {
  static const String appName = 'ProShop';
  static const String appVersion = '1.0.0';
  static const String dbName = 'mobile_shop_pro.db';
  static const int dbVersion = 9;

  // Maintenance Status
  static const String statusNew = 'new';
  static const String statusWaitingInspection = 'waiting_inspection';
  static const String statusInspecting = 'inspecting';
  static const String statusFaultIdentified = 'fault_identified';
  static const String statusWaitingCustomerApproval =
      'waiting_customer_approval';
  static const String statusCustomerApproved = 'customer_approved';
  static const String statusCustomerRejected = 'customer_rejected';
  static const String statusWaitingPart = 'waiting_part';
  static const String statusRepairing = 'repairing';
  static const String statusUnderTesting = 'under_testing';
  static const String statusRepaired = 'repaired';
  static const String statusReady = 'ready';
  static const String statusDelivered = 'delivered';
  static const String statusUnrepairable = 'unrepairable';
  static const String statusCancelled = 'cancelled';
  static const String statusWarrantyReturn = 'warranty_return';
  static const String statusAbandoned = 'abandoned';

  static const List<String> maintenanceStatuses = [
    statusNew,
    statusWaitingInspection,
    statusInspecting,
    statusFaultIdentified,
    statusWaitingCustomerApproval,
    statusCustomerApproved,
    statusCustomerRejected,
    statusWaitingPart,
    statusRepairing,
    statusUnderTesting,
    statusRepaired,
    statusReady,
    statusDelivered,
    statusUnrepairable,
    statusCancelled,
    statusWarrantyReturn,
    statusAbandoned,
  ];

  static const Map<String, String> maintenanceStatusLabels = {
    statusNew: 'دخل الصيانة',
    statusWaitingInspection: 'بانتظار الفحص',
    statusInspecting: 'جاري الفحص',
    statusFaultIdentified: 'تم تحديد العطل',
    statusWaitingCustomerApproval: 'بانتظار موافقة العميل',
    statusCustomerApproved: 'وافق العميل',
    statusCustomerRejected: 'رفض العميل',
    statusWaitingPart: 'يحتاج قطع غيار',
    statusRepairing: 'تحت الصيانة',
    statusUnderTesting: 'تحت الاختبار',
    statusRepaired: 'تم الإصلاح',
    statusReady: 'جاهز للاستلام',
    statusDelivered: 'تم التسليم',
    statusUnrepairable: 'تعذر الإصلاح — جاهز للإرجاع',
    statusCancelled: 'ألغى العميل الطلب',
    statusWarrantyReturn: 'دخل الصيانة تحت الضمان',
    statusAbandoned: 'جهاز متروك',
  };

  static const Map<String, List<String>> allowedMaintenanceTransitions = {
    statusNew: [
      statusWaitingInspection,
      statusInspecting,
      statusCancelled,
    ],
    statusWaitingInspection: [
      statusInspecting,
      statusCancelled,
    ],
    statusInspecting: [
      statusFaultIdentified,
      statusWaitingPart,
      statusUnrepairable,
      statusCancelled,
    ],
    statusFaultIdentified: [
      statusWaitingCustomerApproval,
      statusCustomerApproved,
      statusWaitingPart,
      statusRepairing,
      statusUnrepairable,
      statusCancelled,
    ],
    statusWaitingCustomerApproval: [
      statusCustomerApproved,
      statusCustomerRejected,
      statusCancelled,
    ],
    statusCustomerApproved: [
      statusWaitingPart,
      statusRepairing,
      statusCancelled,
    ],
    statusCustomerRejected: [
      statusDelivered,
      statusCancelled,
    ],
    statusWaitingPart: [
      statusRepairing,
      statusCancelled,
    ],
    statusRepairing: [
      statusUnderTesting,
      statusRepaired,
      statusWaitingPart,
      statusUnrepairable,
      statusCancelled,
    ],
    statusUnderTesting: [
      statusRepairing,
      statusRepaired,
    ],
    statusRepaired: [
      statusReady,
      statusUnderTesting,
    ],
    statusReady: [
      statusDelivered,
      statusAbandoned,
    ],
    statusDelivered: [
      statusWarrantyReturn,
    ],
    statusUnrepairable: [
      statusReady,
      statusDelivered,
      statusCancelled,
    ],
    statusCancelled: [],
    statusWarrantyReturn: [
      statusWaitingInspection,
      statusInspecting,
      statusRepairing,
      statusUnderTesting,
      statusReady,
      statusDelivered,
    ],
    statusAbandoned: [
      statusDelivered,
      statusCancelled,
    ],
  };

  static String maintenanceStatusLabel(String status) {
    return maintenanceStatusLabels[status] ?? status;
  }

  static const List<String> visibleMaintenanceStageLabels = [
    'تم الاستلام',
    'بانتظار الصيانة',
    'جاهز للتسليم',
    'تم التسليم',
    'الضمان',
  ];

  static const List<String> waitingMaintenanceStatuses = [
    statusNew,
    statusWaitingInspection,
    statusInspecting,
    statusFaultIdentified,
    statusWaitingCustomerApproval,
    statusCustomerApproved,
    statusCustomerRejected,
    statusWaitingPart,
    statusRepairing,
    statusUnderTesting,
    statusRepaired,
  ];

  static const List<String> readyForCustomerStatuses = [
    statusReady,
    statusUnrepairable,
  ];

  static const List<String> deliveredMaintenanceStatuses = [
    statusDelivered,
  ];

  static const List<String> warrantyReturnStatuses = [
    statusWarrantyReturn,
  ];

  static int maintenanceStageIndex(String status) {
    if (status == statusDelivered) return 3;
    if (status == statusWarrantyReturn) return 4;
    if (readyForCustomerStatuses.contains(status)) return 2;
    if (waitingMaintenanceStatuses.contains(status)) return 1;
    return 0;
  }

  static String maintenanceStageLabel(String status) {
    if (status == statusUnrepairable) return 'تعذر الإصلاح — جاهز للإرجاع';
    if (status == statusNew) return 'دخل الصيانة';
    if (status == statusRepairing) return 'تحت الصيانة';
    if (status == statusWaitingPart) return 'يحتاج قطع غيار';
    if (readyForCustomerStatuses.contains(status)) return 'جاهز للاستلام';
    if (status == statusDelivered) return 'تم التسليم';
    if (status == statusWarrantyReturn) return 'دخل الصيانة تحت الضمان';
    return 'دخل الصيانة';
  }

  static bool isMaintenanceTerminalStatus(String status) {
    return status == statusDelivered ||
        status == statusCancelled ||
        status == statusAbandoned;
  }

  // Warranty Periods
  static const String warrantyNone = 'none';
  static const String warranty7Days = '7_days';
  static const String warranty30Days = '30_days';
  static const String warranty90Days = '90_days';
  static const String warranty6Months = '6_months';
  static const String warranty1Year = '1_year';
  static const String warranty2Years = '2_years';
  static const String warrantyCustom = 'custom';
  static const int warrantyMinDays = 1;
  static const int warrantyMaxDays = 730;
  static const int longWarrantyThresholdDays = 90;

  static bool isValidWarrantyDays(int? days) {
    return days != null && days >= warrantyMinDays && days <= warrantyMaxDays;
  }

  static int clampWarrantyDays(int days) {
    if (days < warrantyMinDays) return warrantyMinDays;
    if (days > warrantyMaxDays) return warrantyMaxDays;
    return days;
  }

  // User Roles
  static const String roleOwner = 'owner';
  static const String roleManager = 'manager';
  static const String roleBranchManager = 'branch_manager';
  static const String roleCashier = 'cashier';
  static const String roleTechnician = 'technician';
  static const String roleReceptionist = 'receptionist';
  static const String roleAccountant = 'accountant';

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentTransfer = 'transfer';
  static const String paymentCredit = 'credit';

  // Notification Priority
  static const String priorityLow = 'low';
  static const String priorityMedium = 'medium';
  static const String priorityHigh = 'high';
  static const String priorityCritical = 'critical';

  // Inventory Categories
  static const List<String> inventoryCategories = [
    'phones',
    'screens',
    'batteries',
    'chargers',
    'earphones',
    'cases',
    'spare_parts',
    'services',
    'other',
  ];

  // Transaction Types
  static const String txIncome = 'income';
  static const String txExpense = 'expense';

  // Expense Categories
  static const List<String> expenseCategories = [
    'salary',
    'rent',
    'utilities',
    'purchase',
    'maintenance',
    'other',
  ];

  // Abandoned device thresholds (days)
  static const List<int> abandonedThresholds = [3, 7, 15];

  // Low stock default threshold
  static const int defaultLowStockThreshold = 5;

  // Max login attempts before lock
  static const int maxLoginAttempts = 5;
  static const int lockDurationMinutes = 15;

  // Backup
  static const String backupExtension = '.shopbak';
  static const int automaticBackupIntervalDays = 3;
  static const int autoBackupIntervalDays = 1;

  // Whatsapp templates keys
  static const String waTplReceived = 'received';
  static const String waTplInspecting = 'inspecting';
  static const String waTplWaiting = 'waiting_part';
  static const String waTplRepaired = 'repaired';
  static const String waTplReady = 'ready';
  static const String waTplWarrantyExpiring = 'warranty_expiring';

  // Whatsapp workflow message types
  static const String waMsgReceived = 'received';
  static const String waMsgNeedsPart = 'needs_part';
  static const String waMsgReady = 'ready';
  static const String waMsgUnrepairable = 'unrepairable';
  static const String waMsgDelivered = 'delivered';
  static const String waMsgReadyReminder1 = 'ready_reminder_1';
  static const String waMsgReadyReminder3 = 'ready_reminder_3';
  static const String waMsgReadyReminder7 = 'ready_reminder_7';
  static const String waMsgWarrantyExpiring = 'warranty_expiring';
  static const String waMsgWarrantyClaim = 'warranty_claim';

  static const Map<String, String> whatsappMessageTypeLabels = {
    waMsgReceived: 'رسالة الاستلام',
    waMsgNeedsPart: 'رسالة الحاجة إلى قطعة غيار',
    waMsgReady: 'رسالة الجاهزية',
    waMsgUnrepairable: 'رسالة تعذر الإصلاح',
    waMsgDelivered: 'رسالة التسليم',
    waMsgReadyReminder1: 'تذكير أول للاستلام',
    waMsgReadyReminder3: 'تذكير ثان للاستلام',
    waMsgReadyReminder7: 'تذكير أخير للاستلام',
    waMsgWarrantyExpiring: 'تذكير قرب انتهاء الضمان',
    waMsgWarrantyClaim: 'رسالة طلب الضمان',
  };

  static String whatsappMessageTypeLabel(String type) {
    return whatsappMessageTypeLabels[type] ?? type;
  }

  // Invoice statuses
  static const String invoiceDraft = 'draft';
  static const String invoiceApproved = 'approved';
  static const String invoiceSent = 'sent';
  static const String invoicePaid = 'paid';
  static const String invoiceCancelled = 'cancelled';

  static const Map<String, String> invoiceStatusLabels = {
    invoiceDraft: 'مسودة',
    invoiceApproved: 'معتمدة',
    invoiceSent: 'مرسلة',
    invoicePaid: 'مدفوعة',
    invoiceCancelled: 'ملغاة',
  };

  static String invoiceStatusLabel(String status) {
    return invoiceStatusLabels[status] ?? status;
  }

  // Device photo stages
  static const String photoStageIntake = 'intake';
  static const String photoStageBeforeRepair = 'before_repair';
  static const String photoStageDuringRepair = 'during_repair';
  static const String photoStageOldParts = 'old_parts';
  static const String photoStageNewParts = 'new_parts';
  static const String photoStageAfterRepair = 'after_repair';
  static const String photoStageDelivery = 'delivery';
  static const String photoStageEvidence = 'evidence';

  static const Map<String, String> devicePhotoStageLabels = {
    photoStageIntake: 'عند الاستلام',
    photoStageBeforeRepair: 'قبل الصيانة',
    photoStageDuringRepair: 'أثناء الصيانة',
    photoStageOldParts: 'القطع التالفة',
    photoStageNewParts: 'القطع الجديدة',
    photoStageAfterRepair: 'بعد الصيانة',
    photoStageDelivery: 'عند التسليم',
    photoStageEvidence: 'إثبات إضافي',
  };

  static String devicePhotoStageLabel(String stage) {
    return devicePhotoStageLabels[stage] ?? stage;
  }

  static const List<String> defaultDevicePhotoTypes = [
    'الواجهة الأمامية',
    'الشاشة وهي مطفأة',
    'الشاشة وهي تعمل',
    'الجهة الخلفية',
    'الجانب الأيمن',
    'الجانب الأيسر',
    'منفذ الشحن',
    'الكاميرات',
    'IMEI أو الرقم التسلسلي',
    'الملحقات المستلمة',
    'الخدوش',
    'الكسور',
    'آثار السوائل أو الرطوبة',
    'ملاحظة إضافية',
  ];
}
