import 'package:uuid/uuid.dart';

class DeviceModel {
  final String id;
  final String customerId;
  final String brand;
  final String model;
  final String? imei;
  final String? serialNumber;
  final String? color;
  final String? storage;
  final String? imagePath;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const DeviceModel({
    required this.id,
    required this.customerId,
    required this.brand,
    required this.model,
    this.imei,
    this.serialNumber,
    this.color,
    this.storage,
    this.imagePath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory DeviceModel.create({
    required String customerId,
    required String brand,
    required String model,
    String? imei,
    String? serialNumber,
    String? color,
    String? storage,
    String? imagePath,
    String? notes,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DeviceModel(
      id: const Uuid().v4(),
      customerId: customerId,
      brand: brand,
      model: model,
      imei: imei,
      serialNumber: serialNumber,
      color: color,
      storage: storage,
      imagePath: imagePath,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      imei: map['imei'] as String?,
      serialNumber: map['serial_number'] as String?,
      color: map['color'] as String?,
      storage: map['storage'] as String?,
      imagePath: map['image_path'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'brand': brand,
      'model': model,
      'imei': imei,
      'serial_number': serialNumber,
      'color': color,
      'storage': storage,
      'image_path': imagePath,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? customerId,
    String? brand,
    String? model,
    Object? imei = _sentinel,
    Object? serialNumber = _sentinel,
    Object? color = _sentinel,
    Object? storage = _sentinel,
    Object? imagePath = _sentinel,
    Object? notes = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      imei: imei == _sentinel ? this.imei : imei as String?,
      serialNumber: serialNumber == _sentinel
          ? this.serialNumber
          : serialNumber as String?,
      color: color == _sentinel ? this.color : color as String?,
      storage: storage == _sentinel ? this.storage : storage as String?,
      imagePath: imagePath == _sentinel ? this.imagePath : imagePath as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
    );
  }

  String get displayName => '$brand $model';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DeviceModel(id: $id, customerId: $customerId, brand: $brand, model: $model)';
}

/// Private sentinel used by [DeviceModel.copyWith] to distinguish
/// an explicit `null` from an omitted argument.
const Object _sentinel = Object();
