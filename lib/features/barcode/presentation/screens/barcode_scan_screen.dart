import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../maintenance/data/maintenance_repository.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _repo = MaintenanceRepository();
  final _db = DatabaseService();

  bool _scanning = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;

    setState(() {
      _scanning = true;
      _error = null;
      _result = null;
    });

    try {
      final shopId = await _db.getCurrentShopId();
      final rows = await _db.rawQuery('''
SELECT m.*,
       c.name  AS customer_name,
       c.phone AS customer_phone,
       u.name  AS technician_name
FROM maintenance m
LEFT JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
LEFT JOIN users    u ON m.technician_id = u.id
WHERE m.shop_id = ? AND (m.ticket_number = ? OR m.id = ?) AND m.deleted_at IS NULL
LIMIT 1
''', [shopId, code, code]);

      if (rows.isEmpty) {
        setState(() {
          _error = 'لم يتم العثور على جهاز بهذا الرمز:\n$code';
          _scanning = false;
        });
        _scanCtrl.clear();
        _scanFocus.requestFocus();
        return;
      }

      final row = Map<String, dynamic>.from(rows.first);

      // Log the scan to audit trail
      try {
        await _repo.logAudit(
          maintenanceId: row['id'] as String,
          action: 'مسح الباركود',
          newValue: code,
        );
      } catch (_) {}

      setState(() {
        _result = row;
        _scanning = false;
      });

      // Auto-show delivery dialog if device is ready
      final status = row['status'] as String? ?? '';
      if (status == AppConstants.statusReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showDeliveryDialog(row);
        });
      }
    } catch (_) {
      setState(() {
        _error = 'حدث خطأ في البحث، يرجى المحاولة مجدداً';
        _scanning = false;
      });
    }

    _scanCtrl.clear();
    _scanFocus.requestFocus();
  }

  // ── Delivery ───────────────────────────────────────────────────────────────

  void _showDeliveryDialog(Map<String, dynamic> row) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeliveryDialog(
        row: row,
        onDeliver: () async {
          Navigator.pop(ctx);
          await _deliverDevice(row);
        },
      ),
    );
  }

  Future<void> _deliverDevice(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final ticketNumber = (row['ticket_number'] as String?) ?? '';

    try {
      await _repo.updateStatus(id, AppConstants.statusDelivered);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسليم الجهاز بنجاح ✓', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );

      // Refresh the scan result
      final ticketOrId = ticketNumber.isNotEmpty ? ticketNumber : id;
      await _processBarcode(ticketOrId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في عملية التسليم، يرجى المحاولة مجدداً',
                style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Quick status change ────────────────────────────────────────────────────

  Future<void> _quickStatusChange(
      Map<String, dynamic> row, String newStatus) async {
    final id = row['id'] as String;
    final ticketNumber = (row['ticket_number'] as String?) ?? '';

    try {
      await _repo.updateStatus(id, newStatus);

      // Refresh result
      final ticketOrId = ticketNumber.isNotEmpty ? ticketNumber : id;
      await _processBarcode(ticketOrId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // ── Scanner input bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            color: colors.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'مسح الباركود',
                      style: GoogleFonts.cairo(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (_scanning)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _scanCtrl,
                  focusNode: _scanFocus,
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.robotoMono(fontSize: 15),
                  onSubmitted: _processBarcode,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'امسح الباركود أو اكتب رقم الطلب...',
                    hintStyle: GoogleFonts.cairo(fontSize: 14),
                    prefixIcon: const Icon(Icons.qr_code_rounded,
                        color: AppColors.primary, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_scanCtrl.text.isNotEmpty)
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _scanCtrl.clear();
                              _scanFocus.requestFocus();
                              setState(() {
                                _result = null;
                                _error = null;
                              });
                            },
                          ),
                        IconButton(
                          iconSize: 18,
                          icon: const Icon(Icons.search_rounded,
                              color: AppColors.primary),
                          onPressed: () => _processBarcode(_scanCtrl.text),
                          tooltip: 'بحث',
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: colors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'وجّه قارئ الباركود USB نحو ملصق الجهاز — يعمل تلقائياً',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Result / Empty / Error ─────────────────────────────────────────
          Expanded(
            child: _error != null
                ? _ErrorView(message: _error!)
                : _result == null
                    ? _EmptyView()
                    : _ResultView(
                        row: _result!,
                        onNavigate: () =>
                            context.go('/maintenance/${_result!['id']}'),
                        onStatusChange: (s) => _quickStatusChange(_result!, s),
                        onDeliver: () => _showDeliveryDialog(_result!),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery dialog — shown automatically when a "ready" device is scanned
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryDialog extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDeliver;

  const _DeliveryDialog({required this.row, required this.onDeliver});

  @override
  Widget build(BuildContext context) {
    final customerName = (row['customer_name'] as String?) ?? 'العميل';
    final phone = (row['customer_phone'] as String?) ?? '';
    final brand = (row['brand'] as String?) ?? '';
    final model = (row['model'] as String?) ?? '';
    final ticketNumber = (row['ticket_number'] as String?) ?? '';
    final totalCost = (row['total_cost'] as num?)?.toDouble() ?? 0.0;
    final advancePaid = (row['advance_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = totalCost - advancePaid;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: AppColors.success.withValues(alpha: 0.4), width: 2),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: AppColors.success),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(0.94, 0.94),
                end: const Offset(1.06, 1.06),
                duration: 800.ms),
            const SizedBox(height: 14),
            Text(
              'هذا الجهاز جاهز للتسليم',
              style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _dlgRow(Icons.person_rounded, 'العميل', customerName),
            if (phone.isNotEmpty) _dlgRow(Icons.phone_rounded, 'الجوال', phone),
            _dlgRow(Icons.phone_android_rounded, 'الجهاز', '$brand $model'),
            _dlgRow(
                Icons.confirmation_number_rounded, 'رقم الطلب', ticketNumber),
            if (remaining > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payment_rounded,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('المبلغ المتبقي:',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning)),
                    const Spacer(),
                    Text(
                      '${remaining.toStringAsFixed(2)} ر.س',
                      style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إغلاق', style: GoogleFonts.cairo()),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          onPressed: onDeliver,
          icon: const Icon(Icons.check_rounded),
          label: Text('تسليم الجهاز',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _dlgRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.cairo(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan result card
// ─────────────────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onNavigate;
  final void Function(String) onStatusChange;
  final VoidCallback onDeliver;

  const _ResultView({
    required this.row,
    required this.onNavigate,
    required this.onStatusChange,
    required this.onDeliver,
  });

  static const _quickStatuses = [
    _SQ(AppConstants.statusWaitingInspection, 'بانتظار الفحص',
        AppColors.statusWaitingInspection),
    _SQ(AppConstants.statusInspecting, 'قيد الفحص', AppColors.statusInspecting),
    _SQ(AppConstants.statusFaultIdentified, 'تم تحديد العطل',
        AppColors.statusFaultIdentified),
    _SQ(AppConstants.statusWaitingCustomerApproval, 'موافقة العميل',
        AppColors.statusWaitingCustomerApproval),
    _SQ(AppConstants.statusWaitingPart, 'بانتظار قطعة',
        AppColors.statusWaitingPart),
    _SQ(AppConstants.statusRepairing, 'قيد الإصلاح', AppColors.statusRepairing),
    _SQ(AppConstants.statusUnderTesting, 'تحت الاختبار',
        AppColors.statusUnderTesting),
    _SQ(AppConstants.statusRepaired, 'تم الإصلاح', AppColors.statusRepaired),
    _SQ(AppConstants.statusReady, 'جاهز للتسليم', AppColors.statusReady),
  ];

  String _statusLabel(String s) {
    return AppConstants.maintenanceStatusLabel(s);
  }

  Color _statusColor(String s) {
    return AppColors.maintenanceStatus(s);
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = (row['status'] as String?) ?? '';
    final customerName = (row['customer_name'] as String?) ?? '';
    final phone = (row['customer_phone'] as String?) ?? '';
    final brand = (row['brand'] as String?) ?? '';
    final model = (row['model'] as String?) ?? '';
    final ticketNumber = (row['ticket_number'] as String?) ?? '';
    final techName = row['technician_name'] as String?;
    final faultDesc = (row['fault_description'] as String?) ?? '';
    final updatedAt = row['updated_at'] as int?;
    final totalCost = (row['total_cost'] as num?)?.toDouble() ?? 0.0;
    final advancePaid = (row['advance_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = totalCost - advancePaid;
    final sc = _statusColor(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status header with QR ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: sc.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                // QR code thumbnail
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: QrImageView(
                    data: ticketNumber,
                    version: QrVersions.auto,
                    size: 90,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticketNumber,
                        style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: sc,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                      ),
                      if (updatedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'آخر تحديث: ${_fmt(updatedAt)}',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Device & customer info ────────────────────────────────────────
          _Card(
            colors: colors,
            title: 'بيانات الجهاز والعميل',
            children: [
              _Row(Icons.person_rounded, 'العميل', customerName, colors),
              if (phone.isNotEmpty)
                _Row(Icons.phone_rounded, 'الجوال', phone, colors),
              _Row(Icons.phone_android_rounded, 'الجهاز', '$brand $model',
                  colors),
              _Row(Icons.report_problem_rounded, 'العطل', faultDesc, colors),
              if (techName != null)
                _Row(Icons.engineering_rounded, 'الفني', techName, colors),
              if (remaining > 0)
                _Row(Icons.payment_rounded, 'المتبقي',
                    '${remaining.toStringAsFixed(2)} ر.س', colors,
                    valueColor: AppColors.warning),
            ],
          ),

          const SizedBox(height: 14),

          // ── Quick status change ───────────────────────────────────────────
          if (status != AppConstants.statusDelivered &&
              status != AppConstants.statusCancelled)
            _Card(
              colors: colors,
              title: 'تغيير الحالة',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickStatuses
                      .where((s) => s.value != status)
                      .map((s) => ActionChip(
                            avatar: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: s.color, shape: BoxShape.circle),
                            ),
                            label: Text(s.label,
                                style: GoogleFonts.cairo(fontSize: 12)),
                            onPressed: () => onStatusChange(s.value),
                          ))
                      .toList(),
                ),
              ],
            ),

          const SizedBox(height: 14),

          // ── Action buttons ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('فتح سجل الصيانة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                ),
              ),
              if (status == AppConstants.statusReady) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onDeliver,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text('تسليم الجهاز',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SQ {
  final String value;
  final String label;
  final Color color;
  const _SQ(this.value, this.label, this.color);
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final dynamic colors;

  const _Card(
      {required this.title, required this.children, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final dynamic colors;
  final Color? valueColor;

  const _Row(this.icon, this.label, this.value, this.colors, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                  fontSize: 13)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: valueColor ?? c.textPrimary,
                    fontWeight:
                        valueColor != null ? FontWeight.w700 : FontWeight.w400),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner_rounded,
                  size: 90, color: colors.textSecondary.withValues(alpha: 0.25))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.4, end: 1.0, duration: 1600.ms),
          const SizedBox(height: 22),
          Text('جاهز للمسح',
              style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary)),
          const SizedBox(height: 8),
          Text('امسح باركود جهاز أو اكتب رقم الطلب يدوياً',
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: colors.textSecondary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                style: GoogleFonts.cairo(fontSize: 15, color: AppColors.error),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
