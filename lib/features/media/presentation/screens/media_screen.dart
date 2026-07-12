import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows =
        await _db.query('media_files', orderBy: 'created_at DESC', limit: 100);
    if (!mounted) return;
    setState(() {
      _files = rows;
      _loading = false;
    });
  }

  Future<void> _pickAndSave() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملفاً لحفظه',
      allowMultiple: true,
    );
    if (result == null) return;

    setState(() => _busy = true);
    final appDir = await _db.getDataDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'Media'));
    if (!mediaDir.existsSync()) mediaDir.createSync(recursive: true);

    for (final picked in result.files) {
      final sourcePath = picked.path;
      if (sourcePath == null) continue;
      final source = File(sourcePath);
      if (!source.existsSync()) continue;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${stamp}_${p.basename(sourcePath)}';
      final destination = File(p.join(mediaDir.path, fileName));
      await source.copy(destination.path);
      await _db.insert('media_files', {
        'id': const Uuid().v4(),
        'reference_id': 'general',
        'reference_type': 'general',
        'file_path': destination.path,
        'file_name': p.basename(sourcePath),
        'file_type':
            p.extension(sourcePath).replaceFirst('.', '').toLowerCase(),
        'file_size': await destination.length(),
        'caption': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الملفات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: LoadingOverlay(
        isLoading: _busy,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'الملفات المحفوظة',
                          value: '${_files.length}',
                          icon: Icons.photo_library_rounded,
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: StatCard(
                          title: 'تخزين محلي',
                          value: 'Media',
                          icon: Icons.folder_rounded,
                          gradient: AppColors.tealGradient,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'مركز الصور والملفات',
                          trailing: ElevatedButton.icon(
                            onPressed: _pickAndSave,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('إضافة ملفات'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_files.isEmpty)
                          const EmptyState(
                              message: 'لا توجد ملفات محفوظة',
                              icon: Icons.perm_media_outlined)
                        else
                          ..._files.map((file) => _MediaTile(file: file)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSave,
        icon: const Icon(Icons.add_rounded),
        label: const Text('ملف جديد'),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Map<String, dynamic> file;

  const _MediaTile({required this.file});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    final created =
        DateTime.fromMillisecondsSinceEpoch(file['created_at'] as int);
    final size = ((file['file_size'] as num?)?.toDouble() ?? 0) / 1024;
    final type = file['file_type'] as String? ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withAlpha(25),
        child: Icon(_iconFor(type), color: AppColors.primary),
      ),
      title: Text(file['file_name'] as String? ?? ''),
      subtitle: Text(file['file_path'] as String? ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatter.format(created)),
          Text('${size.toStringAsFixed(1)} KB'),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(type)) {
      return Icons.image_rounded;
    }
    if (type == 'pdf') return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }
}
