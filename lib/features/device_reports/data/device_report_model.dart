import 'package:uuid/uuid.dart';

class DeviceReportModel {
  final String id;
  final String shopId;
  final String reportNumber;
  final String reportType;
  final String status;
  final String customerId;
  final String? deviceId;
  final String? maintenanceId;
  final String? invoiceId;
  final String title;
  final String? pdfPath;
  final String? fileName;
  final String? includedPhotoIds;
  final String? centerSettingsSnapshot;
  final String? termsSnapshot;
  final String sentStatus;
  final int? sentAt;
  final String? sentMethod;
  final String? createdBy;
  final int createdAt;
  final int updatedAt;
  final int? approvedAt;
  final int revision;
  final String? notes;

  const DeviceReportModel({
    required this.id,
    required this.shopId,
    required this.reportNumber,
    required this.reportType,
    required this.status,
    required this.customerId,
    this.deviceId,
    this.maintenanceId,
    this.invoiceId,
    required this.title,
    this.pdfPath,
    this.fileName,
    this.includedPhotoIds,
    this.centerSettingsSnapshot,
    this.termsSnapshot,
    required this.sentStatus,
    this.sentAt,
    this.sentMethod,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    required this.revision,
    this.notes,
  });

  factory DeviceReportModel.create({
    required String shopId,
    required String reportNumber,
    required String reportType,
    required String customerId,
    String? deviceId,
    String? maintenanceId,
    String? invoiceId,
    required String title,
    String? includedPhotoIds,
    String? centerSettingsSnapshot,
    String? termsSnapshot,
    String? createdBy,
    String? notes,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DeviceReportModel(
      id: const Uuid().v4(),
      shopId: shopId,
      reportNumber: reportNumber,
      reportType: reportType,
      status: 'approved',
      customerId: customerId,
      deviceId: deviceId,
      maintenanceId: maintenanceId,
      invoiceId: invoiceId,
      title: title,
      pdfPath: null,
      fileName: null,
      includedPhotoIds: includedPhotoIds,
      centerSettingsSnapshot: centerSettingsSnapshot,
      termsSnapshot: termsSnapshot,
      sentStatus: 'not_sent',
      sentAt: null,
      sentMethod: null,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      approvedAt: now,
      revision: 1,
      notes: notes,
    );
  }

  factory DeviceReportModel.fromMap(Map<String, dynamic> map) {
    return DeviceReportModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String? ?? 'default_shop',
      reportNumber: map['report_number'] as String,
      reportType: map['report_type'] as String,
      status: map['status'] as String? ?? 'draft',
      customerId: map['customer_id'] as String,
      deviceId: map['device_id'] as String?,
      maintenanceId: map['maintenance_id'] as String?,
      invoiceId: map['invoice_id'] as String?,
      title: map['title'] as String? ?? '',
      pdfPath: map['pdf_path'] as String?,
      fileName: map['file_name'] as String?,
      includedPhotoIds: map['included_photo_ids'] as String?,
      centerSettingsSnapshot: map['center_settings_snapshot'] as String?,
      termsSnapshot: map['terms_snapshot'] as String?,
      sentStatus: map['sent_status'] as String? ?? 'not_sent',
      sentAt: map['sent_at'] as int?,
      sentMethod: map['sent_method'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      approvedAt: map['approved_at'] as int?,
      revision: (map['revision'] as num? ?? 1).toInt(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'report_number': reportNumber,
      'report_type': reportType,
      'status': status,
      'customer_id': customerId,
      'device_id': deviceId,
      'maintenance_id': maintenanceId,
      'invoice_id': invoiceId,
      'title': title,
      'pdf_path': pdfPath,
      'file_name': fileName,
      'included_photo_ids': includedPhotoIds,
      'center_settings_snapshot': centerSettingsSnapshot,
      'terms_snapshot': termsSnapshot,
      'sent_status': sentStatus,
      'sent_at': sentAt,
      'sent_method': sentMethod,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'approved_at': approvedAt,
      'revision': revision,
      'notes': notes,
    };
  }

  DeviceReportModel copyWith({
    String? pdfPath,
    String? fileName,
    String? sentStatus,
    int? sentAt,
    String? sentMethod,
    int? updatedAt,
  }) {
    return DeviceReportModel(
      id: id,
      shopId: shopId,
      reportNumber: reportNumber,
      reportType: reportType,
      status: status,
      customerId: customerId,
      deviceId: deviceId,
      maintenanceId: maintenanceId,
      invoiceId: invoiceId,
      title: title,
      pdfPath: pdfPath ?? this.pdfPath,
      fileName: fileName ?? this.fileName,
      includedPhotoIds: includedPhotoIds,
      centerSettingsSnapshot: centerSettingsSnapshot,
      termsSnapshot: termsSnapshot,
      sentStatus: sentStatus ?? this.sentStatus,
      sentAt: sentAt ?? this.sentAt,
      sentMethod: sentMethod ?? this.sentMethod,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt,
      revision: revision,
      notes: notes,
    );
  }
}
