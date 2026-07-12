import 'package:uuid/uuid.dart';

class TransactionModel {
  final String id;
  final String type;
  final String? category;
  final String description;
  final double amount;
  final String? referenceId;
  final String? referenceType;
  final String paymentMethod;
  final int transactionDate;
  final String? notes;
  final String? createdBy;
  final int createdAt;
  final int? deletedAt;

  const TransactionModel({
    required this.id,
    required this.type,
    this.category,
    required this.description,
    required this.amount,
    this.referenceId,
    this.referenceType,
    required this.paymentMethod,
    required this.transactionDate,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.deletedAt,
  });

  factory TransactionModel.create({
    required String type,
    String? category,
    required String description,
    required double amount,
    String? referenceId,
    String? referenceType,
    String paymentMethod = 'cash',
    int? transactionDate,
    String? notes,
    String? createdBy,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return TransactionModel(
      id: const Uuid().v4(),
      type: type,
      category: category,
      description: description,
      amount: amount,
      referenceId: referenceId,
      referenceType: referenceType,
      paymentMethod: paymentMethod,
      transactionDate: transactionDate ?? now,
      notes: notes,
      createdBy: createdBy,
      createdAt: now,
    );
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      category: map['category'] as String?,
      description: map['description'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      referenceId: map['reference_id'] as String?,
      referenceType: map['reference_type'] as String?,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      transactionDate: map['transaction_date'] as int,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'description': description,
      'amount': amount,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'payment_method': paymentMethod,
      'transaction_date': transactionDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'deleted_at': deletedAt,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    Object? category = _sentinel,
    String? description,
    double? amount,
    Object? referenceId = _sentinel,
    Object? referenceType = _sentinel,
    String? paymentMethod,
    int? transactionDate,
    Object? notes = _sentinel,
    Object? createdBy = _sentinel,
    int? createdAt,
    Object? deletedAt = _sentinel,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category == _sentinel ? this.category : category as String?,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      referenceId:
          referenceId == _sentinel ? this.referenceId : referenceId as String?,
      referenceType: referenceType == _sentinel
          ? this.referenceType
          : referenceType as String?,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      notes: notes == _sentinel ? this.notes : notes as String?,
      createdBy: createdBy == _sentinel ? this.createdBy : createdBy as String?,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'income':
        return 'دخل';
      case 'expense':
        return 'مصروف';
      default:
        return type;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'salary':
        return 'رواتب';
      case 'rent':
        return 'إيجار';
      case 'utilities':
        return 'خدمات';
      case 'purchase':
        return 'مشتريات';
      case 'maintenance':
        return 'صيانة';
      case 'sales':
        return 'مبيعات';
      case 'repair':
        return 'إصلاح';
      case 'other':
        return 'أخرى';
      default:
        return category ?? 'أخرى';
    }
  }
}

const _sentinel = Object();
