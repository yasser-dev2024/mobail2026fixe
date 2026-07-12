import 'package:uuid/uuid.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String? phone2;
  final String? email;
  final String? address;
  final String? notes;
  final String customerType; // regular, vip, wholesale
  final double totalSpent;
  final int visitCount;
  final int? lastVisit;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2,
    this.email,
    this.address,
    this.notes,
    required this.customerType,
    required this.totalSpent,
    required this.visitCount,
    this.lastVisit,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory CustomerModel.create({
    required String name,
    required String phone,
    String? phone2,
    String? email,
    String? address,
    String? notes,
    String customerType = 'regular',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return CustomerModel(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      phone2: phone2,
      email: email,
      address: address,
      notes: notes,
      customerType: customerType,
      totalSpent: 0.0,
      visitCount: 0,
      lastVisit: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      phone2: map['phone2'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      customerType: map['customer_type'] as String,
      totalSpent: (map['total_spent'] as num).toDouble(),
      visitCount: map['visit_count'] as int,
      lastVisit: map['last_visit'] as int?,
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
      'customer_type': customerType,
      'total_spent': totalSpent,
      'visit_count': visitCount,
      'last_visit': lastVisit,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    Object? phone2 = _sentinel,
    Object? email = _sentinel,
    Object? address = _sentinel,
    Object? notes = _sentinel,
    String? customerType,
    double? totalSpent,
    int? visitCount,
    Object? lastVisit = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phone2: phone2 == _sentinel ? this.phone2 : phone2 as String?,
      email: email == _sentinel ? this.email : email as String?,
      address: address == _sentinel ? this.address : address as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      customerType: customerType ?? this.customerType,
      totalSpent: totalSpent ?? this.totalSpent,
      visitCount: visitCount ?? this.visitCount,
      lastVisit: lastVisit == _sentinel ? this.lastVisit : lastVisit as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
    );
  }

  bool get isVip => totalSpent > 5000 || visitCount > 10;

  String get customerTypeLabel {
    switch (customerType) {
      case 'regular':
        return 'عميل عادي';
      case 'vip':
        return 'عميل مميز';
      case 'wholesale':
        return 'عميل جملة';
      default:
        return 'غير محدد';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CustomerModel(id: $id, name: $name, phone: $phone, customerType: $customerType)';
}

/// Private sentinel used by [CustomerModel.copyWith] to distinguish
/// an explicit `null` from an omitted argument.
const Object _sentinel = Object();
