import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/document_share_service.dart';
import '../../../../core/services/pdf_arabic_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/invoice_model.dart';
import '../../data/invoice_repository.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _repo = InvoiceRepository();
  final _searchCtrl = TextEditingController();
  List<InvoiceModel> _items = [];
  bool _loading = true;
  String? _status;
  String? _sentStatus;
  String? _warrantyStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.getAll(
      search: _searchCtrl.text,
      status: _status,
      sentStatus: _sentStatus,
      warrantyStatus: _warrantyStatus,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openPdf(InvoiceModel invoice) async {
    final path = invoice.pdfPath;
    if (path == null || !File(path).existsSync()) {
      _snack('ملف الفاتورة غير موجود. أعد إنشاءه من طلب الصيانة.', error: true);
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else {
        await Printing.sharePdf(
          bytes: await File(path).readAsBytes(),
          filename: invoice.fileName ?? 'invoice.pdf',
        );
      }
    } catch (e) {
      _snack('تعذر فتح الفاتورة: $e', error: true);
    }
  }

  Future<void> _printPdf(InvoiceModel invoice) async {
    final path = invoice.pdfPath;
    if (path == null || !File(path).existsSync()) {
      _snack('ملف الفاتورة غير موجود.', error: true);
      return;
    }
    await Printing.layoutPdf(
      name: invoice.fileName ?? invoice.invoiceNumber,
      onLayout: (_) => File(path).readAsBytes(),
    );
  }

  Future<void> _downloadPdf(InvoiceModel invoice) async {
    final path = invoice.pdfPath;
    if (path == null || !File(path).existsSync()) {
      _snack('ملف الفاتورة غير موجود.', error: true);
      return;
    }
    final savedPath = await DocumentShareService.savePdfToDownloads(
      filePath: path,
      fileName: invoice.fileName ?? '${invoice.invoiceNumber}.pdf',
    );
    if (savedPath == null) {
      _snack('تعذر حفظ الفاتورة في التنزيلات.', error: true);
      return;
    }
    _snack('تم حفظ الفاتورة في $savedPath');
  }

  Future<void> _sendWhatsApp(InvoiceModel invoice) async {
    try {
      final ok = await _repo.sendWhatsApp(invoice.id);
      _snack(ok ? 'تم فتح واتساب لإرسال الفاتورة' : 'تعذر فتح واتساب',
          error: !ok);
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchCtrl,
                      textDirection: TextDirection.rtl,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        labelText: 'بحث برقم الفاتورة، العميل، الجوال، IMEI',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _load,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _filter(
                    label: 'حالة الفاتورة',
                    value: _status,
                    items: AppConstants.invoiceStatusLabels,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(width: 10),
                  _filter(
                    label: 'الإرسال',
                    value: _sentStatus,
                    items: const {
                      'not_sent': 'لم ترسل',
                      'sent': 'مرسلة',
                      'failed': 'فشل الإرسال',
                    },
                    onChanged: (v) => setState(() => _sentStatus = v),
                  ),
                  const SizedBox(width: 10),
                  _filter(
                    label: 'الضمان',
                    value: _warrantyStatus,
                    items: const {
                      'active': 'ساري',
                      'expired': 'منتهي',
                      'pending': 'بانتظار البدء',
                      'none': 'بدون ضمان',
                    },
                    onChanged: (v) => setState(() => _warrantyStatus = v),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('تطبيق'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد فواتير محفوظة',
                              style: GoogleFonts.cairo(
                                  color: colors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final invoice = _items[index];
                              return _InvoiceCard(
                                invoice: invoice,
                                onOpen: () => _openPdf(invoice),
                                onDownload: () => _downloadPdf(invoice),
                                onPrint: () => _printPdf(invoice),
                                onSend: () => _sendWhatsApp(invoice),
                                onCustomer: () => context
                                    .push('/customers/${invoice.customerId}'),
                                onDevice: invoice.deviceId == null
                                    ? null
                                    : () => context
                                        .push('/devices/${invoice.deviceId}'),
                                onMaintenance: () => context.push(
                                    '/maintenance/${invoice.maintenanceId}'),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filter({
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String?>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('الكل'),
          ),
          ...items.entries.map(
            (entry) => DropdownMenuItem<String?>(
              value: entry.key,
              child: Text(entry.value),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onPrint;
  final VoidCallback onSend;
  final VoidCallback onCustomer;
  final VoidCallback? onDevice;
  final VoidCallback onMaintenance;

  const _InvoiceCard({
    required this.invoice,
    required this.onOpen,
    required this.onDownload,
    required this.onPrint,
    required this.onSend,
    required this.onCustomer,
    required this.onDevice,
    required this.onMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final warrantyColor = switch (invoice.warrantyStatus) {
      'active' => AppColors.success,
      'expired' => AppColors.error,
      'expired_approved' => AppColors.error,
      'pending' => AppColors.warning,
      _ => colors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(invoice.statusLabel, AppColors.primary),
                    const SizedBox(width: 6),
                    _chip(
                        _warrantyLabel(invoice.warrantyStatus), warrantyColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${invoice.customerName} - ${invoice.customerPhone} - ${invoice.deviceName}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  'التاريخ: ${PdfArabicUtils.dateTime(invoice.createdAt)} | الضمان: ${invoice.warrantyDays > 0 ? '${invoice.warrantyDays} يوم' : 'بدون ضمان'} | انتهاء: ${PdfArabicUtils.date(invoice.warrantyEnd)}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            invoice.total.toStringAsFixed(2),
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: AppColors.success,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 6,
            children: [
              IconButton(
                tooltip: 'عرض',
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_rounded),
              ),
              IconButton(
                tooltip: 'تنزيل',
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
              ),
              IconButton(
                tooltip: 'طباعة',
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded),
              ),
              IconButton(
                tooltip: 'إرسال واتساب',
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
              ),
              IconButton(
                tooltip: 'فتح العميل',
                onPressed: onCustomer,
                icon: const Icon(Icons.person_rounded),
              ),
              IconButton(
                tooltip: 'فتح الجهاز',
                onPressed: onDevice,
                icon: const Icon(Icons.phone_android_rounded),
              ),
              IconButton(
                tooltip: 'فتح الصيانة',
                onPressed: onMaintenance,
                icon: const Icon(Icons.build_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _warrantyLabel(String status) {
    switch (status) {
      case 'active':
        return 'ضمان ساري';
      case 'expired':
        return 'ضمان منتهي';
      case 'expired_approved':
        return 'انتهى الضمان';
      case 'pending':
        return 'ضمان لم يبدأ';
      default:
        return 'بدون ضمان';
    }
  }
}
