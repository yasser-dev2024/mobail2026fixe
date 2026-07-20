import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class NotificationModel {
  final String id;
  final String shopId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final int createdAt;
  final int? snoozedUntil;
  final bool alertStopped;
  final int? alertStoppedAt;
  final String? alertStoppedBy;
  final int? lastFiredAt;

  const NotificationModel({
    required this.id,
    this.shopId = 'default_shop',
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.referenceId,
    this.referenceType,
    this.isRead = false,
    required this.createdAt,
    this.snoozedUntil,
    this.alertStopped = false,
    this.alertStoppedAt,
    this.alertStoppedBy,
    this.lastFiredAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String? ?? 'default_shop',
      title: map['title'] as String,
      message: map['message'] as String,
      type: map['type'] as String,
      priority: map['priority'] as String? ?? 'medium',
      referenceId: map['reference_id'] as String?,
      referenceType: map['reference_type'] as String?,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as int,
      snoozedUntil: map['snoozed_until'] as int?,
      alertStopped: (map['alert_stopped'] as int? ?? 0) == 1,
      alertStoppedAt: map['alert_stopped_at'] as int?,
      alertStoppedBy: map['alert_stopped_by'] as String?,
      lastFiredAt: map['last_fired_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
      'snoozed_until': snoozedUntil,
      'alert_stopped': alertStopped ? 1 : 0,
      'alert_stopped_at': alertStoppedAt,
      'alert_stopped_by': alertStoppedBy,
      'last_fired_at': lastFiredAt,
    };
  }

  Color get priorityColor {
    switch (priority) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.primary;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  IconData get priorityIcon {
    if (type.startsWith('maintenance_status_')) {
      return Icons.campaign_rounded;
    }
    if (type.startsWith('warranty_')) {
      return Icons.verified_user_rounded;
    }
    if (type == 'device_manual') {
      return Icons.phone_in_talk_rounded;
    }
    switch (type) {
      case 'maintenance_ready':
        return Icons.check_circle_rounded;
      case 'device_stay_two_days':
        return Icons.timer_rounded;
      case 'warranty_expiring':
        return Icons.verified_user_rounded;
      case 'low_stock':
        return Icons.inventory_2_rounded;
      case 'out_of_stock':
        return Icons.warning_rounded;
      case 'abandoned_device':
        return Icons.access_time_rounded;
      case 'credit_due':
        return Icons.receipt_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String get timeAgo {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - createdAt;
    if (diff < 60000) return 'الآن';
    if (diff < 3600000) return 'منذ ${(diff / 60000).floor()} دقيقة';
    if (diff < 86400000) return 'منذ ${(diff / 3600000).floor()} ساعة';
    return 'منذ ${(diff / 86400000).floor()} يوم';
  }

  NotificationModel copyWith({
    String? id,
    String? shopId,
    String? title,
    String? message,
    String? type,
    String? priority,
    String? referenceId,
    String? referenceType,
    bool? isRead,
    int? createdAt,
    int? snoozedUntil,
    bool? alertStopped,
    int? alertStoppedAt,
    String? alertStoppedBy,
    int? lastFiredAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      alertStopped: alertStopped ?? this.alertStopped,
      alertStoppedAt: alertStoppedAt ?? this.alertStoppedAt,
      alertStoppedBy: alertStoppedBy ?? this.alertStoppedBy,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
    );
  }
}

/// Extra customer/device/ticket context for the recurring alert popup,
/// looked up alongside a [NotificationModel] so the dialog can show a
/// contact number and an "open ticket" action regardless of which check
/// (device-stay, warranty, or a future type) produced the notification.
class AlertPopupDetails {
  final NotificationModel notification;
  final String? customerName;
  final String? customerPhone;
  final String? deviceName;
  final String? ticketNumber;
  final String? maintenanceId;

  const AlertPopupDetails({
    required this.notification,
    this.customerName,
    this.customerPhone,
    this.deviceName,
    this.ticketNumber,
    this.maintenanceId,
  });
}
