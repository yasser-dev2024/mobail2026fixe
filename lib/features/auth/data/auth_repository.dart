import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import 'user_model.dart';

class AuthRepository {
  static final AuthRepository _instance = AuthRepository._internal();
  factory AuthRepository() => _instance;
  AuthRepository._internal();

  final DatabaseService _db = DatabaseService();

  // In-memory current user session
  UserModel? _currentUser;

  /// Authenticates a user by username and password.
  ///
  /// Returns the [UserModel] on success, or `null` when:
  ///   - username not found / soft-deleted
  ///   - account is inactive
  ///   - account is currently locked
  ///   - password is wrong (also increments failed-attempt counter)
  Future<UserModel?> login(String username, String password) async {
    // Find user by username where deleted_at IS NULL
    final map = await _findByUsername(username);
    if (map == null) return null;
    final user = UserModel.fromMap(map);

    // Check if account is active
    if (!user.isActive) return null;

    // Check if locked
    if (user.isLocked) return null;

    // Check password
    if (user.passwordHash != DatabaseService.hashPassword(password)) {
      await _incrementFailedAttempts(user.id, user.failedAttempts);
      return null;
    }

    // Success – reset failed attempts, update last_login
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE users SET failed_attempts = 0, locked_until = NULL, last_login = ?, updated_at = ? WHERE id = ?',
      [now, now, user.id],
    );

    final updatedUser = user.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
      lastLogin: now,
    );
    _currentUser = updatedUser;

    await auditLog('login', tableName: 'users', recordId: user.id);

    return updatedUser;
  }

  /// Clears the current user session.
  void logout() {
    _currentUser = null;
  }

  /// Returns the currently logged-in user, or `null` if no session.
  UserModel? getCurrentUser() => _currentUser;

  /// Sets the current in-memory session user (e.g. after an external auth flow).
  void setCurrentUser(UserModel user) {
    _currentUser = user;
  }

  /// Persists a new user to the database and returns their generated ID.
  Future<String> createUser(UserModel user) async {
    final id = await _db.insert('users', user.toMap());
    await auditLog(
      'create_user',
      tableName: 'users',
      recordId: user.id,
      newValue: user.username,
    );
    return id ?? user.id;
  }

  /// Updates all fields of an existing user record (stamps updated_at).
  Future<void> updateUser(UserModel user) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = user.toMap();
    data['updated_at'] = now;
    await _db.update('users', data, user.id);
    await auditLog('update_user', tableName: 'users', recordId: user.id);
  }

  /// Returns every non-deleted user ordered by creation date.
  Future<List<UserModel>> getAllUsers() async {
    final results = await _db.query(
      'users',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return results.map((m) => UserModel.fromMap(m)).toList();
  }

  /// Changes the password for [userId].
  ///
  /// Verifies [oldPassword] first; returns `true` on success, `false` if the
  /// old password does not match or the user is not found.
  Future<bool> changePassword(
    String userId,
    String oldPassword,
    String newPassword,
  ) async {
    final result = await _db.queryOne('users', userId);
    if (result == null) return false;

    final user = UserModel.fromMap(result);
    if (user.passwordHash != DatabaseService.hashPassword(oldPassword)) {
      return false;
    }

    final newHash = DatabaseService.hashPassword(newPassword);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'users',
      {'password_hash': newHash, 'updated_at': now},
      userId,
    );
    await auditLog('change_password', tableName: 'users', recordId: userId);
    return true;
  }

  /// Resets failed login attempt counter and clears any lock on [userId].
  Future<void> resetFailedAttempts(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE users SET failed_attempts = 0, locked_until = NULL, updated_at = ? WHERE id = ?',
      [now, userId],
    );
  }

  /// Writes an entry to the `audit_log` table.
  Future<void> auditLog(
    String action, {
    String? tableName,
    String? recordId,
    String? oldValue,
    String? newValue,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('audit_log', {
      'id': const Uuid().v4(),
      'user_id': _currentUser?.id,
      'username': _currentUser?.username,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': now,
    });
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Looks up a user row by [username] (ignoring soft-deleted rows).
  /// Returns the raw map, or `null` if not found.
  Future<Map<String, dynamic>?> _findByUsername(String username) async {
    final users = await _db.query(
      'users',
      where: 'username = ? AND deleted_at IS NULL',
      whereArgs: [username],
      limit: 1,
    );
    return users.isEmpty ? null : users.first;
  }

  /// Increments the failed-attempt counter for [userId].
  ///
  /// When [currentAttempts] + 1 reaches [AppConstants.maxLoginAttempts] the
  /// account is locked for [AppConstants.lockDurationMinutes] minutes.
  Future<void> _incrementFailedAttempts(
    String userId,
    int currentAttempts,
  ) async {
    final newAttempts = currentAttempts + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (newAttempts >= AppConstants.maxLoginAttempts) {
      final lockUntil = DateTime.now()
          .add(const Duration(minutes: AppConstants.lockDurationMinutes))
          .millisecondsSinceEpoch;
      await _db.rawUpdate(
        'UPDATE users SET failed_attempts = ?, locked_until = ?, updated_at = ? WHERE id = ?',
        [newAttempts, lockUntil, now, userId],
      );
    } else {
      await _db.rawUpdate(
        'UPDATE users SET failed_attempts = ?, updated_at = ? WHERE id = ?',
        [newAttempts, now, userId],
      );
    }
  }
}
