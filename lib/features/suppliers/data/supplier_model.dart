import 'package:uuid/uuid.dart';

class SupplierModel {
  final String id;
  final String name;
  final String? phone;
  final String? phone2;
  final String? email;
  final String? address;
  final String? notes;
  final double balance;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.phone2,
    this.email,
    this.address,
    this.notes,
    required this.balance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory SupplierModel.create({
    required String name,
    String? phone,
    String? phone2,
    String? email,
    String? address,
    String? notes,
    double balance = 0.0,
    bool isActive = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return SupplierModel(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      phone2: phone2,
      email: email,
      address: address,
      notes: notes,
      balance: balance,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      phone2: map['phone2'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'phone2': phone2,
      'email': email,
      'address': address,
      'notes': notes,
      'balance': balance,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  SupplierModel copyWith({
    String? id,
    String? name,
    Object? phone = _sentinel,
    Object? phone2 = _sentinel,
    Object? email = _sentinel,
    Object? address = _sentinel,
    Object? notes = _sentinel,
    double? balance,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone == _sentinel ? this.phone : phone as String?,
      phone2: phone2 == _sentinel ? this.phone2 : phone2 as String?,
      email: email == _sentinel ? this.email : email as String?,
      address: address == _sentinel ? this.address : address as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
    );
  }
}

const _sentinel = Object();
