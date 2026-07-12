import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';

class DevicePhotoModel {
  final String id;
  final String shopId;
  final String customerId;
  final String? deviceId;
  final String? maintenanceId;
  final String? invoiceId;
  final String? reportId;
  final String originalPath;
  final String? thumbnailPath;
  final String fileName;
  final int fileSize;
  final String? mimeType;
  final String stage;
  final String photoType;
  final String? caption;
  final String? capturedBy;
  final int capturedAt;
  final bool isOriginalRetained;
  final bool isRequired;
  final bool isApproved;
  final int? deletedAt;
  final String? deleteReason;
  final int createdAt;
  final int updatedAt;

  const DevicePhotoModel({
    required this.id,
    required this.shopId,
    required this.customerId,
    this.deviceId,
    this.maintenanceId,
    this.invoiceId,
    this.reportId,
    required this.originalPath,
    this.thumbnailPath,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
    required this.stage,
    required this.photoType,
    this.caption,
    this.capturedBy,
    required this.capturedAt,
    required this.isOriginalRetained,
    required this.isRequired,
    required this.isApproved,
    this.deletedAt,
    this.deleteReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DevicePhotoModel.create({
    required String shopId,
    required String customerId,
    String? deviceId,
    String? maintenanceId,
    String? invoiceId,
    String? reportId,
    required String originalPath,
    String? thumbnailPath,
    required String fileName,
    required int fileSize,
    String? mimeType,
    String stage = AppConstants.photoStageIntake,
    String photoType = 'ملاحظة إضافية',
    String? caption,
    String? capturedBy,
    bool isOriginalRetained = true,
    bool isRequired = false,
    bool isApproved = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DevicePhotoModel(
      id: const Uuid().v4(),
      shopId: shopId,
      customerId: customerId,
      deviceId: deviceId,
      maintenanceId: maintenanceId,
      invoiceId: invoiceId,
      reportId: reportId,
      originalPath: originalPath,
      thumbnailPath: thumbnailPath,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      stage: stage,
      photoType: photoType,
      caption: caption,
      capturedBy: capturedBy,
      capturedAt: now,
      isOriginalRetained: isOriginalRetained,
      isRequired: isRequired,
      isApproved: isApproved,
      deletedAt: null,
      deleteReason: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory DevicePhotoModel.fromMap(Map<String, dynamic> map) {
    return DevicePhotoModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String? ?? 'default_shop',
      customerId: map['customer_id'] as String,
      deviceId: map['device_id'] as String?,
      maintenanceId: map['maintenance_id'] as String?,
      invoiceId: map['invoice_id'] as String?,
      reportId: map['report_id'] as String?,
      originalPath: map['original_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      fileName: map['file_name'] as String,
      fileSize: (map['file_size'] as num? ?? 0).toInt(),
      mimeType: map['mime_type'] as String?,
      stage: map['stage'] as String? ?? AppConstants.photoStageIntake,
      photoType: map['photo_type'] as String? ?? 'ملاحظة إضافية',
      caption: map['caption'] as String?,
      capturedBy: map['captured_by'] as String?,
      capturedAt: map['captured_at'] as int,
      isOriginalRetained: (map['is_original_retained'] as int? ?? 1) == 1,
      isRequired: (map['is_required'] as int? ?? 0) == 1,
      isApproved: (map['is_approved'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] as int?,
      deleteReason: map['delete_reason'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'device_id': deviceId,
      'maintenance_id': maintenanceId,
      'invoice_id': invoiceId,
      'report_id': reportId,
      'original_path': originalPath,
      'thumbnail_path': thumbnailPath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'stage': stage,
      'photo_type': photoType,
      'caption': caption,
      'captured_by': capturedBy,
      'captured_at': capturedAt,
      'is_original_retained': isOriginalRetained ? 1 : 0,
      'is_required': isRequired ? 1 : 0,
      'is_approved': isApproved ? 1 : 0,
      'deleted_at': deletedAt,
      'delete_reason': deleteReason,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get stageLabel => AppConstants.devicePhotoStageLabel(stage);
}
