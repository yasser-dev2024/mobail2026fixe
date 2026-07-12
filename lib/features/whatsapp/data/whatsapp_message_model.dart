import '../../../core/constants/app_constants.dart';

class WhatsappMessageModel {
  final String id;
  final String maintenanceId;
  final String? customerId;
  final String? customerName;
  final String phone;
  final String? normalizedPhone;
  final String messageType;
  final String message;
  final String status;
  final String provider;
  final int preparedAt;
  final int? sentAt;
  final String? sentBy;
  final String? failureReason;
  final int retryCount;
  final int? editedAt;
  final int updatedAt;

  const WhatsappMessageModel({
    required this.id,
    required this.maintenanceId,
    this.customerId,
    this.customerName,
    required this.phone,
    this.normalizedPhone,
    required this.messageType,
    required this.message,
    required this.status,
    required this.provider,
    required this.preparedAt,
    this.sentAt,
    this.sentBy,
    this.failureReason,
    required this.retryCount,
    this.editedAt,
    required this.updatedAt,
  });

  factory WhatsappMessageModel.fromMap(Map<String, dynamic> map) {
    return WhatsappMessageModel(
      id: map['id'] as String,
      maintenanceId: map['maintenance_id'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      phone: map['phone'] as String? ?? '',
      normalizedPhone: map['normalized_phone'] as String?,
      messageType: map['message_type'] as String,
      message: map['message'] as String,
      status: map['status'] as String,
      provider: map['provider'] as String? ?? 'desktop',
      preparedAt: map['prepared_at'] as int,
      sentAt: map['sent_at'] as int?,
      sentBy: map['sent_by'] as String?,
      failureReason: map['failure_reason'] as String?,
      retryCount: map['retry_count'] as int? ?? 0,
      editedAt: map['edited_at'] as int?,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'maintenance_id': maintenanceId,
        'customer_id': customerId,
        'customer_name': customerName,
        'phone': phone,
        'normalized_phone': normalizedPhone,
        'message_type': messageType,
        'message': message,
        'status': status,
        'provider': provider,
        'prepared_at': preparedAt,
        'sent_at': sentAt,
        'sent_by': sentBy,
        'failure_reason': failureReason,
        'retry_count': retryCount,
        'edited_at': editedAt,
        'updated_at': updatedAt,
      };

  String get typeLabel => AppConstants.whatsappMessageTypeLabel(messageType);

  String get statusLabel {
    switch (status) {
      case 'prepared':
        return 'مجهزة';
      case 'sent':
        return 'تم الإرسال';
      case 'failed':
        return 'فشل الإرسال';
      default:
        return status;
    }
  }
}
