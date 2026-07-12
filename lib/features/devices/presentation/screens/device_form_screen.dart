import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../device_photos/data/device_photo_repository.dart';
import '../../data/device_model.dart';
import '../../data/devices_repository.dart';

class DeviceFormScreen extends StatefulWidget {
  final String customerId;

  const DeviceFormScreen({super.key, required this.customerId});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = DevicesRepository();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _storageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_PendingDevicePhoto> _photos = [];
  bool _saving = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _imeiCtrl.dispose();
    _serialCtrl.dispose();
    _colorCtrl.dispose();
    _storageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final device = DeviceModel.create(
        customerId: widget.customerId,
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        imei: _emptyToNull(_imeiCtrl.text),
        serialNumber: _emptyToNull(_serialCtrl.text),
        color: _emptyToNull(_colorCtrl.text),
        storage: _emptyToNull(_storageCtrl.text),
        notes: _emptyToNull(_notesCtrl.text),
      );
      final deviceId = await _repo.create(device);
      for (final photo in _photos) {
        await DevicePhotoRepository().saveFromSource(
          sourcePath: photo.path,
          customerId: widget.customerId,
          deviceId: deviceId,
          stage: AppConstants.photoStageIntake,
          photoType: photo.type,
          caption: photo.caption,
          writeLegacyMaintenanceImage: false,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الجهاز بنجاح')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ الجهاز: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _capturePhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (file == null) return;
      _addPhoto(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر فتح الكاميرا: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
    );
    final paths = result?.files
            .map((file) => file.path)
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    for (final path in paths) {
      _addPhoto(path);
    }
  }

  void _addPhoto(String path) {
    if (_photos.any((photo) => photo.path == path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الصورة مضافة بالفعل')),
      );
      return;
    }
    setState(() => _photos.add(_PendingDevicePhoto(path: path)));
  }

  void _updatePhoto(int index, _PendingDevicePhoto photo) {
    setState(() => _photos[index] = photo);
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('إضافة جهاز'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات الجهاز',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'الشركة',
                            controller: _brandCtrl,
                            required: true,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'الشركة مطلوبة'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppFormField(
                            label: 'الموديل',
                            controller: _modelCtrl,
                            required: true,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'الموديل مطلوب'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'IMEI',
                            controller: _imeiCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppFormField(
                            label: 'الرقم التسلسلي',
                            controller: _serialCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'اللون',
                            controller: _colorCtrl,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppFormField(
                            label: 'السعة',
                            hint: 'مثال: 128GB',
                            controller: _storageCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: 'ملاحظات',
                      controller: _notesCtrl,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    _DevicePhotoCaptureSection(
                      photos: _photos,
                      onCamera: _capturePhoto,
                      onPick: _pickPhotos,
                      onUpdate: _updatePhoto,
                      onRemove: _removePhoto,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('حفظ الجهاز'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : () => context.pop(),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingDevicePhoto {
  final String path;
  final String type;
  final String? caption;

  const _PendingDevicePhoto({
    required this.path,
    this.type = 'ملاحظة إضافية',
    this.caption,
  });

  _PendingDevicePhoto copyWith({String? type, String? caption}) {
    return _PendingDevicePhoto(
      path: path,
      type: type ?? this.type,
      caption: caption ?? this.caption,
    );
  }
}

class _DevicePhotoCaptureSection extends StatelessWidget {
  final List<_PendingDevicePhoto> photos;
  final VoidCallback onCamera;
  final VoidCallback onPick;
  final void Function(int index, _PendingDevicePhoto photo) onUpdate;
  final void Function(int index) onRemove;

  const _DevicePhotoCaptureSection({
    required this.photos,
    required this.onCamera,
    required this.onPick,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تصوير حالة الجهاز عند الاستلام',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${photos.length} صورة',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('فتح الكاميرا والتقاط الصور'),
              ),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('إضافة صور من المعرض أو الملفات'),
              ),
            ],
          ),
          if (photos.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'يمكن حفظ الجهاز بدون صور، وسيظهر تنبيه إذا كانت سياسة المركز تتطلب صورًا من الإعدادات.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 250,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _PendingPhotoCard(
                  photo: photo,
                  onChanged: (updated) => onUpdate(index, updated),
                  onRemove: () => onRemove(index),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingPhotoCard extends StatelessWidget {
  final _PendingDevicePhoto photo;
  final ValueChanged<_PendingDevicePhoto> onChanged;
  final VoidCallback onRemove;

  const _PendingPhotoCard({
    required this.photo,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final exists = File(photo.path).existsSync();
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                exists
                    ? Image.file(File(photo.path), fit: BoxFit.cover)
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: const Icon(Icons.broken_image_rounded),
                      ),
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: IconButton.filledTonal(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value:
                      AppConstants.defaultDevicePhotoTypes.contains(photo.type)
                          ? photo.type
                          : 'ملاحظة إضافية',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'نوع الصورة',
                    isDense: true,
                  ),
                  items: AppConstants.defaultDevicePhotoTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(photo.copyWith(type: value));
                  },
                ),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: photo.caption,
                  minLines: 1,
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة الصورة',
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      onChanged(photo.copyWith(caption: value.trim())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
