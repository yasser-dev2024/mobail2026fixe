import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import 'warranty_model.dart';

class WarrantyActionModel {
  final String id;
  final String shopId;
  final String warrantyId;
  final String? maintenanceId;
  final String action;
  final String? oldValue;
  final String? newValue;
  final String? userId;
  final String? username;
  final String? notes;
  final int createdAt;

  const WarrantyActionModel({
    required this.id,
    this.shopId = 'default_shop',
    required this.warrantyId,
    this.maintenanceId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.userId,
    this.username,
    this.notes,
    required this.createdAt,
  });

  factory WarrantyActionModel.create({
    required String warrantyId,
    String? maintenanceId,
    required String action,
    String? oldValue,
    String? newValue,
    String? userId,
    String? username,
    String? notes,
  }) {
    return WarrantyActionModel(
      id: const Uuid().v4(),
      warrantyId: warrantyId,
      maintenanceId: maintenanceId,
      action: action,
      oldValue: oldValue,
      newValue: newValue,
      userId: userId,
      username: username,
      notes: notes,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory WarrantyActionModel.fromMap(Map<String, dynamic> map) {
    return WarrantyActionModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String? ?? 'default_shop',
      warrantyId: map['warranty_id'] as String,
      maintenanceId: map['maintenance_id'] as String?,
      action: map['action'] as String,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      userId: map['user_id'] as String?,
      username: map['username'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'warranty_id': warrantyId,
      'maintenance_id': maintenanceId,
      'action': action,
      'old_value': oldValue,
      'new_value': newValue,
      'user_id': userId,
      'username': username,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  String get actionLabel {
    switch (action) {
      case 'created':
        return 'إنشاء الضمان';
      case 'alert_shown':
        return 'ظهور التنبيه';
      case 'alert_opened':
        return 'فتح التنبيه';
      case 'alert_disabled':
        return 'إيقاف التنبيه';
      case 'renewed':
        return 'تجديد الضمان';
      case 'expiry_approved':
        return 'اعتماد انتهاء الضمان';
      case 'correction_note':
        return 'ملاحظة تصحيحية';
      default:
        return action;
    }
  }
}

class WarrantyAlertDetails {
  final WarrantyModel warranty;
  final String customerName;
  final String customerPhone;
  final String deviceName;
  final String? invoiceNumber;
  final String maintenanceStatus;
  final List<WarrantyActionModel> actions;

  const WarrantyAlertDetails({
    required this.warranty,
    required this.customerName,
    required this.customerPhone,
    required this.deviceName,
    this.invoiceNumber,
    required this.maintenanceStatus,
    required this.actions,
  });

  String get ticketOrInvoice {
    final ticket = warranty.ticketNumber?.trim() ?? '';
    final invoice = invoiceNumber?.trim() ?? '';
    if (ticket.isNotEmpty && invoice.isNotEmpty) return '$ticket / $invoice';
    if (invoice.isNotEmpty) return invoice;
    return ticket.isEmpty ? warranty.maintenanceId : ticket;
  }

  String get maintenanceStatusLabel =>
      AppConstants.maintenanceStatusLabel(maintenanceStatus);
}
