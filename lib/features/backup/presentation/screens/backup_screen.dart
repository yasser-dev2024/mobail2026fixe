import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = BackupService();
  List<Map<String, dynamic>> _logs = [];
  AutoBackupResult? _autoBackupResult;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final result = await _service.createAutomaticBackupIfDue();
      final logs = await _service.getBackupLogs();
      if (!mounted) return;
      setState(() {
        _autoBackupResult = result;
        _logs = logs;
        _busy = false;
      });
      if (result.created && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      final logs = await _service.getBackupLogs();
      if (!mounted) return;
      setState(() {
        _autoBackupResult = AutoBackupResult.failed(e.toString());
        _logs = logs;
        _busy = false;
      });
    }
  }

  Future<void> _loadLogs() async {
    final logs = await _service.getBackupLogs();
    if (!mounted) return;
    setState(() => _logs = logs);
  }

  Future<void> _createBackup() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد حفظ النسخة الاحتياطية',
    );
    if (directory == null) return;

    setState(() => _busy = true);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(
        directory, 'ProShop_Backup_$stamp${AppConstants.backupExtension}');
    final ok = await _service.createBackup(filePath);
    if (!mounted) return;
    setState(() => _busy = false);
    await _loadLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم إنشاء النسخة الاحتياطية'
              : (_service.lastError ?? 'تعذر إنشاء النسخة الاحتياطية'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      type: FileType.custom,
      allowedExtensions: ['shopbak', 'zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final confirm = await ConfirmDialog.show(
      context,
      title: 'استعادة نسخة احتياطية',
      message:
          'سيتم استبدال قاعدة البيانات والملفات الحالية بمحتوى النسخة. هل تريد المتابعة؟',
      confirmLabel: 'استعادة',
      confirmColor: AppColors.warning,
    );
    if (!confirm) return;

    setState(() => _busy = true);
    final ok = await _service.restoreBackup(path);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'تمت الاستعادة بنجاح. أعد تشغيل البرنامج.'
            : (_service.lastError ?? 'تعذرت الاستعادة')),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Map<String, dynamic>? get _latestAutoLog {
    for (final log in _logs) {
      if (log['type'] == 'auto' && log['status'] == 'success') {
        return log;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    final latestAuto = _latestAutoLog;
    return Scaffold(
      backgroundColor: colors.background,
      body: LoadingOverlay(
        isLoading: _busy,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'النسخ المسجلة',
                    value: '${_logs.length}',
                    icon: Icons.backup_rounded,
                    gradient: AppColors.primaryGradient,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: StatCard(
                    title: 'الحفظ المحلي',
                    value: 'Offline',
                    icon: Icons.folder_zip_rounded,
                    gradient: AppColors.tealGradient,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'النسخ والاستعادة'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.save_alt_rounded),
                        label: const Text('إنشاء نسخة احتياطية'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _restoreBackup,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('استعادة نسخة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'آخر نسخة تلقائية',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latestAuto == null
                              ? 'لا توجد نسخة تلقائية مسجلة بعد'
                              : formatter.format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    latestAuto['created_at'] as int,
                                  ),
                                ),
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_autoBackupResult != null)
                    Text(
                      _autoBackupResult!.message,
                      style: TextStyle(
                        color: _autoBackupResult!.failed
                            ? AppColors.error
                            : AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'سجل النسخ الاحتياطية'),
                  const SizedBox(height: 12),
                  if (_logs.isEmpty)
                    const EmptyState(
                        message: 'لا يوجد سجل نسخ بعد',
                        icon: Icons.history_rounded)
                  else
                    ..._logs.map((log) {
                      final created = DateTime.fromMillisecondsSinceEpoch(
                          log['created_at'] as int);
                      final size =
                          ((log['file_size'] as num?)?.toDouble() ?? 0) /
                              (1024 * 1024);
                      final type = log['type'] as String? ?? 'manual';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          type == 'auto'
                              ? Icons.auto_awesome_rounded
                              : Icons.archive_rounded,
                          color: type == 'auto'
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.basename(log['file_path'] as String? ?? ''),
                              ),
                            ),
                            _BackupTypeBadge(type: type),
                          ],
                        ),
                        subtitle: Text(log['file_path'] as String? ?? ''),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatter.format(created)),
                            Text('${size.toStringAsFixed(2)} MB'),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupTypeBadge extends StatelessWidget {
  final String type;

  const _BackupTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isAuto = type == 'auto';
    final color = isAuto ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isAuto ? 'تلقائي' : 'يدوي',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
