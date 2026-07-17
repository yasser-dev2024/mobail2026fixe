import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/tracking_service.dart';

class TrackingScreen extends StatefulWidget {
  final String? initialCode;

  const TrackingScreen({super.key, this.initialCode});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _service = TrackingService();
  final _codeCtrl = TextEditingController();

  TrackingRecord? _record;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode?.trim() ?? '';
    _codeCtrl.text = code;
    if (code.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup(code));
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? value]) async {
    final code = (value ?? _codeCtrl.text).trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _record = null;
    });

    final record = await _service.loadByCode(code);
    if (!mounted) return;
    setState(() {
      _record = record;
      _error = record == null ? 'لم يتم العثور على طلب بهذا الرقم.' : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDirectCode = (widget.initialCode ?? '').trim().isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFFAF5),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _lookup(),
            color: const Color(0xFF08916F),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                const _TrackingHero(),
                if (_loading) ...[
                  const SizedBox(height: 28),
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF08916F),
                    ),
                  ),
                ] else if (_error != null) ...[
                  const SizedBox(height: 18),
                  _EmptyTrackingResult(message: _error!),
                ] else if (!hasDirectCode) ...[
                  const SizedBox(height: 18),
                  const _MissingDirectLinkPanel(),
                ] else if (_record != null) ...[
                  const SizedBox(height: 18),
                  _StatusPanel(record: _record!),
                  const SizedBox(height: 14),
                  _DevicePanel(record: _record!),
                  const SizedBox(height: 14),
                  _TimelinePanel(record: _record!),
                  if (_record!.photos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PhotosPanel(photos: _record!.photos),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingHero extends StatelessWidget {
  const _TrackingHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF08A97E), Color(0xFF0A7B5E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08A97E).withValues(alpha: .20),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeroLinesPainter()),
          ),
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تتبع صيانة جهازك',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _HeroBadge(
                      icon: Icons.verified_rounded,
                      text: 'متابعة مباشرة من مركز الصيانة',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingDirectLinkPanel extends StatelessWidget {
  const _MissingDirectLinkPanel();

  @override
  Widget build(BuildContext context) {
    return const _WhitePanel(
      child: Column(
        children: [
          Icon(
            Icons.link_off_rounded,
            color: Color(0xFF08916F),
            size: 58,
          ),
          SizedBox(height: 12),
          Text(
            'رابط التتبع غير مكتمل',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'افتح رابط التتبع الذي يصل للعميل في رسالة الاستلام لعرض حالة الجهاز مباشرة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final TrackingRecord record;

  const _StatusPanel({required this.record});

  @override
  Widget build(BuildContext context) {
    final info = record.statusInfo;
    final statusColor = _trackingStatusColor(record.status);
    final progress = info.progress.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor,
            Color.lerp(statusColor, const Color(0xFF04563F), .34)!,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: .24),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeroLinesPainter())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .28)),
                    ),
                    child: Icon(
                      info.isFinal
                          ? Icons.task_alt_rounded
                          : Icons.build_circle_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _StatusTicketBadge(ticket: record.ticketNumber),
                      ],
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: .28),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                info.description,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              _StatusMetaGrid(record: record),
              if (record.parts.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SoftInfoBox(
                  icon: Icons.construction_rounded,
                  title: 'القطعة المطلوبة',
                  value: record.parts.join('، '),
                ),
              ],
              if (record.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _SoftInfoBox(
                  icon: Icons.notes_rounded,
                  title: 'ملاحظة المركز',
                  value: record.notes,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTicketBadge extends StatelessWidget {
  final String ticket;

  const _StatusTicketBadge({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'رقم الطلب: $ticket',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusMetaGrid extends StatelessWidget {
  final TrackingRecord record;

  const _StatusMetaGrid({required this.record});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetaItem(
        icon: Icons.update_rounded,
        title: 'آخر تحديث',
        value: _formatDateTime(record.updatedAt),
      ),
      _MetaItem(
        icon: Icons.event_available_rounded,
        title: 'التسليم المتوقع',
        value: _formatDate(record.estimatedDelivery),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2,
                child: _SoftInfoBox(
                  icon: item.icon,
                  title: item.title,
                  value: item.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SoftInfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SoftInfoBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: .84),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
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

class _DevicePanel extends StatelessWidget {
  final TrackingRecord record;

  const _DevicePanel({required this.record});

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.phone_iphone_rounded,
            title: 'بيانات الجهاز',
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.phone_android_rounded,
            label: 'الجهاز',
            value: record.deviceName.isEmpty ? 'غير محدد' : record.deviceName,
          ),
          if (record.imei.isNotEmpty)
            _InfoLine(
              icon: Icons.pin_rounded,
              label: 'IMEI',
              value: record.imei,
              ltr: true,
            ),
          _InfoLine(
            icon: Icons.report_problem_rounded,
            label: 'العطل المسجل',
            value: record.faultDescription.isEmpty
                ? 'لم يتم تسجيل وصف للعطل'
                : record.faultDescription,
          ),
          _InfoLine(
            icon: Icons.schedule_rounded,
            label: 'تاريخ الاستلام',
            value: _formatDateTime(record.receivedAt),
          ),
          if (record.technicianName.isNotEmpty)
            _InfoLine(
              icon: Icons.engineering_rounded,
              label: 'الفني',
              value: record.technicianName,
            ),
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  final TrackingRecord record;

  const _TimelinePanel({required this.record});

  @override
  Widget build(BuildContext context) {
    final history = record.history.isEmpty
        ? [
            TrackingHistoryItem(
              status: record.status,
              label: AppConstants.maintenanceStatusLabel(record.status),
              reason: 'آخر حالة مسجلة',
              notes: '',
              changedAt: record.updatedAt,
            ),
          ]
        : record.history;

    return _WhitePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.timeline_rounded,
            title: 'مراحل الصيانة',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < history.length; index++)
            _TimelineTile(
              item: history[index],
              isLast: index == history.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PhotosPanel extends StatelessWidget {
  final List<TrackingPhoto> photos;

  const _PhotosPanel({required this.photos});

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.photo_library_rounded,
            title: 'صور الجهاز',
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .82,
            ),
            itemBuilder: (context, index) => _PhotoTile(photo: photos[index]),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final TrackingPhoto photo;

  const _PhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    final file = File(photo.path);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _MissingImage(),
                  )
                : const _MissingImage(),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.label.isEmpty ? 'صورة الجهاز' : photo.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
                if (photo.caption.isNotEmpty)
                  Text(
                    photo.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
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

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
    );
  }
}

class _WhitePanel extends StatelessWidget {
  final Widget child;

  const _WhitePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEBE5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A7B5E).withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PanelHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7F1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF08916F), size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ltr;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF08916F), size: 20),
          const SizedBox(width: 9),
          SizedBox(
            width: 102,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
              textAlign: ltr ? TextAlign.left : TextAlign.start,
              style: GoogleFonts.cairo(
                color: const Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final TrackingHistoryItem item;
  final bool isLast;

  const _TimelineTile({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = _trackingStatusColor(item.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .26),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateTime(item.changedAt),
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.reason.isNotEmpty || item.notes.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      [item.reason, item.notes]
                          .where((value) => value.trim().isNotEmpty)
                          .join(' - '),
                      style: GoogleFonts.cairo(
                        color: const Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrackingResult extends StatelessWidget {
  final String message;

  const _EmptyTrackingResult({required this.message});

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 62, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: const Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem {
  final IconData icon;
  final String title;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _HeroLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..strokeWidth = 1.1;
    for (var index = -8; index < 12; index++) {
      final x = index * 34.0;
      canvas.drawLine(
        Offset(x, size.height + 20),
        Offset(x + size.height * .9, -20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _trackingStatusColor(String status) {
  switch (status) {
    case AppConstants.statusReady:
    case AppConstants.statusRepaired:
    case AppConstants.statusDelivered:
      return const Color(0xFF08A36F);
    case AppConstants.statusWaitingPart:
    case AppConstants.statusWaitingCustomerApproval:
      return const Color(0xFFF59E0B);
    case AppConstants.statusUnrepairable:
    case AppConstants.statusCancelled:
      return const Color(0xFFEF4444);
    case AppConstants.statusRepairing:
    case AppConstants.statusUnderTesting:
      return const Color(0xFF2563EB);
    default:
      return AppColors.primary;
  }
}

String _formatDate(int? ms) {
  if (ms == null || ms <= 0) return 'غير محدد';
  final date = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(int? ms) {
  if (ms == null || ms <= 0) return 'غير محدد';
  final date = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_formatDate(ms)} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
