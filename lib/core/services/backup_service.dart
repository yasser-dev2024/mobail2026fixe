import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../database/database_service.dart';
import 'settings_service.dart';

/// Service for creating and restoring ZIP-based backups of the SQLite database
/// and the Images directory.
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();
  String? lastError;

  // ---------------------------------------------------------------------------
  // Directory helpers
  // ---------------------------------------------------------------------------

  /// Returns the application support directory used as the root for all app data.
  Future<Directory> getAppDataDir() async {
    return await _db.getDataDirectory();
  }

  /// Returns the full path to the SQLite database file.
  Future<String> getDatabasePath() async {
    return await _db.getDatabasePath();
  }

  /// Returns the path to the Images directory (appDataDir/Images).
  Future<String> getImagesDir() async {
    final appDir = await getAppDataDir();
    return p.join(appDir.path, 'Images');
  }

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  /// Creates a ZIP backup archive at [destinationPath].
  ///
  /// The archive contains:
  ///   - `database/<db-filename>` — the SQLite database file
  ///   - `Images/<relative-path>` — every file inside the Images directory
  ///
  /// Logs a record to `backup_logs` on success.
  /// Returns `true` on success, `false` on any error.
  Future<bool> createBackup(
    String destinationPath, {
    String type = 'manual',
    String? notes,
  }) async {
    try {
      lastError = null;
      final archive = Archive();
      final settings = SettingsService();
      await settings.load();

      final manifest = jsonEncode({
        'app': 'mobile_shop_pro',
        'format': 'proshop_backup',
        'version': 1,
        'shop_id': settings.shopId,
        'shop_name': settings.shopName,
        'created_at': DateTime.now().toIso8601String(),
        'type': type,
      });
      final manifestBytes = utf8.encode(manifest);
      archive.addFile(
        ArchiveFile(
          'manifest.json',
          manifestBytes.length,
          manifestBytes,
        ),
      );

      // --- Add database file ---
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        final dbBytes = await dbFile.readAsBytes();
        archive.addFile(
          ArchiveFile(
            'database/${p.basename(dbPath)}',
            dbBytes.length,
            dbBytes,
          ),
        );
      }

      // --- Add image files ---
      final imagesDirPath = await getImagesDir();
      final imagesDir = Directory(imagesDirPath);
      if (imagesDir.existsSync()) {
        for (final entity in imagesDir.listSync(recursive: true)) {
          if (entity is File) {
            // Build a path relative to the parent of imagesDir so the archive
            // entry looks like "Images/<filename>" or "Images/<subdir>/<filename>".
            final relativePath = p
                .relative(entity.path, from: p.dirname(imagesDir.path))
                .replaceAll('\\', '/');
            final bytes = await entity.readAsBytes();
            archive.addFile(
              ArchiveFile(relativePath, bytes.length, bytes),
            );
          }
        }
      }

      // --- Encode and write to destination ---
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        return false;
      }

      final destinationFile = File(destinationPath);
      final parentDir = destinationFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
      await destinationFile.writeAsBytes(zipBytes);

      // --- Log backup to database ---
      final fileSize = await destinationFile.length();
      await _db.insert('backup_logs', {
        'id': _uuid.v4(),
        'shop_id': settings.shopId,
        'file_path': destinationPath,
        'file_size': fileSize,
        'type': type,
        'status': 'success',
        'notes': notes,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<AutoBackupResult> createAutomaticBackupIfDue() async {
    final enabled = (await _db.getSetting('auto_backup')) ?? 'true';
    if (enabled != 'true') {
      return const AutoBackupResult.skipped('النسخ التلقائي متوقف.');
    }

    final configuredInterval =
        int.tryParse((await _db.getSetting('auto_backup_interval')) ?? '') ??
            AppConstants.automaticBackupIntervalDays;
    final intervalDays =
        configuredInterval < AppConstants.automaticBackupIntervalDays
            ? AppConstants.automaticBackupIntervalDays
            : configuredInterval;
    final intervalMs = Duration(days: intervalDays).inMilliseconds;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final shopId = await _db.getCurrentShopId();

    final latest = await _db.rawQuery(
      "SELECT created_at, file_path FROM backup_logs WHERE shop_id = ? AND type = 'auto' AND status = 'success' ORDER BY created_at DESC LIMIT 1",
      [shopId],
    );
    if (latest.isNotEmpty) {
      final lastCreated = latest.first['created_at'] as int? ?? 0;
      if (nowMs - lastCreated < intervalMs) {
        return AutoBackupResult.skipped(
          'آخر نسخة تلقائية لا تزال ضمن فترة $intervalDays أيام.',
          filePath: latest.first['file_path'] as String?,
        );
      }
    }

    final appDir = await getAppDataDir();
    final backupsDir = Directory(p.join(appDir.path, 'Backups', shopId));
    if (!backupsDir.existsSync()) {
      backupsDir.createSync(recursive: true);
    }

    final stamp = _backupStamp(now);
    final destinationPath = p.join(
      backupsDir.path,
      'ProShop_AutoBackup_$stamp${AppConstants.backupExtension}',
    );
    final ok = await createBackup(
      destinationPath,
      type: 'auto',
      notes: 'نسخة تلقائية كل $intervalDays أيام',
    );

    if (!ok) {
      return const AutoBackupResult.failed('تعذر إنشاء النسخة التلقائية.');
    }
    return AutoBackupResult.created(destinationPath);
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  /// Restores a backup from the ZIP archive at [backupFilePath].
  ///
  /// Steps:
  ///   1. Read and decode the ZIP archive.
  ///   2. Close the database connection before overwriting the DB file.
  ///   3. Extract `database/...` entries to the app Database folder.
  ///   4. Extract `Images/...` entries to the app Images directory.
  ///   5. The database will reconnect automatically on the next use.
  ///
  /// Returns `true` on success, `false` on any error.
  Future<bool> restoreBackup(String backupFilePath) async {
    try {
      lastError = null;
      final backupFile = File(backupFilePath);
      if (!backupFile.existsSync()) return false;

      final bytes = Uint8List.fromList(await backupFile.readAsBytes());
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = _readManifest(archive);
      if (manifest == null) {
        lastError =
            'هذه النسخة الاحتياطية لا تحتوي على هوية محل، وتم رفضها لحماية بيانات المحلات.';
        return false;
      }

      final currentShopId = await _db.getCurrentShopId();
      final backupShopId = manifest['shop_id']?.toString();
      if (backupShopId == null || backupShopId.trim().isEmpty) {
        lastError = 'هوية المحل داخل النسخة الاحتياطية غير صالحة.';
        return false;
      }
      if (backupShopId != currentShopId) {
        final backupShopName = manifest['shop_name']?.toString() ?? 'محل آخر';
        lastError =
            'تم رفض الاستعادة: النسخة تخص "$backupShopName" ($backupShopId)، وهذه النسخة تخص $currentShopId.';
        return false;
      }

      // Close the database before overwriting its file on disk.
      await _db.close();

      for (final file in archive) {
        if (!file.isFile) continue;

        // Block path traversal attacks (e.g. ../../AppData/...)
        if (file.name.contains('..')) continue;

        final content = file.content as List<int>;

        if (file.name.startsWith('database/')) {
          // Restore the database file to the Database folder.
          final appDir = await getAppDataDir();
          final dbFolder = Directory(p.join(appDir.path, 'Database'));
          if (!dbFolder.existsSync()) {
            dbFolder.createSync(recursive: true);
          }
          final outFile = File(p.join(dbFolder.path, p.basename(file.name)));
          await outFile.writeAsBytes(content);
        } else if (file.name.startsWith('Images/') ||
            file.name.startsWith('images/')) {
          // Restore image files preserving the relative directory structure.
          final appDir = await getAppDataDir();
          final outFile = File(p.join(appDir.path, file.name));
          final parent = outFile.parent;
          if (!parent.existsSync()) {
            parent.createSync(recursive: true);
          }
          await outFile.writeAsBytes(content);
        }
      }

      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Backup logs
  // ---------------------------------------------------------------------------

  /// Returns all rows from the `backup_logs` table ordered by newest first.
  Future<List<Map<String, dynamic>>> getBackupLogs() async {
    final shopId = await _db.getCurrentShopId();
    return await _db.query(
      'backup_logs',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at DESC',
    );
  }

  String _backupStamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }

  Map<String, dynamic>? _readManifest(Archive archive) {
    for (final file in archive) {
      if (!file.isFile || file.name != 'manifest.json') continue;
      try {
        final content = file.content as List<int>;
        final decoded = jsonDecode(utf8.decode(content));
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class AutoBackupResult {
  final bool created;
  final bool failed;
  final String message;
  final String? filePath;

  const AutoBackupResult._({
    required this.created,
    required this.failed,
    required this.message,
    this.filePath,
  });

  const AutoBackupResult.created(String filePath)
      : this._(
          created: true,
          failed: false,
          message: 'تم إنشاء نسخة تلقائية جديدة.',
          filePath: filePath,
        );

  const AutoBackupResult.skipped(String message, {String? filePath})
      : this._(
          created: false,
          failed: false,
          message: message,
          filePath: filePath,
        );

  const AutoBackupResult.failed(String message)
      : this._(
          created: false,
          failed: true,
          message: message,
        );
}
