import 'package:uuid/uuid.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String passwordHash;
  final String
      role; // owner, manager, branch_manager, cashier, technician, receptionist, accountant
  final String? email;
  final String? phone;
  final String? avatarPath;
  final bool isActive;
  final int failedAttempts;
  final int? lockedUntil;
  final int? lastLogin;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.email,
    this.phone,
    this.avatarPath,
    required this.isActive,
    required this.failedAttempts,
    this.lockedUntil,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory UserModel.create({
    required String name,
    required String username,
    required String passwordHash,
    required String role,
    String? email,
    String? phone,
    String? avatarPath,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return UserModel(
      id: const Uuid().v4(),
      name: name,
      username: username,
      passwordHash: passwordHash,
      role: role,
      email: email,
      phone: phone,
      avatarPath: avatarPath,
      isActive: true,
      failedAttempts: 0,
      lockedUntil: null,
      lastLogin: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      role: map['role'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
      isActive: (map['is_active'] as int) == 1,
      failedAttempts: map['failed_attempts'] as int,
      lockedUntil: map['locked_until'] as int?,
      lastLogin: map['last_login'] as int?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'email': email,
      'phone': phone,
      'avatar_path': avatarPath,
      'is_active': isActive ? 1 : 0,
      'failed_attempts': failedAttempts,
      'locked_until': lockedUntil,
      'last_login': lastLogin,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? passwordHash,
    String? role,
    Object? email = _sentinel,
    Object? phone = _sentinel,
    Object? avatarPath = _sentinel,
    bool? isActive,
    int? failedAttempts,
    Object? lockedUntil = _sentinel,
    Object? lastLogin = _sentinel,
    int? createdAt,
    int? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      email: email == _sentinel ? this.email : email as String?,
      phone: phone == _sentinel ? this.phone : phone as String?,
      avatarPath:
          avatarPath == _sentinel ? this.avatarPath : avatarPath as String?,
      isActive: isActive ?? this.isActive,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil:
          lockedUntil == _sentinel ? this.lockedUntil : lockedUntil as int?,
      lastLogin: lastLogin == _sentinel ? this.lastLogin : lastLogin as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as int?,
    );
  }

  /// Role-based access control.
  ///
  /// Supported modules:
  ///   user_management, sales, customers, inventory,
  ///   maintenance, notifications, reports, settings
  ///
  /// Access matrix:
  ///   owner        – all modules
  ///   manager      – all modules except full user_management (view-only)
  ///   cashier      – sales, customers, inventory (view), notifications
  ///   technician   – maintenance, inventory (view), notifications
  ///   receptionist – customers, maintenance (view), notifications
  bool canAccess(String module) {
    switch (role) {
      case 'owner':
        return true;

      case 'manager':
      case 'branch_manager':
        // Managers can access every module; user_management is view-only
        // (enforced separately in the UI layer).
        return true;

      case 'accountant':
        return const {
          'sales',
          'customers',
          'accounting',
          'reports',
          'notifications',
        }.contains(module);

      case 'cashier':
        return const {
          'sales',
          'customers',
          'inventory',
          'notifications',
        }.contains(module);

      case 'technician':
        return const {
          'maintenance',
          'inventory',
          'notifications',
        }.contains(module);

      case 'receptionist':
        return const {
          'customers',
          'maintenance',
          'notifications',
        }.contains(module);

      default:
        return false;
    }
  }

  bool get isLocked =>
      lockedUntil != null &&
      DateTime.now().millisecondsSinceEpoch < lockedUntil!;

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'مالك';
      case 'manager':
        return 'مدير';
      case 'branch_manager':
        return 'مدير فرع';
      case 'cashier':
        return 'كاشير';
      case 'technician':
        return 'فني';
      case 'receptionist':
        return 'موظف استقبال';
      case 'accountant':
        return 'محاسب';
      default:
        return 'غير محدد';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, username: $username, role: $role, isActive: $isActive)';
}

/// Private sentinel used by [UserModel.copyWith] to distinguish
/// an explicit `null` from an omitted argument.
const Object _sentinel = Object();
