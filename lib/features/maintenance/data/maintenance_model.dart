import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class MaintenanceModel {
  final String id;
  final String ticketNumber;
  final String customerId;
  final String? deviceId;
  final String brand;
  final String model;
  final String? imei;
  final String? color;
  final String faultDescription;
  final String? technicianId;
  final String status;
  final double laborCost;
  final double partsCost;
  final double totalCost;
  final double advancePaid;
  final String? warrantyType;
  final int? warrantyDays;
  final int? warrantyStart;
  final int? warrantyEnd;
  final int receivedAt;
  final int? estimatedDelivery;
  final int? deliveredAt;
  final String? notes;
  final String? internalNotes;
  final String createdBy;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  // Join fields (not stored in DB directly)
  final String? customerName;
  final String? customerPhone;
  final String? technicianName;
  final String? createdByName;

  const MaintenanceModel({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    this.deviceId,
    required this.brand,
    required this.model,
    this.imei,
    this.color,
    required this.faultDescription,
    this.technicianId,
    required this.status,
    required this.laborCost,
    required this.partsCost,
    required this.totalCost,
    required this.advancePaid,
    this.warrantyType,
    this.warrantyDays,
    this.warrantyStart,
    this.warrantyEnd,
    required this.receivedAt,
    this.estimatedDelivery,
    this.deliveredAt,
    this.notes,
    this.internalNotes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.customerName,
    this.customerPhone,
    this.technicianName,
    this.createdByName,
  });

  factory MaintenanceModel.create({
    required String ticketNumber,
    required String customerId,
    String? deviceId,
    required String brand,
    required String model,
    String? imei,
    String? color,
    required String faultDescription,
    String? technicianId,
    double laborCost = 0.0,
    double partsCost = 0.0,
    double totalCost = 0.0,
    double advancePaid = 0.0,
    String? warrantyType,
    int? warrantyDays,
    int? warrantyStart,
    int? warrantyEnd,
    int? estimatedDelivery,
    String? notes,
    String? internalNotes,
    required String createdBy,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MaintenanceModel(
      id: const Uuid().v4(),
      ticketNumber: ticketNumber,
      customerId: customerId,
      deviceId: deviceId,
      brand: brand,
      model: model,
      imei: imei,
      color: color,
      faultDescription: faultDescription,
      technicianId: technicianId,
      status: 'new',
      laborCost: laborCost,
      partsCost: partsCost,
      totalCost: totalCost,
      advancePaid: advancePaid,
      warrantyType: warrantyType,
      warrantyDays: warrantyDays,
      warrantyStart: warrantyStart,
      warrantyEnd: warrantyEnd,
      receivedAt: now,
      estimatedDelivery: estimatedDelivery,
      deliveredAt: null,
      notes: notes,
      internalNotes: internalNotes,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      customerName: null,
      customerPhone: null,
      technicianName: null,
      createdByName: null,
    );
  }

  factory MaintenanceModel.fromMap(Map<String, dynamic> map) {
    return MaintenanceModel(
      id: map['id'] as String,
      ticketNumber: map['ticket_number'] as String,
      customerId: map['customer_id'] as String,
      deviceId: map['device_id'] as String?,
      brand: map['brand'] as String,
      model: map['model'] as String,
      imei: map['imei'] as String?,
      color: map['color'] as String?,
      faultDescription: map['fault_description'] as String,
      technicianId: map['technician_id'] as String?,
      status: map['status'] as String,
      laborCost: (map['labor_cost'] as num).toDouble(),
      partsCost: (map['parts_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      advancePaid: (map['advance_paid'] as num).toDouble(),
      warrantyType: map['warranty_type'] as String?,
      warrantyDays: map['warranty_days'] as int?,
      warrantyStart: map['warranty_start'] as int?,
      warrantyEnd: map['warranty_end'] as int?,
      receivedAt: map['received_at'] as int,
      estimatedDelivery: map['estimated_delivery'] as int?,
      deliveredAt: map['delivered_at'] as int?,
      notes: map['notes'] as String?,
      internalNotes: map['internal_notes'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      technicianName: map['technician_name'] as String?,
      createdByName: map['created_by_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticket_number': ticketNumber,
      'customer_id': customerId,
      'device_id': deviceId,
      'brand': brand,
      'model': model,
      'imei': imei,
      'color': color,
      'fault_description': faultDescription,
      'technician_id': technicianId,
      'status': status,
      'labor_cost': laborCost,
      'parts_cost': partsCost,
      'total_cost': totalCost,
      'advance_paid': advancePaid,
      'warranty_type': warrantyType,
      'warranty_days': warrantyDays,
      'warranty_start': warrantyStart,
      'warranty_end': warrantyEnd,
      'received_at': receivedAt,
      'estimated_delivery': estimatedDelivery,
      'delivered_at': deliveredAt,
      'notes': notes,
      'internal_notes': internalNotes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  MaintenanceModel copyWith({
    String? id,
    String? ticketNumber,
    String? customerId,
    Object? deviceId = _sentinel,
    String? brand,
    String? model,
    Object? imei = _sentinel,
    Object? color = _sentinel,
    String? faultDescription,
    Object? technicianId = _sentinel,
    String? status,
    double? laborCost,
    double? partsCost,
    double? totalCost,
    double? advancePaid,
    Object? warrantyType = _sentinel,
    Object? warrantyDays = _sentinel,
    Object? warrantyStart = _sentinel,
    Object? warrantyEnd = _sentinel,
    int? receivedAt,
    Object? estimatedDelivery = _sentinel,
    Object? deliveredAt = _sentinel,
    Object? notes = _sentinel,
    Object? internalNotes = _sentinel,
    String? createdBy,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
    Object? customerName = _sentinel,
    Object? customerPhone = _sentinel,
    Object? technicianName = _sentinel,
    Object? createdByName = _sentinel,
  }) {
    return MaintenanceModel(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      customerId: customerId ?? this.customerId,
      deviceId: deviceId == _sentinel ? this.deviceId : deviceId as String?,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      imei: imei == _sentinel ? this.imei : imei as String?,
      color: color == _sentinel ? this.color : color as String?,
      faultDescription: faultDescription ?? this.faultDescription,
      technicianId: technicianId == _sentinel
          ? this.technicianId
          : technicianId as String?,
      status: status ?? this.status,
      laborCost: laborCost ?? this.laborCost,
      partsCost: partsCost ?? this.partsCost,
      totalCost: totalCost ?? this.totalCost,
      advancePaid: advancePaid ?? this.advancePaid,
      warrantyType: warrantyType == _sentinel
          ? this.warrantyType
          : warrantyType as String?,
      warrantyDays:
          warrantyDays == _sentinel ? this.warrantyDays : warrantyDays as int?,
      warrantyStart: warrantyStart == _sentinel
          ? this.warrantyStart
          : warrantyStart as int?,
      warrantyEnd:
          warrantyEnd == _sentinel ? this.warrantyEnd : warrantyEnd as int?,
      receivedAt: receivedAt ?? this.receivedAt,
      estimatedDelivery: estimatedDelivery == _sentinel
          ? this.estimatedDelivery
          : estimatedDelivery as int?,
      deliveredAt:
          deliveredAt == _sentinel ? this.deliveredAt : deliveredAt as int?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      internalNotes: internalNotes == _sentinel
          ? this.internalNotes
          : internalNotes as String?,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
      customerName: customerName == _sentinel
          ? this.customerName
          : customerName as String?,
      customerPhone: customerPhone == _sentinel
          ? this.customerPhone
          : customerPhone as String?,
      technicianName: technicianName == _sentinel
          ? this.technicianName
          : technicianName as String?,
      createdByName: createdByName == _sentinel
          ? this.createdByName
          : createdByName as String?,
    );
  }

  String get statusLabel {
    return AppConstants.maintenanceStatusLabel(status);
  }

  Color get statusColor {
    return AppColors.maintenanceStatus(status);
  }

  double get remainingAmount => totalCost - advancePaid;

  bool get isOverdue =>
      estimatedDelivery != null &&
      status != 'delivered' &&
      status != 'cancelled' &&
      DateTime.now().millisecondsSinceEpoch > estimatedDelivery!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MaintenanceModel(id: $id, ticketNumber: $ticketNumber, status: $status)';
}

/// Private sentinel used by [MaintenanceModel.copyWith] to distinguish
/// an explicit `null` from an omitted argument.
const Object _sentinel = Object();
