import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/services/document_share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../../barcode/services/label_print_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../notifications/data/notification_model.dart';
import '../../../notifications/data/notifications_repository.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../whatsapp/data/whatsapp_message_model.dart';
import '../../../whatsapp/data/whatsapp_repository.dart';
import '../../../warranty/data/warranty_claim_model.dart';
import '../../../warranty/data/warranty_repository.dart';
import '../../../invoices/data/invoice_model.dart';
import '../../../invoices/data/invoice_repository.dart';
import '../../../device_reports/data/device_report_model.dart';
import '../../../device_reports/data/device_report_repository.dart';
import '../../data/maintenance_model.dart';
import '../../data/maintenance_part_model.dart';
import '../../data/maintenance_image_model.dart';
import '../../data/maintenance_repository.dart';
import '../cubit/maintenance_cubit.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  final String maintenanceId;
  final bool justCreated;
  const MaintenanceDetailScreen({
    super.key,
    required this.maintenanceId,
    this.justCreated = false,
  });

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _imageTabController;
  final _repo = MaintenanceRepository();
  final _whatsappRepo = WhatsappRepository();
  List<NotificationModel> _linkedNotifications = [];
  List<WhatsappMessageModel> _whatsappMessages = [];
  WhatsappMessageModel? _currentWhatsappMessage;
  List<Map<String, dynamic>> _statusHistory = [];
  Map<String, dynamic>? _intakeChecklist;
  Map<String, dynamic>? _finalChecklist;
  Map<String, dynamic>? _approval;
  InvoiceModel? _latestInvoice;
  DeviceReportModel? _latestReport;
  String? _customerPhone;
  bool _loadingWhatsapp = false;
  bool _documentBusy = false;
  bool _printPromptShown = false;

  @override
  void initState() {
    super.initState();
    _imageTabController = TabController(length: 3, vsync: this);
    context.read<MaintenanceCubit>().loadById(widget.maintenanceId);
    _loadLinkedNotifications();
    _loadCustomerPhone();
    _loadWorkflowExtensions();
    _loadWhatsappMessages();
  }

  Future<void> _loadLinkedNotifications() async {
    try {
      final notifs = await NotificationsRepository()
          .getForMaintenance(widget.maintenanceId);
      if (mounted) setState(() => _linkedNotifications = notifs);
    } catch (_) {}
  }

  Future<void> _loadCustomerPhone() async {
    try {
      final db = DatabaseService();
      final shopId = await db.getCurrentShopId();
      final rows = await db.rawQuery('''
SELECT c.phone
FROM maintenance m
JOIN customers c ON m.customer_id = c.id AND c.shop_id = m.shop_id
WHERE m.shop_id = ? AND m.id = ? LIMIT 1
''', [shopId, widget.maintenanceId]);
      if (mounted && rows.isNotEmpty) {
        setState(() => _customerPhone = rows.first['phone'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _loadWorkflowExtensions() async {
    try {
      final history = await _repo.getStatusHistory(widget.maintenanceId);
      final intake = await _repo.getChecklist(widget.maintenanceId, 'intake');
      final finalTest = await _repo.getChecklist(widget.maintenanceId, 'final');
      final approval = await _repo.getCustomerApproval(widget.maintenanceId);
      final invoice =
          await InvoiceRepository().getByMaintenance(widget.maintenanceId);
      final reports = await DeviceReportRepository()
          .getForMaintenance(widget.maintenanceId);
      if (!mounted) return;
      setState(() {
        _statusHistory = history;
        _intakeChecklist = intake;
        _finalChecklist = finalTest;
        _approval = approval;
        _latestInvoice = invoice;
        _latestReport = reports.isEmpty ? null : reports.first;
      });
    } catch (_) {}
  }

  Future<void> _loadWhatsappMessages() async {
    if (mounted) setState(() => _loadingWhatsapp = true);
    try {
      final current = await _whatsappRepo
          .ensureCurrentMaintenanceMessage(widget.maintenanceId);
      final messages =
          await _whatsappRepo.getMessagesForMaintenance(widget.maintenanceId);
      if (!mounted) return;
      setState(() {
        _currentWhatsappMessage = current;
        _whatsappMessages = messages;
        _loadingWhatsapp = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWhatsapp = false);
    }
  }

  @override
  void dispose() {
    _imageTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MaintenanceCubit, MaintenanceState>(
      listener: (context, state) {
        if (state is MaintenanceSingleLoaded &&
            widget.justCreated &&
            !_printPromptShown) {
          _printPromptShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showPrintLabelPrompt(state.maintenance);
          });
        }
        if (state is MaintenanceStatusUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث الحالة', style: GoogleFonts.cairo()),
              backgroundColor: AppColors.success,
            ),
          );
          context.read<NotificationsCubit>().loadNotifications();
          context.read<MaintenanceCubit>().loadById(widget.maintenanceId);
          _loadWorkflowExtensions();
          _loadWhatsappMessages();
        }
        if (state is MaintenanceDeleted) {
          context.go('/maintenance');
        }
        if (state is MaintenanceError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is MaintenanceLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is MaintenanceError) {
          return Scaffold(
            appBar: AppBar(title: Text('خطأ', style: GoogleFonts.cairo())),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 56, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(state.message, style: GoogleFonts.cairo()),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<MaintenanceCubit>()
                        .loadById(widget.maintenanceId),
                    child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is! MaintenanceSingleLoaded) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final m = state.maintenance;
        final parts = state.parts;
        final images = state.images;

        return Scaffold(
          backgroundColor: context.appColors.background,
          appBar: AppBar(
            title: Text(m.ticketNumber,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              onPressed: () => context.go('/maintenance'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'تعديل',
                onPressed: () => context.go('/maintenance/${m.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                tooltip: 'حذف',
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header card ────────────────────────────────────────────────
              _SectionCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.ticketNumber,
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fmt(m.receivedAt),
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: context.appColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        _StageBadge(status: m.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildJourneyProgress(m),
                    if (m.estimatedDelivery != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14,
                              color: m.isOverdue
                                  ? AppColors.error
                                  : context.appColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'الموعد المتوقع: ${_fmt(m.estimatedDelivery!)}',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: m.isOverdue
                                    ? AppColors.error
                                    : context.appColors.textSecondary,
                                fontWeight: m.isOverdue
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (m.isOverdue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('متأخر',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (m.deliveredAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'تاريخ التسليم: ${_fmt(m.deliveredAt!)}',
                              style: GoogleFonts.cairo(
                                  fontSize: 12, color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── QR code & label printing ───────────────────────────────────
              _SectionCard(
                title: 'الباركود والطباعة',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final qr = Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.appColors.border),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: QrImageView(
                        data: m.ticketNumber,
                        version: QrVersions.auto,
                        size: constraints.maxWidth < 360 ? 96 : 110,
                      ),
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.ticketNumber,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.brand} ${m.model}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: context.appColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: constraints.maxWidth < 420
                              ? double.infinity
                              : null,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _printLabel(m),
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: Text('طباعة الملصق',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    );

                    if (constraints.maxWidth < 420) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: qr,
                          ),
                          const SizedBox(height: 12),
                          details,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        qr,
                        const SizedBox(width: 16),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Customer & Device ──────────────────────────────────────────
              _SectionCard(
                title: 'بيانات العميل والجهاز',
                child: Column(
                  children: [
                    _InfoRow(
                        icon: Icons.person_rounded,
                        label: 'العميل',
                        value: m.customerName ?? 'غير محدد'),
                    if ((m.customerPhone ?? _customerPhone ?? '').isNotEmpty)
                      _InfoRow(
                          icon: Icons.phone_rounded,
                          label: 'الجوال',
                          value: (m.customerPhone ?? _customerPhone)!),
                    _InfoRow(
                        icon: Icons.phone_android_rounded,
                        label: 'الجهاز',
                        value: '${m.brand} ${m.model}'),
                    _InfoRow(
                        icon: Icons.hourglass_top_rounded,
                        label: 'منذ الاستلام',
                        value: _elapsedSince(m.receivedAt)),
                    if (m.imei != null)
                      _InfoRow(
                          icon: Icons.numbers_rounded,
                          label: 'IMEI',
                          value: m.imei!),
                    if (m.color != null)
                      _InfoRow(
                          icon: Icons.color_lens_rounded,
                          label: 'اللون',
                          value: m.color!),
                    if (m.technicianName != null)
                      _InfoRow(
                          icon: Icons.engineering_rounded,
                          label: 'الفني',
                          value: m.technicianName!),
                    const Divider(height: 20),
                    _InfoRow(
                        icon: Icons.report_problem_rounded,
                        label: 'المشكلة',
                        value: m.faultDescription),
                    if (m.notes != null && m.notes!.isNotEmpty)
                      _InfoRow(
                          icon: Icons.notes_rounded,
                          label: 'ملاحظات',
                          value: m.notes!),
                    if (m.internalNotes != null && m.internalNotes!.isNotEmpty)
                      _InfoRow(
                          icon: Icons.lock_rounded,
                          label: 'ملاحظات داخلية',
                          value: m.internalNotes!),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Cost breakdown ─────────────────────────────────────────────
              _SectionCard(
                title: 'تفاصيل التكلفة',
                child: Column(
                  children: [
                    _CostRow(label: 'أجرة الصيانة', amount: m.laborCost),
                    _CostRow(label: 'تكلفة القطع', amount: m.partsCost),
                    const Divider(),
                    _CostRow(
                        label: 'الإجمالي', amount: m.totalCost, bold: true),
                    _CostRow(
                        label: 'مدفوع مقدماً',
                        amount: m.advancePaid,
                        color: AppColors.success),
                    _CostRow(
                        label: 'المتبقي',
                        amount: m.remainingAmount,
                        bold: true,
                        color: m.remainingAmount > 0
                            ? AppColors.error
                            : AppColors.success),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _buildInvoiceAndReportCard(m),

              const SizedBox(height: 12),

              _buildWorkflowCard(m),

              const SizedBox(height: 12),

              // ── Parts used ────────────────────────────────────────────────
              _SectionCard(
                title: 'القطع المستخدمة',
                trailing: IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  onPressed: () => _showAddPartDialog(context, m.id),
                ),
                child: parts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('لا توجد قطع مضافة',
                              style: GoogleFonts.cairo(
                                  color: context.appColors.textSecondary)),
                        ),
                      )
                    : Column(
                        children: [
                          ...parts.map((p) => _PartRow(
                                part: p,
                                onRemove: () => context
                                    .read<MaintenanceCubit>()
                                    .removePart(p.id, m.id),
                              )),
                          // Profit summary — only show when at least one part
                          // has cost data from inventory.
                          if (parts.any((p) => p.hasCostData)) ...[
                            const Divider(height: 20),
                            _PartsProfitSummary(parts: parts),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 12),

              // ── Images ────────────────────────────────────────────────────
              _SectionCard(
                title: 'الصور',
                trailing: TextButton.icon(
                  onPressed: () => _imageTabController.animateTo(0),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    'صور الجهاز قبل الصيانة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                  ),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _imageTabController,
                      tabs: const [
                        Tab(text: 'قبل'),
                        Tab(text: 'أثناء'),
                        Tab(text: 'بعد'),
                      ],
                    ),
                    SizedBox(
                      height: 200,
                      child: TabBarView(
                        controller: _imageTabController,
                        children: [
                          _ImageGrid(
                              images: images
                                  .where((i) => i.imageType == 'before')
                                  .toList()),
                          _ImageGrid(
                              images: images
                                  .where((i) => i.imageType == 'during')
                                  .toList()),
                          _ImageGrid(
                              images: images
                                  .where((i) => i.imageType == 'after')
                                  .toList()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Warranty info ─────────────────────────────────────────────
              if (m.warrantyType != null &&
                  m.warrantyType != AppConstants.warrantyNone) ...[
                _SectionCard(
                  title: 'معلومات الضمان',
                  child: Column(
                    children: [
                      _InfoRow(
                          icon: Icons.verified_user_rounded,
                          label: 'نوع الضمان',
                          value: _warrantyLabel(m.warrantyType!)),
                      if (m.warrantyDays != null)
                        _InfoRow(
                            icon: Icons.calendar_month_rounded,
                            label: 'مدة الضمان',
                            value: '${m.warrantyDays} يوم'),
                      if (m.warrantyStart != null)
                        _InfoRow(
                            icon: Icons.play_arrow_rounded,
                            label: 'بداية الضمان',
                            value: _dualDate(m.warrantyStart!)),
                      if (m.warrantyEnd != null)
                        _InfoRow(
                            icon: Icons.stop_rounded,
                            label: 'نهاية الضمان',
                            value: _dualDate(m.warrantyEnd!)),
                      if (m.warrantyEnd != null)
                        _InfoRow(
                            icon: Icons.hourglass_bottom_rounded,
                            label: 'المتبقي',
                            value: _remainingWarranty(m.warrantyEnd!)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Notifications ─────────────────────────────────────────────
              _SectionCard(
                title: 'التنبيهات',
                trailing: IconButton(
                  icon: const Icon(Icons.add_alert_rounded,
                      color: AppColors.primary),
                  tooltip: 'إضافة تنبيه',
                  onPressed: () => _showAddNotificationDialog(context, m),
                ),
                child: _linkedNotifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'لا توجد تنبيهات لهذا الجهاز',
                            style: GoogleFonts.cairo(
                                color: context.appColors.textSecondary,
                                fontSize: 13),
                          ),
                        ),
                      )
                    : Column(
                        children: _linkedNotifications
                            .map((n) => _NotifRow(n: n))
                            .toList(),
                      ),
              ),

              const SizedBox(height: 12),

              _buildWhatsappSection(),

              const SizedBox(height: 12),

              _buildPrimaryStageAction(m),

              const SizedBox(height: 12),

              // ── Action buttons ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _printReceipt(m),
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: Text('طباعة الإيصال',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _printDelivery(m),
                      icon: const Icon(Icons.assignment_returned_rounded,
                          size: 18),
                      label: Text('طباعة التسليم',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_currentWhatsappMessage != null)
                _buildWhatsappButton(_currentWhatsappMessage!),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }

  String _elapsedSince(int ms) {
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    return '${diff.inMinutes.clamp(0, 59)} دقيقة';
  }

  Widget _buildInvoiceAndReportCard(MaintenanceModel m) {
    final colors = context.appColors;
    final invoice = _latestInvoice;
    final report = _latestReport;
    return _SectionCard(
      title: 'الفواتير والضمانات والتقارير المصورة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_documentBusy) const LinearProgressIndicator(minHeight: 2),
          if (_documentBusy) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DocSummaryTile(
                  icon: Icons.receipt_long_rounded,
                  title: invoice?.invoiceNumber ?? 'لم تنشأ فاتورة بعد',
                  subtitle: invoice == null
                      ? 'ينشئ PDF رسميًا مع الضمان وشروطه'
                      : '${invoice.statusLabel} - ${invoice.total.toStringAsFixed(2)} ر.س',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DocSummaryTile(
                  icon: Icons.photo_library_rounded,
                  title: report?.reportNumber ?? 'لم ينشأ تقرير مصور بعد',
                  subtitle: report == null
                      ? 'تقرير عربي يحفظ صور حالة الجهاز'
                      : report.title,
                  color: AppColors.success,
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
                onPressed: _documentBusy ? null : () => _createInvoice(m),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  invoice == null ? 'إنشاء فاتورة PDF' : 'إعادة إنشاء PDF',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: invoice?.pdfPath == null
                    ? null
                    : () => _openDocument(invoice!.pdfPath!),
                icon: const Icon(Icons.visibility_rounded),
                label: Text('عرض الفاتورة', style: GoogleFonts.cairo()),
              ),
              OutlinedButton.icon(
                onPressed: invoice?.pdfPath == null
                    ? null
                    : () => _downloadDocument(
                          invoice!.pdfPath!,
                          invoice.fileName,
                        ),
                icon: const Icon(Icons.download_rounded),
                label: Text('تنزيل الفاتورة', style: GoogleFonts.cairo()),
              ),
              OutlinedButton.icon(
                onPressed: invoice?.pdfPath == null
                    ? null
                    : () => _printDocument(invoice!.pdfPath!, invoice.fileName),
                icon: const Icon(Icons.print_rounded),
                label: Text('طباعة الفاتورة', style: GoogleFonts.cairo()),
              ),
              OutlinedButton.icon(
                onPressed: invoice == null ? null : () => _sendInvoice(invoice),
                icon: const Icon(Icons.send_rounded),
                label: Text('إرسال الفاتورة', style: GoogleFonts.cairo()),
              ),
              TextButton.icon(
                onPressed: () => context.go('/invoices'),
                icon: const Icon(Icons.list_alt_rounded),
                label: Text('سجل الفواتير', style: GoogleFonts.cairo()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.border),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _documentBusy ? null : () => _createDeviceReport(m),
                icon: const Icon(Icons.collections_rounded),
                label: Text(
                  report == null
                      ? 'إنشاء تقرير مصور'
                      : 'إنشاء إصدار تقرير جديد',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: report?.pdfPath == null
                    ? null
                    : () => _openDocument(report!.pdfPath!),
                icon: const Icon(Icons.visibility_rounded),
                label: Text('عرض التقرير', style: GoogleFonts.cairo()),
              ),
              OutlinedButton.icon(
                onPressed: report?.pdfPath == null
                    ? null
                    : () => _downloadDocument(
                          report!.pdfPath!,
                          report.fileName,
                        ),
                icon: const Icon(Icons.download_rounded),
                label: Text('تنزيل التقرير', style: GoogleFonts.cairo()),
              ),
              OutlinedButton.icon(
                onPressed: report?.pdfPath == null
                    ? null
                    : () => _printDocument(report!.pdfPath!, report.fileName),
                icon: const Icon(Icons.print_rounded),
                label: Text('طباعة التقرير', style: GoogleFonts.cairo()),
              ),
              OutlinedButton.icon(
                onPressed: report == null ? null : () => _sendReport(report),
                icon: const Icon(Icons.send_rounded),
                label: Text('إرسال التقرير', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createInvoice(MaintenanceModel m) async {
    setState(() => _documentBusy = true);
    try {
      final invoice =
          await InvoiceRepository().createOrRegenerateForMaintenance(m.id);
      if (!mounted) return;
      setState(() => _latestInvoice = invoice);
      _showMessage('تم إنشاء فاتورة PDF');
      if (invoice.pdfPath != null) await _openDocument(invoice.pdfPath!);
    } catch (e) {
      _showMessage('تعذر إنشاء الفاتورة: $e', error: true);
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  Future<void> _createDeviceReport(MaintenanceModel m) async {
    setState(() => _documentBusy = true);
    try {
      final report = await DeviceReportRepository().createForMaintenance(m.id);
      if (!mounted) return;
      setState(() => _latestReport = report);
      _showMessage('تم إنشاء التقرير المصور');
      if (report.pdfPath != null) await _openDocument(report.pdfPath!);
    } catch (e) {
      _showMessage('تعذر إنشاء التقرير: $e', error: true);
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  Future<void> _sendInvoice(InvoiceModel invoice) async {
    setState(() => _documentBusy = true);
    try {
      final ok = await InvoiceRepository().sendWhatsApp(invoice.id);
      _showMessage(ok ? 'تم فتح واتساب لإرسال الفاتورة' : 'تعذر فتح واتساب',
          error: !ok);
      await _loadWorkflowExtensions();
    } catch (e) {
      _showMessage('تعذر إرسال الفاتورة: $e', error: true);
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  Future<void> _sendReport(DeviceReportModel report) async {
    setState(() => _documentBusy = true);
    try {
      final ok = await DeviceReportRepository().sendWhatsApp(report.id);
      _showMessage(ok ? 'تم فتح واتساب لإرسال التقرير' : 'تعذر فتح واتساب',
          error: !ok);
      await _loadWorkflowExtensions();
    } catch (e) {
      _showMessage('تعذر إرسال التقرير: $e', error: true);
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  Future<void> _openDocument(String path) async {
    if (!File(path).existsSync()) {
      _showMessage('ملف PDF غير موجود', error: true);
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else {
        await Printing.sharePdf(
          bytes: await File(path).readAsBytes(),
          filename: path.split(Platform.pathSeparator).last,
        );
      }
    } catch (e) {
      _showMessage('تعذر فتح الملف: $e', error: true);
    }
  }

  Future<void> _downloadDocument(String path, String? name) async {
    if (!File(path).existsSync()) {
      _showMessage('ملف PDF غير موجود', error: true);
      return;
    }
    final savedPath = await DocumentShareService.savePdfToDownloads(
      filePath: path,
      fileName: name,
    );
    if (savedPath == null) {
      _showMessage('تعذر حفظ ملف PDF في التنزيلات', error: true);
      return;
    }
    _showMessage('تم حفظ ملف PDF في $savedPath');
  }

  Future<void> _printDocument(String path, String? name) async {
    if (!File(path).existsSync()) {
      _showMessage('ملف PDF غير موجود', error: true);
      return;
    }
    await Printing.layoutPdf(
      name: name ?? 'document.pdf',
      onLayout: (_) => File(path).readAsBytes(),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Widget _buildJourneyProgress(MaintenanceModel m) {
    final colors = context.appColors;
    final currentIndex = AppConstants.maintenanceStageIndex(m.status);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: List.generate(
            AppConstants.visibleMaintenanceStageLabels.length, (index) {
          final active = index == currentIndex;
          final label = AppConstants.visibleMaintenanceStageLabels[index];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 104),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? AppColors.primary : colors.border,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primary : colors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (index < AppConstants.visibleMaintenanceStageLabels.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: active ? AppColors.primary : colors.textSecondary,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  String _dualDate(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return 'م ${_fmt(ms)} | هـ ${HijriDate.fromGregorian(date).format()}';
  }

  String _remainingWarranty(int endMs) {
    final now = DateTime.now();
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final days = endDay.difference(today).inDays;
    if (days > 0) return '$days يوم';
    if (days == 0) return 'ينتهي اليوم';
    return 'منتهي منذ ${days.abs()} يوم';
  }

  String _warrantyLabel(String type) {
    switch (type) {
      case AppConstants.warranty7Days:
        return '7 أيام';
      case AppConstants.warranty30Days:
        return '30 يوم';
      case AppConstants.warranty90Days:
        return '90 يوم';
      case AppConstants.warranty6Months:
        return '6 أشهر';
      case AppConstants.warranty1Year:
        return 'سنة';
      case AppConstants.warranty2Years:
        return 'سنتين';
      case AppConstants.warrantyCustom:
        return 'مخصص';
      default:
        return 'بدون ضمان';
    }
  }

  Widget _buildPrimaryStageAction(MaintenanceModel m) {
    final label = _primaryActionLabel(m);
    if (label == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          if (AppConstants.waitingMaintenanceStatuses.contains(m.status)) {
            _showRepairResultDialog(m);
          } else if (AppConstants.readyForCustomerStatuses.contains(m.status)) {
            _showDeliveryConfirmDialog(m);
          } else if (_canOpenWarrantyClaim(m)) {
            _showWarrantyClaimDialog(m);
          }
        },
        icon: Icon(_primaryActionIcon(m), size: 18),
        label: Text(
          label,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String? _primaryActionLabel(MaintenanceModel m) {
    if (AppConstants.waitingMaintenanceStatuses.contains(m.status)) {
      return 'تحديث نتيجة الصيانة';
    }
    if (AppConstants.readyForCustomerStatuses.contains(m.status)) {
      return 'تسليم الجهاز للعميل';
    }
    if (_canOpenWarrantyClaim(m)) {
      return 'فتح طلب ضمان';
    }
    return null;
  }

  IconData _primaryActionIcon(MaintenanceModel m) {
    if (AppConstants.waitingMaintenanceStatuses.contains(m.status)) {
      return Icons.build_circle_rounded;
    }
    if (AppConstants.readyForCustomerStatuses.contains(m.status)) {
      return Icons.assignment_turned_in_rounded;
    }
    return Icons.verified_user_rounded;
  }

  bool _canOpenWarrantyClaim(MaintenanceModel m) {
    if (m.status != AppConstants.statusDelivered) return false;
    if (m.warrantyType == null || m.warrantyType == AppConstants.warrantyNone) {
      return false;
    }
    if (m.warrantyEnd == null) return false;
    return DateTime.now().millisecondsSinceEpoch <= m.warrantyEnd!;
  }

  Future<void> _showRepairResultDialog(MaintenanceModel m) async {
    var repaired = true;
    final repairCtrl = TextEditingController();
    final partCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final costCtrl =
        TextEditingController(text: m.laborCost.toStringAsFixed(0));
    final warrantyDaysCtrl =
        TextEditingController(text: (m.warrantyDays ?? 30).toString());
    String warrantyType =
        m.warrantyType == null || m.warrantyType == AppConstants.warrantyNone
            ? AppConstants.warranty30Days
            : m.warrantyType!;
    var openedDevice = false;
    var changedAnyPart = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'تحديث نتيجة الصيانة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('تمت الصيانة'),
                        icon: Icon(Icons.check_circle_rounded),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('تعذر الإصلاح'),
                        icon: Icon(Icons.error_rounded),
                      ),
                    ],
                    selected: {repaired},
                    onSelectionChanged: (value) =>
                        setDialogState(() => repaired = value.first),
                  ),
                  const SizedBox(height: 14),
                  if (repaired) ...[
                    TextField(
                      controller: repairCtrl,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'الصيانة التي تمت'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: partCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                          labelText: 'القطعة التي تم تغييرها'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'تكلفة الصيانة'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: warrantyType,
                      decoration:
                          const InputDecoration(labelText: 'مدة الضمان'),
                      items: const [
                        DropdownMenuItem(
                            value: AppConstants.warrantyNone,
                            child: Text('بدون ضمان')),
                        DropdownMenuItem(
                            value: AppConstants.warranty7Days,
                            child: Text('7 أيام')),
                        DropdownMenuItem(
                            value: AppConstants.warranty30Days,
                            child: Text('30 يوم')),
                        DropdownMenuItem(
                            value: AppConstants.warranty90Days,
                            child: Text('90 يوم')),
                        DropdownMenuItem(
                            value: AppConstants.warranty6Months,
                            child: Text('6 أشهر')),
                        DropdownMenuItem(
                            value: AppConstants.warranty1Year,
                            child: Text('سنة')),
                        DropdownMenuItem(
                            value: AppConstants.warranty2Years,
                            child: Text('سنتين')),
                        DropdownMenuItem(
                            value: AppConstants.warrantyCustom,
                            child: Text('مخصص')),
                      ],
                      onChanged: (value) => setDialogState(
                        () =>
                            warrantyType = value ?? AppConstants.warranty30Days,
                      ),
                    ),
                    if (warrantyType == AppConstants.warrantyCustom) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: warrantyDaysCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'عدد أيام الضمان'),
                      ),
                    ],
                  ] else ...[
                    TextField(
                      controller: reasonCtrl,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'سبب تعذر الإصلاح'),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: openedDevice,
                      title: const Text('تم فتح الجهاز'),
                      onChanged: (value) =>
                          setDialogState(() => openedDevice = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: changedAnyPart,
                      title: const Text('تم تغيير قطعة'),
                      onChanged: (value) =>
                          setDialogState(() => changedAnyPart = value ?? false),
                    ),
                    TextField(
                      controller: costCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'رسوم الفحص إن وجدت'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'ملاحظات الفني'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _repo.saveRepairResult(
                    id: m.id,
                    repaired: repaired,
                    repairDetails: repairCtrl.text.trim(),
                    changedPart: partCtrl.text.trim(),
                    unrepairableReason: reasonCtrl.text.trim(),
                    technicianNotes: notesCtrl.text.trim(),
                    laborCost: double.tryParse(costCtrl.text.trim()) ?? 0,
                    warrantyType:
                        repaired ? warrantyType : AppConstants.warrantyNone,
                    warrantyDays: warrantyType == AppConstants.warrantyCustom
                        ? int.tryParse(warrantyDaysCtrl.text.trim())
                        : null,
                    openedDevice: repaired ? null : openedDevice,
                    changedAnyPart: repaired ? null : changedAnyPart,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  _showActionError(e);
                }
              },
              child: Text(
                repaired
                    ? 'حفظ الصيانة وتجهيز الجهاز للتسليم'
                    : 'حفظ النتيجة وتجهيز الجهاز للإرجاع',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

    repairCtrl.dispose();
    partCtrl.dispose();
    reasonCtrl.dispose();
    notesCtrl.dispose();
    costCtrl.dispose();
    warrantyDaysCtrl.dispose();
    if (saved == true) {
      await _reloadMaintenanceAfterAction();
    }
  }

  Future<void> _showDeliveryConfirmDialog(MaintenanceModel m) async {
    final receiverCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final delivered = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'تسليم الجهاز للعميل',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(
                  icon: Icons.person_rounded,
                  label: 'العميل',
                  value: m.customerName ?? 'غير محدد'),
              if ((m.customerPhone ?? _customerPhone ?? '').isNotEmpty)
                _InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'الجوال',
                    value: m.customerPhone ?? _customerPhone!),
              _InfoRow(
                  icon: Icons.phone_android_rounded,
                  label: 'الجهاز',
                  value: '${m.brand} ${m.model}'),
              _InfoRow(
                  icon: Icons.payments_rounded,
                  label: 'المبلغ المطلوب',
                  value: '${m.remainingAmount.toStringAsFixed(2)} ر.س'),
              if (m.warrantyDays != null)
                _InfoRow(
                    icon: Icons.verified_user_rounded,
                    label: 'مدة الضمان',
                    value: '${m.warrantyDays} يوم'),
              const SizedBox(height: 10),
              TextField(
                controller: receiverCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'اسم المستلم إذا كان مختلفاً عن العميل',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات التسليم'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final notes = [
                  if (receiverCtrl.text.trim().isNotEmpty)
                    'المستلم: ${receiverCtrl.text.trim()}',
                  if (notesCtrl.text.trim().isNotEmpty)
                    'ملاحظات التسليم: ${notesCtrl.text.trim()}',
                ].join('\n');
                await _repo.updateStatus(
                  m.id,
                  AppConstants.statusDelivered,
                  reason: 'تأكيد التسليم',
                  notes: notes.isEmpty ? null : notes,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                _showActionError(e);
              }
            },
            child: Text('تأكيد التسليم',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    receiverCtrl.dispose();
    notesCtrl.dispose();
    if (delivered == true) {
      await _reloadMaintenanceAfterAction();
    }
  }

  Future<void> _showWarrantyClaimDialog(MaintenanceModel m) async {
    final problemCtrl = TextEditingController();
    final customerDescCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var relatedToRepair = true;
    final opened = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'فتح طلب ضمان',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: problemCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'المشكلة الحالية'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: customerDescCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'وصف العميل'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: relatedToRepair,
                  title: const Text('المشكلة مرتبطة بالصيانة السابقة'),
                  onChanged: (value) =>
                      setDialogState(() => relatedToRepair = value ?? true),
                ),
                TextField(
                  controller: notesCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات الموظف'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final warrantyRepo = WarrantyRepository();
                  await warrantyRepo.syncFromMaintenance();
                  final warranty = await warrantyRepo.getByMaintenance(m.id);
                  if (warranty == null) {
                    throw Exception('لا يوجد ضمان فعال لهذا الجهاز');
                  }
                  final description = [
                    if (problemCtrl.text.trim().isNotEmpty)
                      'المشكلة الحالية: ${problemCtrl.text.trim()}',
                    if (customerDescCtrl.text.trim().isNotEmpty)
                      'وصف العميل: ${customerDescCtrl.text.trim()}',
                    'مرتبطة بالصيانة السابقة: ${relatedToRepair ? 'نعم' : 'لا'}',
                    if (notesCtrl.text.trim().isNotEmpty)
                      'ملاحظات الموظف: ${notesCtrl.text.trim()}',
                  ].join('\n');
                  await warrantyRepo.addClaim(
                    WarrantyClaimModel.create(
                      warrantyId: warranty.id,
                      maintenanceId: m.id,
                      description: description,
                    ),
                  );
                  await _repo.updateStatus(
                    m.id,
                    AppConstants.statusWarrantyReturn,
                    reason: 'فتح طلب ضمان',
                    notes: description,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  _showActionError(e);
                }
              },
              child: Text('فتح طلب ضمان',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    problemCtrl.dispose();
    customerDescCtrl.dispose();
    notesCtrl.dispose();
    if (opened == true) {
      await _reloadMaintenanceAfterAction();
    }
  }

  Future<void> _reloadMaintenanceAfterAction() async {
    if (!mounted) return;
    context.read<NotificationsCubit>().loadNotifications();
    context.read<MaintenanceCubit>().loadById(widget.maintenanceId);
    await _loadWorkflowExtensions();
    await _loadWhatsappMessages();
  }

  void _showActionError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Exception: ', ''),
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Widget _buildWhatsappSection() {
    final colors = context.appColors;
    return _SectionCard(
      title: 'سجل رسائل WhatsApp',
      trailing: _loadingWhatsapp
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: _whatsappMessages.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد رسائل WhatsApp محفوظة لهذا الجهاز',
                style: GoogleFonts.cairo(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          : Column(
              children: _whatsappMessages
                  .take(5)
                  .map(
                    (msg) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _whatsappStatusIcon(msg.status),
                            size: 18,
                            color: _whatsappStatusColor(msg.status),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.typeLabel,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${msg.statusLabel} • ${_fmt(msg.preparedAt)}'
                                  '${msg.sentAt == null ? '' : ' • أرسلت ${_fmt(msg.sentAt!)}'}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                if ((msg.failureReason ?? '').isNotEmpty)
                                  Text(
                                    msg.failureReason!,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            msg.retryCount == 0
                                ? msg.phone
                                : '${msg.phone} • ${msg.retryCount}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildWhatsappButton(WhatsappMessageModel message) {
    final isResend = message.status == WhatsappRepository.statusSent;
    final labelPrefix = isResend ? 'إعادة إرسال' : 'إرسال';
    return OutlinedButton.icon(
      onPressed: () => _showWhatsappMessageDialog(message),
      icon: const Icon(Icons.chat_rounded, size: 18, color: AppColors.success),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.success,
        side: const BorderSide(color: AppColors.success),
      ),
      label: Text(
        '$labelPrefix ${message.typeLabel} عبر WhatsApp',
        style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showWhatsappMessageDialog(
    WhatsappMessageModel message,
  ) async {
    final initialMessage = await _whatsappRepo.ensureRequiredTrackingLink(
      message,
      message.message,
    );
    if (!mounted) return;
    final messageCtrl = TextEditingController(text: initialMessage);
    var sending = false;
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            message.typeLabel,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم العميل: ${message.phone}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: messageCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة قبل الإرسال',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() => sending = true);
                      try {
                        final user = AuthRepository().getCurrentUser();
                        await _whatsappRepo.sendPreparedMessage(
                          message.id,
                          message: messageCtrl.text.trim(),
                          sentBy: user?.username ?? user?.name,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (!mounted) return;
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
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                sending ? 'جارٍ الفتح...' : 'إرسال عبر WhatsApp',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
    messageCtrl.dispose();

    if (sent == true) {
      await _loadWhatsappMessages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم فتح WhatsApp وتسجيل الرسالة',
              style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  IconData _whatsappStatusIcon(String status) {
    switch (status) {
      case WhatsappRepository.statusSent:
        return Icons.check_circle_rounded;
      case WhatsappRepository.statusFailed:
        return Icons.error_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _whatsappStatusColor(String status) {
    switch (status) {
      case WhatsappRepository.statusSent:
        return AppColors.success;
      case WhatsappRepository.statusFailed:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف الصيانة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        content: Text('هل تريد حذف هذا السجل؟ لا يمكن التراجع.',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MaintenanceCubit>().delete(widget.maintenanceId);
            },
            child: Text('حذف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static const _intakeChecklistItems = [
    'الهيكل الخارجي',
    'الشاشة',
    'اللمس',
    'الكاميرا الأمامية',
    'الكاميرا الخلفية',
    'السماعة الداخلية',
    'السماعة الخارجية',
    'الميكروفون',
    'الشبكة',
    'Wi-Fi',
    'Bluetooth',
    'GPS',
    'الشحن',
    'منفذ الشحن',
    'البطارية',
    'الأزرار',
    'البصمة',
    'Face ID',
    'الاهتزاز',
    'الإضاءة',
    'الحرارة',
    'الكسر',
    'الانحناء',
    'آثار السوائل',
    'الخدوش',
  ];

  static const _finalChecklistItems = [
    'تشغيل الجهاز',
    'الشاشة',
    'اللمس',
    'الشحن',
    'البطارية',
    'الشبكة',
    'Wi-Fi',
    'Bluetooth',
    'الصوت',
    'الميكروفون',
    'الكاميرا',
    'الأزرار',
    'البصمة',
    'Face ID',
    'الحرارة',
    'إعادة التشغيل',
    'القطعة المستبدلة',
    'اختبار لمدة زمنية عند الحاجة',
  ];

  static const _checkStates = [
    'يعمل',
    'لا يعمل',
    'لم يتم اختباره',
    'يحتاج فحصاً إضافياً',
    'غير موجود في الجهاز',
  ];

  Widget _buildWorkflowCard(MaintenanceModel m) {
    final finalStatus = _finalChecklist?['overall_status'] as String?;
    final approvalStatus = _approval?['approval_status'] as String?;
    final latestHistory = _statusHistory.take(4).toList();

    return _SectionCard(
      title: 'الفحص والموافقة والاختبار',
      child: Column(
        children: [
          _WorkflowTile(
            icon: Icons.fact_check_rounded,
            title: 'فحص الاستلام',
            subtitle: _checklistSummary(
              _intakeChecklist,
              fallback: 'لم يتم حفظ فحص الاستلام بعد',
            ),
            color: _intakeChecklist == null
                ? AppColors.warning
                : AppColors.success,
            onTap: () => _showChecklistDialog(m, 'intake'),
          ),
          const Divider(height: 18),
          _WorkflowTile(
            icon: Icons.verified_rounded,
            title: 'موافقة العميل',
            subtitle: _approvalSummary(approvalStatus),
            color: approvalStatus == 'approved'
                ? AppColors.success
                : approvalStatus == 'rejected'
                    ? AppColors.error
                    : AppColors.warning,
            onTap: () => _showApprovalDialog(m),
          ),
          const Divider(height: 18),
          _WorkflowTile(
            icon: Icons.rule_rounded,
            title: 'الاختبار النهائي',
            subtitle: _checklistSummary(
              _finalChecklist,
              fallback:
                  'مطلوب قبل تحويل الطلب إلى ${AppConstants.maintenanceStatusLabel(AppConstants.statusReady)}',
            ),
            color:
                finalStatus == 'passed' ? AppColors.success : AppColors.error,
            onTap: () => _showChecklistDialog(m, 'final'),
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'سجل الحالات',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (latestHistory.isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لا توجد تغييرات حالة مسجلة بعد',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: context.appColors.textSecondary,
                ),
              ),
            )
          else
            ...latestHistory.map(_buildStatusHistoryRow),
        ],
      ),
    );
  }

  Widget _buildStatusHistoryRow(Map<String, dynamic> row) {
    final oldStatus = row['old_status'] as String?;
    final newStatus = row['new_status'] as String? ?? '';
    final changedAt = row['changed_at'] as int? ?? 0;
    final username = row['username'] as String? ?? 'النظام';
    final reason = row['reason'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: AppColors.maintenanceStatus(newStatus),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${oldStatus == null ? 'إنشاء' : AppConstants.maintenanceStatusLabel(oldStatus)} ← ${AppConstants.maintenanceStatusLabel(newStatus)}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    username,
                    _fmt(changedAt),
                    if (reason != null && reason.isNotEmpty) reason,
                  ].join(' - '),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _checklistSummary(
    Map<String, dynamic>? checklist, {
    required String fallback,
  }) {
    if (checklist == null) return fallback;
    final status = checklist['overall_status'] as String? ?? 'pending';
    final by = checklist['performed_by'] as String?;
    final label = status == 'passed'
        ? 'ناجح'
        : status == 'needs_attention'
            ? 'يحتاج متابعة'
            : 'قيد المتابعة';
    return by == null || by.isEmpty ? label : '$label - بواسطة $by';
  }

  String _approvalSummary(String? status) {
    if (_approval == null) return 'لم يتم حفظ موافقة العميل بعد';
    final method = _approval?['approval_method'] as String? ?? '';
    final amount = (_approval?['approved_amount'] as num?)?.toDouble() ?? 0;
    final label = status == 'approved'
        ? 'موافق'
        : status == 'rejected'
            ? 'مرفوض'
            : 'بانتظار الموافقة';
    final suffix = amount > 0 ? ' - ${amount.toStringAsFixed(2)} ر.س' : '';
    return '$label${method.isEmpty ? '' : ' عبر $method'}$suffix';
  }

  Map<String, String> _decodeChecklistItems(
    Map<String, dynamic>? checklist,
    List<String> defaults,
  ) {
    final initial = {for (final item in defaults) item: 'لم يتم اختباره'};
    final raw = checklist?['items_json'] as String?;
    if (raw == null || raw.isEmpty) return initial;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        initial[entry.key] = entry.value?.toString() ?? 'لم يتم اختباره';
      }
    } catch (_) {}
    return initial;
  }

  Future<void> _showChecklistDialog(
    MaintenanceModel m,
    String type,
  ) async {
    final isFinal = type == 'final';
    final existing = isFinal ? _finalChecklist : _intakeChecklist;
    final items = _decodeChecklistItems(
      existing,
      isFinal ? _finalChecklistItems : _intakeChecklistItems,
    );
    final performedByCtrl =
        TextEditingController(text: existing?['performed_by'] as String? ?? '');
    final approvedByCtrl =
        TextEditingController(text: existing?['approved_by'] as String? ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isFinal ? 'الاختبار النهائي' : 'فحص الاستلام',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 620,
            height: 560,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: performedByCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: isFinal ? 'اسم الفني' : 'اسم الموظف',
                        ),
                      ),
                    ),
                    if (isFinal) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: approvedByCtrl,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(
                            labelText: 'اعتماد فني/مشرف',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: items.keys.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.cairo(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                value: items[item],
                                items: _checkStates
                                    .map(
                                      (state) => DropdownMenuItem(
                                        value: state,
                                        child: Text(state),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    items[item] = value ?? 'لم يتم اختباره';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                final needsAttention = items.values.any(
                  (value) =>
                      value == 'لا يعمل' ||
                      value == 'لم يتم اختباره' ||
                      value == 'يحتاج فحصاً إضافياً',
                );
                await _repo.saveChecklist(
                  maintenanceId: m.id,
                  checklistType: type,
                  items: items,
                  overallStatus: needsAttention ? 'needs_attention' : 'passed',
                  performedBy: performedByCtrl.text.trim().isEmpty
                      ? null
                      : performedByCtrl.text.trim(),
                  approvedBy: approvedByCtrl.text.trim().isEmpty
                      ? null
                      : approvedByCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text('حفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );

    performedByCtrl.dispose();
    approvedByCtrl.dispose();
    notesCtrl.dispose();
    if (saved == true) {
      await _loadWorkflowExtensions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم حفظ ${isFinal ? 'الاختبار النهائي' : 'فحص الاستلام'}',
              style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _showApprovalDialog(MaintenanceModel m) async {
    String approvalStatus =
        _approval?['approval_status'] as String? ?? 'pending';
    String approvalMethod =
        _approval?['approval_method'] as String? ?? 'توقيع داخل المحل';
    final offeredCtrl = TextEditingController(
      text: ((_approval?['offered_amount'] as num?)?.toDouble() ?? m.totalCost)
          .toStringAsFixed(2),
    );
    final approvedCtrl = TextEditingController(
      text: ((_approval?['approved_amount'] as num?)?.toDouble() ?? m.totalCost)
          .toStringAsFixed(2),
    );
    final employeeCtrl = TextEditingController(
        text: _approval?['employee_name'] as String? ?? '');
    final messageCtrl = TextEditingController(
        text: _approval?['customer_message'] as String? ?? '');
    final termsCtrl =
        TextEditingController(text: _approval?['terms'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'موافقة العميل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: approvalStatus,
                  decoration: const InputDecoration(labelText: 'حالة الموافقة'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('بانتظار')),
                    DropdownMenuItem(value: 'approved', child: Text('موافق')),
                    DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => approvalStatus = value ?? 'pending',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: approvalMethod,
                  decoration:
                      const InputDecoration(labelText: 'طريقة الموافقة'),
                  items: const [
                    DropdownMenuItem(
                        value: 'توقيع داخل المحل',
                        child: Text('توقيع داخل المحل')),
                    DropdownMenuItem(
                        value: 'WhatsApp', child: Text('WhatsApp')),
                    DropdownMenuItem(
                        value: 'رابط آمن', child: Text('رابط آمن')),
                    DropdownMenuItem(value: 'SMS', child: Text('SMS')),
                    DropdownMenuItem(
                        value: 'مكالمة هاتفية مسجلة',
                        child: Text('مكالمة هاتفية مسجلة')),
                    DropdownMenuItem(
                        value: 'البريد الإلكتروني',
                        child: Text('البريد الإلكتروني')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => approvalMethod = value ?? 'توقيع داخل المحل',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: offeredCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'المبلغ المعروض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: approvedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'المبلغ الموافق عليه'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: employeeCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'اسم الموظف'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: messageCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'رسالة العميل أو التوقيع'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: termsCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'الشروط والاستثناءات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                await _repo.saveCustomerApproval(
                  maintenanceId: m.id,
                  approvalStatus: approvalStatus,
                  offeredAmount: double.tryParse(offeredCtrl.text) ?? 0,
                  approvedAmount: double.tryParse(approvedCtrl.text) ?? 0,
                  approvalMethod: approvalMethod,
                  employeeName: employeeCtrl.text.trim().isEmpty
                      ? null
                      : employeeCtrl.text.trim(),
                  customerMessage: messageCtrl.text.trim().isEmpty
                      ? null
                      : messageCtrl.text.trim(),
                  terms: termsCtrl.text.trim().isEmpty
                      ? null
                      : termsCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text('حفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );

    offeredCtrl.dispose();
    approvedCtrl.dispose();
    employeeCtrl.dispose();
    messageCtrl.dispose();
    termsCtrl.dispose();
    if (saved == true) {
      await _loadWorkflowExtensions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ موافقة العميل', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _printLabel(MaintenanceModel m) async {
    await LabelPrintService.printMaintenanceLabel(
      ticketNumber: m.ticketNumber,
      customerName: m.customerName ?? 'عميل',
      customerPhone: _customerPhone ?? '',
      deviceBrand: m.brand,
      deviceModel: m.model,
    );
  }

  void _showPrintLabelPrompt(MaintenanceModel m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            Text('تم إنشاء طلب الصيانة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                m.ticketNumber,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: m.ticketNumber,
                version: QrVersions.auto,
                size: 140,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'هل تريد طباعة ملصق الجهاز الآن؟',
              style: GoogleFonts.cairo(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('لاحقاً', style: GoogleFonts.cairo()),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _printLabel(m);
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: Text('طباعة الملصق الآن',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPartDialog(
      BuildContext context, String maintenanceId) async {
    // Pre-load inventory products for autocomplete.
    List<Map<String, dynamic>> products = [];
    try {
      products = await DatabaseService().rawQuery(
        '''SELECT id, name, purchase_price, sale_price, quantity, category_key
           FROM products
           WHERE is_active = 1 AND deleted_at IS NULL
           ORDER BY name''',
      );
    } catch (_) {}
    if (!mounted) return;

    String? selectedProductId;
    String partName = '';
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlgState) => AlertDialog(
          title: Text('إضافة قطعة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product search autocomplete
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textValue) {
                    if (textValue.text.trim().isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    final q = textValue.text.toLowerCase();
                    return products.where(
                      (p) => (p['name'] as String).toLowerCase().contains(q),
                    );
                  },
                  displayStringForOption: (p) => p['name'] as String,
                  onSelected: (p) {
                    setDlgState(() {
                      selectedProductId = p['id'] as String;
                      partName = p['name'] as String;
                      final sp = p['sale_price'];
                      priceCtrl.text =
                          sp != null ? (sp as num).toStringAsFixed(2) : '';
                    });
                  },
                  fieldViewBuilder:
                      (fctx, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textDirection: TextDirection.rtl,
                      onChanged: (v) {
                        partName = v;
                        if (selectedProductId != null) {
                          setDlgState(() => selectedProductId = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'اسم القطعة (ابحث في المخزون)',
                        labelStyle: GoogleFonts.cairo(),
                        suffixIcon: Icon(
                          selectedProductId != null
                              ? Icons.inventory_2_rounded
                              : Icons.search_rounded,
                          size: 18,
                          color: selectedProductId != null
                              ? AppColors.success
                              : null,
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (octx, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 240, maxWidth: 400),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options.map((p) {
                            final cost =
                                (p['purchase_price'] as num?)?.toDouble() ??
                                    0.0;
                            final sale =
                                (p['sale_price'] as num?)?.toDouble() ?? 0.0;
                            final qty = p['quantity'] as int? ?? 0;
                            final profit = sale - cost;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_rounded,
                                  size: 16, color: AppColors.primary),
                              title: Text(p['name'] as String,
                                  style: GoogleFonts.cairo(fontSize: 13)),
                              subtitle: Row(
                                children: [
                                  Text(
                                    'تكلفة: ${cost.toStringAsFixed(0)} | بيع: ${sale.toStringAsFixed(0)}',
                                    style: GoogleFonts.cairo(
                                        fontSize: 10, color: AppColors.primary),
                                  ),
                                  if (cost > 0 && profit >= 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'ربح: ${profit.toStringAsFixed(0)}',
                                      style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: qty > 0
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  qty > 0 ? 'كمية: $qty' : 'نفذ',
                                  style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      color: qty > 0
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              onTap: () => onSelected(p),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (selectedProductId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 13, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'سيتم خصم الكمية من المخزون تلقائيًا',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'الكمية',
                          labelStyle: GoogleFonts.cairo(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'السعر',
                          labelStyle: GoogleFonts.cairo(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () {
                final name = partName.trim();
                final qty = double.tryParse(qtyCtrl.text) ?? 1;
                final price = double.tryParse(priceCtrl.text) ?? 0;
                if (name.isEmpty) return;
                final part = MaintenancePartModel.create(
                  maintenanceId: maintenanceId,
                  productName: name,
                  quantity: qty,
                  unitPrice: price,
                  productId: selectedProductId,
                );
                context.read<MaintenanceCubit>().addPart(part);
                Navigator.pop(ctx);
              },
              child: Text('إضافة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(MaintenanceModel m) async {
    await LabelPrintService.printReceipt(
      ticketNumber: m.ticketNumber,
      customerName: m.customerName ?? 'عميل',
      customerPhone: _customerPhone ?? '',
      deviceBrand: m.brand,
      deviceModel: m.model,
      faultDescription: m.faultDescription,
      laborCost: m.laborCost,
      partsCost: m.partsCost,
      totalCost: m.totalCost,
      advancePaid: m.advancePaid,
      remainingAmount: m.remainingAmount,
      receivedAt: m.receivedAt,
      imei: m.imei,
      color: m.color,
      technicianName: m.technicianName,
      notes: m.notes,
      estimatedDelivery: m.estimatedDelivery,
    );
  }

  Future<void> _printDelivery(MaintenanceModel m) async {
    await LabelPrintService.printDeliverySlip(
      ticketNumber: m.ticketNumber,
      customerName: m.customerName ?? 'عميل',
      customerPhone: _customerPhone ?? '',
      deviceBrand: m.brand,
      deviceModel: m.model,
      totalCost: m.totalCost,
      advancePaid: m.advancePaid,
      remainingAmount: m.remainingAmount,
      receivedAt: m.receivedAt,
      deliveredAt: m.deliveredAt,
      imei: m.imei,
    );
  }

  void _showAddNotificationDialog(BuildContext context, MaintenanceModel m) {
    final titleCtrl = TextEditingController(
        text: 'تنبيه: ${m.brand} ${m.model} - ${m.ticketNumber}');
    final msgCtrl = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('إضافة تنبيه للجهاز',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                    labelText: 'العنوان', labelStyle: GoogleFonts.cairo()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: msgCtrl,
                textDirection: TextDirection.rtl,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: 'الرسالة', labelStyle: GoogleFonts.cairo()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: priority,
                onChanged: (v) => setDlgState(() => priority = v ?? 'medium'),
                decoration: InputDecoration(
                    labelText: 'الأولوية', labelStyle: GoogleFonts.cairo()),
                items: [
                  DropdownMenuItem(
                      value: 'low',
                      child: Text('منخفض', style: GoogleFonts.cairo())),
                  DropdownMenuItem(
                      value: 'medium',
                      child: Text('متوسط', style: GoogleFonts.cairo())),
                  DropdownMenuItem(
                      value: 'high',
                      child: Text('عالي', style: GoogleFonts.cairo())),
                  DropdownMenuItem(
                      value: 'critical',
                      child: Text('حرج', style: GoogleFonts.cairo())),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final message = msgCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                final notifCubit = context.read<NotificationsCubit>();
                await NotificationsRepository().addDeviceNotification(
                  deviceId: m.id,
                  title: title,
                  message: message.isEmpty
                      ? 'تنبيه للجهاز ${m.brand} ${m.model}'
                      : message,
                  priority: priority,
                );
                if (!mounted) return;
                notifCubit.loadNotifications();
                _loadLinkedNotifications();
              },
              child: Text('إضافة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status dropdown
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DocSummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _DocSummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _WorkflowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: trailing!),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: GoogleFonts.cairo(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String status;

  const _StageBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.maintenanceStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          AppConstants.maintenanceStageLabel(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final Color? color;

  const _CostRow({
    required this.label,
    required this.amount,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textColor = color ?? colors.textPrimary;
    final style = GoogleFonts.cairo(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: textColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${amount.toStringAsFixed(2)} ر.س',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  final MaintenancePartModel part;
  final VoidCallback onRemove;

  const _PartRow({required this.part, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.build_circle_rounded,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.productName,
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                Text(
                  'الكمية: ${part.quantity.toStringAsFixed(0)} × ${part.unitPrice.toStringAsFixed(2)} ر.س',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: colors.textSecondary),
                ),
                if (part.hasCostData)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _miniChip(
                          'تكلفة: ${part.totalCost.toStringAsFixed(2)} ر.س',
                          AppColors.warning,
                        ),
                        _miniChip(
                          'ربح: ${part.totalProfit.toStringAsFixed(2)} ر.س',
                          part.totalProfit >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${part.totalPrice.toStringAsFixed(2)} ر.س',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (part.hasCostData)
                Text(
                  '+${part.profitMarginPct.toStringAsFixed(0)}%',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: part.totalProfit >= 0
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove_circle_outline_rounded,
                  size: 18, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PartsProfitSummary extends StatelessWidget {
  final List<MaintenancePartModel> parts;
  const _PartsProfitSummary({required this.parts});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = context.appColors.textSecondary;
    final primaryColor = context.appColors.textPrimary;
    final trackedParts = parts.where((p) => p.hasCostData).toList();
    final totalRevenue = parts.fold(0.0, (s, p) => s + p.totalPrice);
    final totalCost = trackedParts.fold(0.0, (s, p) => s + p.totalCost);
    final totalProfit = trackedParts.fold(0.0, (s, p) => s + p.totalProfit);
    final margin = totalCost > 0 ? (totalProfit / totalCost) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'ملخص أرباح القطع',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('إجمالي القطع (للعميل)',
              '${totalRevenue.toStringAsFixed(2)} ر.س', primaryColor,
              secondaryColor: secondaryColor),
          if (trackedParts.isNotEmpty) ...[
            _row('تكلفة القطع (المشتريات)',
                '${totalCost.toStringAsFixed(2)} ر.س', AppColors.warning,
                secondaryColor: secondaryColor),
            _row(
              'صافي الربح من القطع',
              '${totalProfit.toStringAsFixed(2)} ر.س  (${margin.toStringAsFixed(0)}%)',
              totalProfit >= 0 ? AppColors.success : AppColors.error,
              secondaryColor: secondaryColor,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor,
      {required Color secondaryColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontSize: 12, color: secondaryColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final NotificationModel n;
  const _NotifRow({required this.n});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(n.priorityIcon, size: 16, color: n.priorityColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (n.message.isNotEmpty)
                  Text(
                    n.message,
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            n.timeAgo,
            style: GoogleFonts.cairo(fontSize: 11, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<MaintenanceImageModel> images;
  const _ImageGrid({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Center(
        child: Text('لا توجد صور',
            style: GoogleFonts.cairo(color: context.appColors.textSecondary)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final img = images[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: File(img.imagePath).existsSync()
              ? Image.file(File(img.imagePath), fit: BoxFit.cover)
              : Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child:
                      const Icon(Icons.image_rounded, color: AppColors.primary),
                ),
        );
      },
    );
  }
}
