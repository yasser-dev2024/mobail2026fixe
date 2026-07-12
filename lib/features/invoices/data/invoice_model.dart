import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';

class InvoiceModel {
  final String id;
  final String shopId;
  final String invoiceNumber;
  final String status;
  final String customerId;
  final String? deviceId;
  final String maintenanceId;
  final String customerName;
  final String customerPhone;
  final String deviceName;
  final String? imei;
  final String? serialNumber;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double amountPaid;
  final double amountDue;
  final String? paymentMethod;
  final String? warrantyType;
  final int warrantyDays;
  final int? warrantyStart;
  final int? warrantyEnd;
  final String warrantyStatus;
  final String? warrantyTermsSnapshot;
  final String? centerSettingsSnapshot;
  final String? pdfPath;
  final String? fileName;
  final String sentStatus;
  final int? sentAt;
  final String? sentMethod;
  final String? createdBy;
  final int createdAt;
  final int updatedAt;
  final int? approvedAt;
  final int? cancelledAt;
  final String? cancelReason;
  final int revision;
  final String? notes;

  const InvoiceModel({
    required this.id,
    required this.shopId,
    required this.invoiceNumber,
    required this.status,
    required this.customerId,
    this.deviceId,
    required this.maintenanceId,
    required this.customerName,
    required this.customerPhone,
    required this.deviceName,
    this.imei,
    this.serialNumber,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.amountPaid,
    required this.amountDue,
    this.paymentMethod,
    this.warrantyType,
    required this.warrantyDays,
    this.warrantyStart,
    this.warrantyEnd,
    required this.warrantyStatus,
    this.warrantyTermsSnapshot,
    this.centerSettingsSnapshot,
    this.pdfPath,
    this.fileName,
    required this.sentStatus,
    this.sentAt,
    this.sentMethod,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.cancelledAt,
    this.cancelReason,
    required this.revision,
    this.notes,
  });

  factory InvoiceModel.create({
    required String shopId,
    required String invoiceNumber,
    required String customerId,
    String? deviceId,
    required String maintenanceId,
    required String customerName,
    required String customerPhone,
    required String deviceName,
    String? imei,
    String? serialNumber,
    required double subtotal,
    double discount = 0,
    required double tax,
    required double total,
    required double amountPaid,
    String? paymentMethod,
    String? warrantyType,
    int warrantyDays = 0,
    int? warrantyStart,
    int? warrantyEnd,
    String? warrantyTermsSnapshot,
    String? centerSettingsSnapshot,
    String? createdBy,
    String? notes,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return InvoiceModel(
      id: const Uuid().v4(),
      shopId: shopId,
      invoiceNumber: invoiceNumber,
      status: AppConstants.invoiceDraft,
      customerId: customerId,
      deviceId: deviceId,
      maintenanceId: maintenanceId,
      customerName: customerName,
      customerPhone: customerPhone,
      deviceName: deviceName,
      imei: imei,
      serialNumber: serialNumber,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      amountPaid: amountPaid,
      amountDue: total - amountPaid,
      paymentMethod: paymentMethod,
      warrantyType: warrantyType,
      warrantyDays: warrantyDays,
      warrantyStart: warrantyStart,
      warrantyEnd: warrantyEnd,
      warrantyStatus: calculateWarrantyStatus(
        warrantyType: warrantyType,
        warrantyEnd: warrantyEnd,
      ),
      warrantyTermsSnapshot: warrantyTermsSnapshot,
      centerSettingsSnapshot: centerSettingsSnapshot,
      pdfPath: null,
      fileName: null,
      sentStatus: 'not_sent',
      sentAt: null,
      sentMethod: null,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      approvedAt: null,
      cancelledAt: null,
      cancelReason: null,
      revision: 1,
      notes: notes,
    );
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String? ?? 'default_shop',
      invoiceNumber: map['invoice_number'] as String,
      status: map['status'] as String? ?? AppConstants.invoiceDraft,
      customerId: map['customer_id'] as String,
      deviceId: map['device_id'] as String?,
      maintenanceId: map['maintenance_id'] as String,
      customerName: map['customer_name'] as String? ?? '',
      customerPhone: map['customer_phone'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? '',
      imei: map['imei'] as String?,
      serialNumber: map['serial_number'] as String?,
      subtotal: (map['subtotal'] as num? ?? 0).toDouble(),
      discount: (map['discount'] as num? ?? 0).toDouble(),
      tax: (map['tax'] as num? ?? 0).toDouble(),
      total: (map['total'] as num? ?? 0).toDouble(),
      amountPaid: (map['amount_paid'] as num? ?? 0).toDouble(),
      amountDue: (map['amount_due'] as num? ?? 0).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      warrantyType: map['warranty_type'] as String?,
      warrantyDays: (map['warranty_days'] as num? ?? 0).toInt(),
      warrantyStart: map['warranty_start'] as int?,
      warrantyEnd: map['warranty_end'] as int?,
      warrantyStatus: map['warranty_status'] as String? ?? 'none',
      warrantyTermsSnapshot: map['warranty_terms_snapshot'] as String?,
      centerSettingsSnapshot: map['center_settings_snapshot'] as String?,
      pdfPath: map['pdf_path'] as String?,
      fileName: map['file_name'] as String?,
      sentStatus: map['sent_status'] as String? ?? 'not_sent',
      sentAt: map['sent_at'] as int?,
      sentMethod: map['sent_method'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      approvedAt: map['approved_at'] as int?,
      cancelledAt: map['cancelled_at'] as int?,
      cancelReason: map['cancel_reason'] as String?,
      revision: (map['revision'] as num? ?? 1).toInt(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'invoice_number': invoiceNumber,
      'status': status,
      'customer_id': customerId,
      'device_id': deviceId,
      'maintenance_id': maintenanceId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'device_name': deviceName,
      'imei': imei,
      'serial_number': serialNumber,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'amount_paid': amountPaid,
      'amount_due': amountDue,
      'payment_method': paymentMethod,
      'warranty_type': warrantyType,
      'warranty_days': warrantyDays,
      'warranty_start': warrantyStart,
      'warranty_end': warrantyEnd,
      'warranty_status': warrantyStatus,
      'warranty_terms_snapshot': warrantyTermsSnapshot,
      'center_settings_snapshot': centerSettingsSnapshot,
      'pdf_path': pdfPath,
      'file_name': fileName,
      'sent_status': sentStatus,
      'sent_at': sentAt,
      'sent_method': sentMethod,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'approved_at': approvedAt,
      'cancelled_at': cancelledAt,
      'cancel_reason': cancelReason,
      'revision': revision,
      'notes': notes,
    };
  }

  InvoiceModel copyWith({
    String? id,
    String? shopId,
    String? invoiceNumber,
    String? status,
    String? customerId,
    Object? deviceId = _sentinel,
    String? maintenanceId,
    String? customerName,
    String? customerPhone,
    String? deviceName,
    Object? imei = _sentinel,
    Object? serialNumber = _sentinel,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    double? amountPaid,
    double? amountDue,
    Object? paymentMethod = _sentinel,
    Object? warrantyType = _sentinel,
    int? warrantyDays,
    Object? warrantyStart = _sentinel,
    Object? warrantyEnd = _sentinel,
    String? warrantyStatus,
    Object? warrantyTermsSnapshot = _sentinel,
    Object? centerSettingsSnapshot = _sentinel,
    Object? pdfPath = _sentinel,
    Object? fileName = _sentinel,
    String? sentStatus,
    Object? sentAt = _sentinel,
    Object? sentMethod = _sentinel,
    Object? createdBy = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? approvedAt = _sentinel,
    Object? cancelledAt = _sentinel,
    Object? cancelReason = _sentinel,
    int? revision,
    Object? notes = _sentinel,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      deviceId: deviceId == _sentinel ? this.deviceId : deviceId as String?,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deviceName: deviceName ?? this.deviceName,
      imei: imei == _sentinel ? this.imei : imei as String?,
      serialNumber: serialNumber == _sentinel
          ? this.serialNumber
          : serialNumber as String?,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      amountDue: amountDue ?? this.amountDue,
      paymentMethod: paymentMethod == _sentinel
          ? this.paymentMethod
          : paymentMethod as String?,
      warrantyType: warrantyType == _sentinel
          ? this.warrantyType
          : warrantyType as String?,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      warrantyStart: warrantyStart == _sentinel
          ? this.warrantyStart
          : warrantyStart as int?,
      warrantyEnd:
          warrantyEnd == _sentinel ? this.warrantyEnd : warrantyEnd as int?,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      warrantyTermsSnapshot: warrantyTermsSnapshot == _sentinel
          ? this.warrantyTermsSnapshot
          : warrantyTermsSnapshot as String?,
      centerSettingsSnapshot: centerSettingsSnapshot == _sentinel
          ? this.centerSettingsSnapshot
          : centerSettingsSnapshot as String?,
      pdfPath: pdfPath == _sentinel ? this.pdfPath : pdfPath as String?,
      fileName: fileName == _sentinel ? this.fileName : fileName as String?,
      sentStatus: sentStatus ?? this.sentStatus,
      sentAt: sentAt == _sentinel ? this.sentAt : sentAt as int?,
      sentMethod:
          sentMethod == _sentinel ? this.sentMethod : sentMethod as String?,
      createdBy: createdBy == _sentinel ? this.createdBy : createdBy as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt:
          approvedAt == _sentinel ? this.approvedAt : approvedAt as int?,
      cancelledAt:
          cancelledAt == _sentinel ? this.cancelledAt : cancelledAt as int?,
      cancelReason: cancelReason == _sentinel
          ? this.cancelReason
          : cancelReason as String?,
      revision: revision ?? this.revision,
      notes: notes == _sentinel ? this.notes : notes as String?,
    );
  }

  String get statusLabel => AppConstants.invoiceStatusLabel(status);

  static String calculateWarrantyStatus({
    required String? warrantyType,
    required int? warrantyEnd,
  }) {
    if (warrantyType == null || warrantyType == AppConstants.warrantyNone) {
      return 'none';
    }
    if (warrantyEnd == null) return 'pending';
    return DateTime.now().millisecondsSinceEpoch <= warrantyEnd
        ? 'active'
        : 'expired';
  }
}

const Object _sentinel = Object();
