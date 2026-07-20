import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';

class WarrantyModel {
  final String id;
  final String maintenanceId;
  final String customerId;
  final String deviceInfo;
  final String warrantyType;
  final int warrantyDays;
  final int startDate;
  final int endDate;
  final String? notes;
  final bool isVoid;
  final bool alertDisabled;
  final String? alertDisabledReason;
  final int? alertDisabledAt;
  final String? alertDisabledBy;
  final bool expiryApproved;
  final int? expiryApprovedAt;
  final String? expiryApprovedBy;
  final int createdAt;
  final int updatedAt;

  // Join fields (not stored in DB directly)
  final String? customerName;
  final String? ticketNumber;

  const WarrantyModel({
    required this.id,
    required this.maintenanceId,
    required this.customerId,
    required this.deviceInfo,
    required this.warrantyType,
    required this.warrantyDays,
    required this.startDate,
    required this.endDate,
    this.notes,
    required this.isVoid,
    this.alertDisabled = false,
    this.alertDisabledReason,
    this.alertDisabledAt,
    this.alertDisabledBy,
    this.expiryApproved = false,
    this.expiryApprovedAt,
    this.expiryApprovedBy,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.ticketNumber,
  });

  factory WarrantyModel.create({
    required String maintenanceId,
    required String customerId,
    required String deviceInfo,
    required String warrantyType,
    required int warrantyDays,
    required int startDate,
    required int endDate,
    String? notes,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WarrantyModel(
      id: const Uuid().v4(),
      maintenanceId: maintenanceId,
      customerId: customerId,
      deviceInfo: deviceInfo,
      warrantyType: warrantyType,
      warrantyDays: warrantyDays,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      isVoid: false,
      alertDisabled: false,
      expiryApproved: false,
      createdAt: now,
      updatedAt: now,
      customerName: null,
      ticketNumber: null,
    );
  }

  factory WarrantyModel.fromMap(Map<String, dynamic> map) {
    return WarrantyModel(
      id: map['id'] as String,
      maintenanceId: map['maintenance_id'] as String,
      customerId: map['customer_id'] as String,
      deviceInfo: map['device_info'] as String,
      warrantyType: map['warranty_type'] as String,
      warrantyDays: map['warranty_days'] as int,
      startDate: map['start_date'] as int,
      endDate: map['end_date'] as int,
      notes: map['notes'] as String?,
      isVoid: (map['is_void'] as int) == 1,
      alertDisabled: (map['alert_disabled'] as int? ?? 0) == 1,
      alertDisabledReason: map['alert_disabled_reason'] as String?,
      alertDisabledAt: map['alert_disabled_at'] as int?,
      alertDisabledBy: map['alert_disabled_by'] as String?,
      expiryApproved: (map['expiry_approved'] as int? ?? 0) == 1,
      expiryApprovedAt: map['expiry_approved_at'] as int?,
      expiryApprovedBy: map['expiry_approved_by'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      customerName: map['customer_name'] as String?,
      ticketNumber: map['ticket_number'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'maintenance_id': maintenanceId,
      'customer_id': customerId,
      'device_info': deviceInfo,
      'warranty_type': warrantyType,
      'warranty_days': warrantyDays,
      'start_date': startDate,
      'end_date': endDate,
      'notes': notes,
      'is_void': isVoid ? 1 : 0,
      'alert_disabled': alertDisabled ? 1 : 0,
      'alert_disabled_reason': alertDisabledReason,
      'alert_disabled_at': alertDisabledAt,
      'alert_disabled_by': alertDisabledBy,
      'expiry_approved': expiryApproved ? 1 : 0,
      'expiry_approved_at': expiryApprovedAt,
      'expiry_approved_by': expiryApprovedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  WarrantyModel copyWith({
    String? id,
    String? maintenanceId,
    String? customerId,
    String? deviceInfo,
    String? warrantyType,
    int? warrantyDays,
    int? startDate,
    int? endDate,
    Object? notes = _sentinel,
    bool? isVoid,
    bool? alertDisabled,
    Object? alertDisabledReason = _sentinel,
    Object? alertDisabledAt = _sentinel,
    Object? alertDisabledBy = _sentinel,
    bool? expiryApproved,
    Object? expiryApprovedAt = _sentinel,
    Object? expiryApprovedBy = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? customerName = _sentinel,
    Object? ticketNumber = _sentinel,
  }) {
    return WarrantyModel(
      id: id ?? this.id,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      customerId: customerId ?? this.customerId,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      warrantyType: warrantyType ?? this.warrantyType,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes == _sentinel ? this.notes : notes as String?,
      isVoid: isVoid ?? this.isVoid,
      alertDisabled: alertDisabled ?? this.alertDisabled,
      alertDisabledReason: alertDisabledReason == _sentinel
          ? this.alertDisabledReason
          : alertDisabledReason as String?,
      alertDisabledAt: alertDisabledAt == _sentinel
          ? this.alertDisabledAt
          : alertDisabledAt as int?,
      alertDisabledBy: alertDisabledBy == _sentinel
          ? this.alertDisabledBy
          : alertDisabledBy as String?,
      expiryApproved: expiryApproved ?? this.expiryApproved,
      expiryApprovedAt: expiryApprovedAt == _sentinel
          ? this.expiryApprovedAt
          : expiryApprovedAt as int?,
      expiryApprovedBy: expiryApprovedBy == _sentinel
          ? this.expiryApprovedBy
          : expiryApprovedBy as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName == _sentinel
          ? this.customerName
          : customerName as String?,
      ticketNumber: ticketNumber == _sentinel
          ? this.ticketNumber
          : ticketNumber as String?,
    );
  }

  String get status {
    if (expiryApproved) return 'expired_approved';
    if (isVoid) return 'expired';
    final days = calendarDaysRemaining;
    if (days < 0) return 'expired';
    if (days <= 7) return 'expiring';
    return 'active';
  }

  int get calendarDaysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime.fromMillisecondsSinceEpoch(endDate);
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.difference(today).inDays;
  }

  int get daysRemaining {
    final days = calendarDaysRemaining;
    return days < 0 ? 0 : days;
  }

  bool get isLongWarranty =>
      warrantyDays > AppConstants.longWarrantyThresholdDays;

  bool get hasExpiredStamp => expiryApproved;

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'ساري';
      case 'expiring':
        return 'ينتهي قريباً';
      case 'expired':
        return 'منتهي';
      case 'expired_approved':
        return 'منتهي ومعتمد';
      default:
        return 'غير محدد';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expiring':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'expired_approved':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarrantyModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WarrantyModel(id: $id, maintenanceId: $maintenanceId, status: $status)';
}

/// Private sentinel used by [WarrantyModel.copyWith] to distinguish
/// an explicit `null` from an omitted argument.
const Object _sentinel = Object();
