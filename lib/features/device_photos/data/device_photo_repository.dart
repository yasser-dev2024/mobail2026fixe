import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/pdf_arabic_utils.dart';
import '../../../core/services/settings_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../maintenance/data/maintenance_image_model.dart';
import '../../maintenance/data/maintenance_repository.dart';
import 'device_photo_model.dart';

class CapturedDevicePhoto {
  final String sourcePath;
  final String stage;
  final String photoType;
  final String? caption;
  final bool isRequired;

  const CapturedDevicePhoto({
    required this.sourcePath,
    this.stage = AppConstants.photoStageIntake,
    this.photoType = 'ملاحظة إضافية',
    this.caption,
    this.isRequired = false,
  });
}

class DevicePhotoRepository {
  DevicePhotoRepository();

  final DatabaseService _db = DatabaseService();

  Future<DevicePhotoModel> saveFromSource({
    required String sourcePath,
    required String customerId,
    String? deviceId,
    String? maintenanceId,
    String? invoiceId,
    String? reportId,
    String stage = AppConstants.photoStageIntake,
    String photoType = 'ملاحظة إضافية',
    String? caption,
    bool isRequired = false,
    bool writeLegacyMaintenanceImage = true,
  }) async {
    final settings = SettingsService();
    await settings.load();

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw Exception('ملف الصورة غير موجود.');
    }

    final size = await source.length();
    final maxBytes = settings.photoMaxSizeMb * 1024 * 1024;
    if (size > maxBytes) {
      throw Exception(
          'حجم الصورة أكبر من الحد المسموح (${settings.photoMaxSizeMb}MB).');
    }

    final extension = p.extension(source.path).toLowerCase();
    final normalizedExt = extension.replaceFirst('.', '');
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(normalizedExt)) {
      throw Exception('صيغة الصورة غير مسموحة. استخدم PNG أو JPG أو WEBP.');
    }

    final appDir = await _db.getDataDirectory();
    final targetDir = Directory(
      p.join(
        appDir.path,
        'Images',
        'DevicePhotos',
        settings.shopId,
        customerId,
        deviceId ?? 'no_device',
      ),
    );
    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);

    final safeName = PdfArabicUtils.safeFileName(
      '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}$extension',
      fallback: 'photo$extension',
    );
    final targetPath = PdfArabicUtils.uniquePath(targetDir.path, safeName);
    await source.copy(targetPath);

    final user = AuthRepository().getCurrentUser();
    final model = DevicePhotoModel.create(
      shopId: settings.shopId,
      customerId: customerId,
      deviceId: deviceId,
      maintenanceId: maintenanceId,
      invoiceId: invoiceId,
      reportId: reportId,
      originalPath: targetPath,
      thumbnailPath: targetPath,
      fileName: p.basename(targetPath),
      fileSize: size,
      mimeType: _mimeType(normalizedExt),
      stage: stage,
      photoType: photoType.trim().isEmpty ? 'ملاحظة إضافية' : photoType.trim(),
      caption: _emptyToNull(caption),
      capturedBy: user?.username ?? user?.name ?? 'النظام',
      isOriginalRetained: settings.photoKeepOriginal,
      isRequired: isRequired,
    );

    await _db.insert('device_photos', model.toMap());

    if (writeLegacyMaintenanceImage && maintenanceId != null) {
      await MaintenanceRepository().addImage(
        MaintenanceImageModel.create(
          maintenanceId: maintenanceId,
          imagePath: targetPath,
          imageType: _legacyStage(stage),
          caption: caption,
        ),
      );
    }

    await _log(
      action: 'إضافة صورة جهاز',
      tableName: 'device_photos',
      recordId: model.id,
      newValue: '${model.stageLabel} - ${model.photoType}',
    );

    return model;
  }

  Future<List<DevicePhotoModel>> saveMany({
    required List<CapturedDevicePhoto> photos,
    required String customerId,
    String? deviceId,
    String? maintenanceId,
    bool writeLegacyMaintenanceImage = true,
  }) async {
    final saved = <DevicePhotoModel>[];
    for (final photo in photos) {
      saved.add(
        await saveFromSource(
          sourcePath: photo.sourcePath,
          customerId: customerId,
          deviceId: deviceId,
          maintenanceId: maintenanceId,
          stage: photo.stage,
          photoType: photo.photoType,
          caption: photo.caption,
          isRequired: photo.isRequired,
          writeLegacyMaintenanceImage: writeLegacyMaintenanceImage,
        ),
      );
    }
    return saved;
  }

  Future<List<DevicePhotoModel>> getForMaintenance(String maintenanceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_photos',
      where: 'shop_id = ? AND maintenance_id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, maintenanceId],
      orderBy: 'captured_at ASC',
    );
    return rows.map(DevicePhotoModel.fromMap).toList();
  }

  Future<List<DevicePhotoModel>> getForDevice(String deviceId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_photos',
      where: 'shop_id = ? AND device_id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, deviceId],
      orderBy: 'captured_at DESC',
    );
    return rows.map(DevicePhotoModel.fromMap).toList();
  }

  Future<List<DevicePhotoModel>> getForCustomer(String customerId) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_photos',
      where: 'shop_id = ? AND customer_id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, customerId],
      orderBy: 'captured_at DESC',
    );
    return rows.map(DevicePhotoModel.fromMap).toList();
  }

  Future<void> softDelete(
    String photoId, {
    String? reason,
    bool allowApproved = false,
  }) async {
    final shopId = await _db.getCurrentShopId();
    final rows = await _db.query(
      'device_photos',
      where: 'shop_id = ? AND id = ? AND deleted_at IS NULL',
      whereArgs: [shopId, photoId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final photo = DevicePhotoModel.fromMap(rows.first);
    if (photo.isApproved && !allowApproved) {
      throw Exception('لا يمكن حذف صورة معتمدة دون صلاحية إدارية وسبب موثق.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE device_photos SET deleted_at = ?, delete_reason = ?, updated_at = ? WHERE shop_id = ? AND id = ?',
      [now, _emptyToNull(reason), now, shopId, photoId],
    );
    await _log(
      action: 'حذف صورة جهاز',
      tableName: 'device_photos',
      recordId: photoId,
      oldValue: photo.originalPath,
      newValue: reason,
    );
  }

  Future<void> _log({
    required String action,
    String? tableName,
    String? recordId,
    String? oldValue,
    String? newValue,
  }) async {
    final user = AuthRepository().getCurrentUser();
    await _db.insert('audit_log', {
      'id': const Uuid().v4(),
      'user_id': user?.id,
      'username': user?.username ?? 'النظام',
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String _legacyStage(String stage) {
    switch (stage) {
      case AppConstants.photoStageDuringRepair:
      case AppConstants.photoStageOldParts:
      case AppConstants.photoStageNewParts:
        return 'during';
      case AppConstants.photoStageAfterRepair:
      case AppConstants.photoStageDelivery:
        return 'after';
      default:
        return 'before';
    }
  }

  String _mimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String? _emptyToNull(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }
}
