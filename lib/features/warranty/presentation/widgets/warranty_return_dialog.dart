import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/warranty_model.dart';

bool canReceiveDeviceUnderWarranty(WarrantyModel warranty) =>
    !warranty.isArchived;

class WarrantyReturnFormData {
  final String problem;
  final String customerDescription;
  final String deviceCondition;
  final String employeeNotes;
  final List<String> imagePaths;

  const WarrantyReturnFormData({
    required this.problem,
    required this.customerDescription,
    required this.deviceCondition,
    required this.employeeNotes,
    required this.imagePaths,
  });
}

Future<WarrantyReturnFormData?> showWarrantyReturnDialog({
  required BuildContext context,
  required WarrantyModel warranty,
}) {
  return showDialog<WarrantyReturnFormData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WarrantyReturnDialog(warranty: warranty),
  );
}

class WarrantyReturnButton extends StatelessWidget {
  final WarrantyModel warranty;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  const WarrantyReturnButton({
    super.key,
    required this.warranty,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!canReceiveDeviceUnderWarranty(warranty)) {
      return const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      label: 'استلام الجوال تحت الضمان',
      child: SizedBox(
        width: compact ? 178 : double.infinity,
        height: 46,
        child: FilledButton.icon(
          key: ValueKey('receive-under-warranty-${warranty.id}'),
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.assignment_return_rounded, size: 20),
          label: Text(
            'استلام الجوال تحت الضمان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarrantyReturnDialog extends StatefulWidget {
  final WarrantyModel warranty;

  const _WarrantyReturnDialog({required this.warranty});

  @override
  State<_WarrantyReturnDialog> createState() => _WarrantyReturnDialogState();
}

class _WarrantyReturnDialogState extends State<_WarrantyReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _problem = TextEditingController();
  final _description = TextEditingController();
  final _condition = TextEditingController();
  final _notes = TextEditingController();
  final List<String> _images = [];

  @override
  void dispose() {
    _problem.dispose();
    _description.dispose();
    _condition.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    setState(() => _addUniqueImages(result.paths.whereType<String>()));
  }

  Future<void> _captureImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (file == null || !mounted) return;
      setState(() => _addUniqueImages([file.path]));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر فتح الكاميرا: $error',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _addUniqueImages(Iterable<String> paths) {
    for (final path in paths) {
      if (!_images.contains(path)) _images.add(path);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      WarrantyReturnFormData(
        problem: _problem.text.trim(),
        customerDescription: _description.text.trim(),
        deviceCondition: _condition.text.trim(),
        employeeNotes: _notes.text.trim(),
        imagePaths: List.unmodifiable(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final availableHeight = MediaQuery.sizeOf(context).height - 190;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        title: Row(
          children: [
            const Icon(
              Icons.assignment_return_rounded,
              color: AppColors.info,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'استلام الجوال تحت الضمان',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: availableHeight.clamp(330.0, 680.0),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.warranty.customerName ?? 'عميل غير محدد',
                            style: GoogleFonts.cairo(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.warranty.deviceInfo,
                            style: GoogleFonts.cairo(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ReturnTextField(
                      controller: _problem,
                      label: 'المشكلة الحالية',
                      requiredValue: true,
                      maxLines: 2,
                    ),
                    _ReturnTextField(
                      controller: _description,
                      label: 'وصف العميل',
                      maxLines: 2,
                    ),
                    _ReturnTextField(
                      controller: _condition,
                      label: 'حالة الجهاز عند العودة',
                      maxLines: 2,
                    ),
                    _ReturnTextField(
                      controller: _notes,
                      label: 'ملاحظات الموظف',
                      maxLines: 3,
                    ),
                    Text(
                      _images.isEmpty
                          ? 'صور العودة: لم تُضف صور'
                          : 'صور العودة: ${_images.length}',
                      style: GoogleFonts.cairo(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _captureImage,
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: Text(
                            'التقاط صورة',
                            style: GoogleFonts.cairo(),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: Text(
                            'اختيار صور',
                            style: GoogleFonts.cairo(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(
              'حفظ واستلامه تحت الضمان',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool requiredValue;
  final int maxLines;

  const _ReturnTextField({
    required this.controller,
    required this.label,
    this.requiredValue = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        style: GoogleFonts.cairo(),
        decoration: InputDecoration(
          labelText: requiredValue ? '$label *' : label,
          labelStyle: GoogleFonts.cairo(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: requiredValue
            ? (value) =>
                value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
            : null,
      ),
    );
  }
}
