import 'package:uuid/uuid.dart';

class MaintenanceImageModel {
  final String id;
  final String maintenanceId;
  final String imagePath;
  final String imageType; // before, during, after
  final String? caption;
  final int createdAt;

  const MaintenanceImageModel({
    required this.id,
    required this.maintenanceId,
    required this.imagePath,
    required this.imageType,
    this.caption,
    required this.createdAt,
  });

  factory MaintenanceImageModel.create({
    required String maintenanceId,
    required String imagePath,
    required String imageType,
    String? caption,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MaintenanceImageModel(
      id: const Uuid().v4(),
      maintenanceId: maintenanceId,
      imagePath: imagePath,
      imageType: imageType,
      caption: caption,
      createdAt: now,
    );
  }

  factory MaintenanceImageModel.fromMap(Map<String, dynamic> map) {
    return MaintenanceImageModel(
      id: map['id'] as String,
      maintenanceId: map['maintenance_id'] as String,
      imagePath: map['image_path'] as String,
      imageType: map['image_type'] as String,
      caption: map['caption'] as String?,
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'maintenance_id': maintenanceId,
      'image_path': imagePath,
      'image_type': imageType,
      'caption': caption,
      'created_at': createdAt,
    };
  }

  MaintenanceImageModel copyWith({
    String? id,
    String? maintenanceId,
    String? imagePath,
    String? imageType,
    Object? caption = _sentinel,
    int? createdAt,
  }) {
    return MaintenanceImageModel(
      id: id ?? this.id,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      imagePath: imagePath ?? this.imagePath,
      imageType: imageType ?? this.imageType,
      caption: caption == _sentinel ? this.caption : caption as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get typeLabel {
    switch (imageType) {
      case 'before':
        return 'قبل الإصلاح';
      case 'during':
        return 'أثناء الإصلاح';
      case 'after':
        return 'بعد الإصلاح';
      default:
        return 'غير محدد';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceImageModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MaintenanceImageModel(id: $id, maintenanceId: $maintenanceId, imageType: $imageType)';
}

/// Private sentinel used by [MaintenanceImageModel.copyWith] to distinguish
/// an explicit `null` from an omitted argument.
const Object _sentinel = Object();
