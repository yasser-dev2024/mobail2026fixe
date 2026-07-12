import 'package:uuid/uuid.dart';

class WarrantyClaimModel {
  final String id;
  final String warrantyId;
  final String? maintenanceId;
  final String description;
  final String? resolution;
  final String status; // open, resolved, rejected
  final int createdAt;
  final int? resolvedAt;

  const WarrantyClaimModel({
    required this.id,
    required this.warrantyId,
    this.maintenanceId,
    required this.description,
    this.resolution,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  factory WarrantyClaimModel.create({
    required String warrantyId,
    String? maintenanceId,
    required String description,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WarrantyClaimModel(
      id: const Uuid().v4(),
      warrantyId: warrantyId,
      maintenanceId: maintenanceId,
      description: description,
      resolution: null,
      status: 'open',
      createdAt: now,
      resolvedAt: null,
    );
  }

  factory WarrantyClaimModel.fromMap(Map<String, dynamic> map) {
    return WarrantyClaimModel(
      id: map['id'] as String,
      warrantyId: map['warranty_id'] as String,
      maintenanceId: map['maintenance_id'] as String?,
      description: map['description'] as String,
      resolution: map['resolution'] as String?,
      status: map['status'] as String,
      createdAt: map['created_at'] as int,
      resolvedAt: map['resolved_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'warranty_id': warrantyId,
      'maintenance_id': maintenanceId,
      'description': description,
      'resolution': resolution,
      'status': status,
      'created_at': createdAt,
      'resolved_at': resolvedAt,
    };
  }

  WarrantyClaimModel copyWith({
    String? id,
    String? warrantyId,
    Object? maintenanceId = _sentinel,
    String? description,
    Object? resolution = _sentinel,
    String? status,
    int? createdAt,
    Object? resolvedAt = _sentinel,
  }) {
    return WarrantyClaimModel(
      id: id ?? this.id,
      warrantyId: warrantyId ?? this.warrantyId,
      maintenanceId: maintenanceId == _sentinel
          ? this.maintenanceId
          : maintenanceId as String?,
      description: description ?? this.description,
      resolution:
          resolution == _sentinel ? this.resolution : resolution as String?,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt:
          resolvedAt == _sentinel ? this.resolvedAt : resolvedAt as int?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'مفتوح';
      case 'resolved':
        return 'تم الحل';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير محدد';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarrantyClaimModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WarrantyClaimModel(id: $id, warrantyId: $warrantyId, status: $status)';
}

const Object _sentinel = Object();
