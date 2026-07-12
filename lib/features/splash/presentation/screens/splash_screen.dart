import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../features/auth/data/auth_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _minimumSplashDuration = Duration(seconds: 6);

  late final AnimationController _motionController;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  double _targetProgress = 0;
  String _loadingText = 'تشغيل النظام...';
  String _permissionText = 'سيطلب التطبيق إذن الكاميرا بعد اكتمال التحميل.';
  _CameraPermissionState _cameraState = _CameraPermissionState.waiting;
  bool _hasInitializationError = false;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );
    _initialize();
  }

  @override
  void dispose() {
    _motionController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final startedAt = DateTime.now();

    if (mounted) {
      setState(() {
        _targetProgress = 0;
        _loadingText = 'تشغيل النظام...';
        _permissionText = 'سيطلب التطبيق إذن الكاميرا بعد اكتمال التحميل.';
        _cameraState = _CameraPermissionState.waiting;
        _hasInitializationError = false;
      });
    }
    _progressController.value = 0;

    try {
      await _updateProgress(
        0.16,
        'تشغيل واجهة الاستقبال...',
        'يتم تجهيز بيئة العمل قبل طلب أي صلاحية.',
      );

      await _updateProgress(
        0.38,
        'تهيئة قاعدة البيانات...',
        'يتم فتح ملفات العملاء والأجهزة والصيانة.',
      );
      await DatabaseService().db;

      await _updateProgress(
        0.62,
        'تحميل إعدادات النظام...',
        'يتم تجهيز الشعار ومسار العمل للجوال والآيباد.',
      );
      final settings = SettingsService();
      await settings.reload();
      final nextRoute =
          settings.shopSetupCompleted ? '/repair-board' : '/shop-setup';
      await Future.delayed(const Duration(milliseconds: 360));

      if (AuthRepository().getCurrentUser() == null) {
        await AuthRepository().login('admin', 'admin123');
      }

      await _updateProgress(
        0.82,
        'تحضير الكاميرا...',
        'سيظهر طلب السماح بالكاميرا لتصوير حالة الجهاز عند الاستلام.',
      );

      final remaining =
          _minimumSplashDuration - DateTime.now().difference(startedAt);
      if (remaining.inMilliseconds > 0) {
        await Future.delayed(remaining);
      }

      await _requestCameraPermission();

      await _updateProgress(
        1,
        'اكتمل التشغيل.',
        _cameraState.successMessage,
      );
      await Future.delayed(const Duration(milliseconds: 780));

      if (!mounted) return;
      context.go(nextRoute);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasInitializationError = true;
        _loadingText = 'تعذر إكمال التهيئة.';
        _permissionText = 'تحقق من تشغيل النظام ثم أعد المحاولة.';
        _cameraState = _CameraPermissionState.failed;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    if (!mounted) return;

    if (!_supportsCameraPermissionPrompt) {
      setState(() {
        _cameraState = _CameraPermissionState.notRequired;
        _permissionText = 'إذن الكاميرا سيظهر عند الحاجة على هذا النظام.';
      });
      await Future.delayed(const Duration(milliseconds: 380));
      return;
    }

    setState(() {
      _cameraState = _CameraPermissionState.requesting;
      _loadingText = 'طلب إذن الكاميرا...';
      _permissionText = 'عند ظهور رسالة النظام اختر السماح باستخدام الكاميرا.';
    });

    await Future.delayed(const Duration(milliseconds: 420));
    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      if (status.isGranted || status.isLimited) {
        _cameraState = _CameraPermissionState.granted;
        _permissionText = 'تم السماح باستخدام الكاميرا بنجاح.';
      } else if (status.isPermanentlyDenied) {
        _cameraState = _CameraPermissionState.permanentlyDenied;
        _permissionText =
            'تم رفض إذن الكاميرا. يمكن تفعيله لاحقًا من إعدادات الجهاز.';
      } else {
        _cameraState = _CameraPermissionState.denied;
        _permissionText =
            'لم يتم منح إذن الكاميرا الآن. يمكن طلبه مرة أخرى عند التصوير.';
      }
    });
  }

  bool get _supportsCameraPermissionPrompt {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _updateProgress(
    double value,
    String text,
    String permissionText,
  ) async {
    if (!mounted) return;

    final startValue = _targetProgress;
    setState(() {
      _targetProgress = value.clamp(0, 1);
      _loadingText = text;
      _permissionText = permissionText;
    });

    _progressController
      ..value = startValue
      ..animateTo(_targetProgress);

    await Future.delayed(const Duration(milliseconds: 520));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF06101A),
        body: AnimatedBuilder(
          animation: _motionController,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ElegantSplashBackground(
                      value: _motionController.value,
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 700;
                final sidePadding = isTablet ? 44.0 : 22.0;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: isTablet ? 36 : 22,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 620 : 460,
                        minHeight: math.max(0, constraints.maxHeight - 44),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SplashLogo(
                            motion: _motionController,
                            size: isTablet ? 260 : 220,
                          ),
                          SizedBox(height: isTablet ? 28 : 22),
                          _BrandHeader(isTablet: isTablet),
                          SizedBox(height: isTablet ? 28 : 24),
                          _LoadingPanel(
                            progress: _progressAnimation,
                            targetProgress: _targetProgress,
                            loadingText: _loadingText,
                            permissionText: _permissionText,
                            cameraState: _cameraState,
                            hasError: _hasInitializationError,
                            onRetry: _initialize,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum _CameraPermissionState {
  waiting,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  notRequired,
  failed;

  bool get isPositive {
    return this == granted || this == notRequired;
  }

  String get successMessage {
    return switch (this) {
      granted => 'الكاميرا جاهزة للاستخدام.',
      denied => 'يمكن طلب إذن الكاميرا لاحقًا عند التصوير.',
      permanentlyDenied => 'يمكن تفعيل الكاميرا لاحقًا من إعدادات الجهاز.',
      notRequired => 'سيتم طلب الكاميرا عند الحاجة.',
      failed => 'تعذر تجهيز إذن الكاميرا.',
      waiting || requesting => 'يتم تجهيز إذن الكاميرا...',
    };
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({
    required this.motion,
    required this.size,
  });

  final Animation<double> motion;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LogoAuraPainter(value: motion.value),
                ),
              ),
              Transform.translate(
                offset: Offset(
                  0,
                  math.sin(motion.value * math.pi * 2) * 4,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DescendingLightPainter(value: motion.value),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 560.ms).scale(
          begin: const Offset(.92, .92),
          duration: 760.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isTablet});

  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'ProShop',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: isTablet ? 48 : 40,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ).animate().fadeIn(delay: 160.ms).slideY(begin: .14),
        const SizedBox(height: 8),
        Text(
          'نظام إدارة محلات الجوالات والصيانة',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: Colors.white.withAlpha(218),
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ).animate().fadeIn(delay: 260.ms).slideY(begin: .12),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({
    required this.progress,
    required this.targetProgress,
    required this.loadingText,
    required this.permissionText,
    required this.cameraState,
    required this.hasError,
    required this.onRetry,
  });

  final Animation<double> progress;
  final double targetProgress;
  final String loadingText;
  final String permissionText;
  final _CameraPermissionState cameraState;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final accent = hasError
        ? const Color(0xFFFF4D5E)
        : cameraState.isPositive
            ? const Color(0xFF65FF93)
            : const Color(0xFF18E7D2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xE60A1725),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatusIcon(state: cameraState, hasError: hasError),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loadingText,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(targetProgress * 100).round()}%',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              return _ElegantProgressBar(
                value: progress.value,
                accent: accent,
              );
            },
          ),
          const SizedBox(height: 16),
          _PermissionMessage(
            text: permissionText,
            state: cameraState,
            hasError: hasError,
          ),
          if (hasError) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF4D5E),
                side: const BorderSide(color: Color(0xFFFF4D5E)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 380.ms, duration: 520.ms).slideY(begin: .18);
  }
}

class _ElegantProgressBar extends StatelessWidget {
  const _ElegantProgressBar({
    required this.value,
    required this.accent,
  });

  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: width * value.clamp(0, 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withAlpha(210),
                      const Color(0xFFFFD94F),
                      accent,
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ProgressGlowPainter(value: value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.text,
    required this.state,
    required this.hasError,
  });

  final String text;
  final _CameraPermissionState state;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? const Color(0xFFFF4D5E)
        : state.isPositive
            ? const Color(0xFF65FF93)
            : const Color(0xFF18E7D2);

    return AnimatedSwitcher(
      duration: 260.ms,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(78)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              state.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.cairo(
                  color: Colors.white.withAlpha(224),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.state,
    required this.hasError,
  });

  final _CameraPermissionState state;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? const Color(0xFFFF4D5E)
        : state.isPositive
            ? const Color(0xFF65FF93)
            : const Color(0xFF18E7D2);

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(82)),
      ),
      child: Icon(
        state.icon,
        color: color,
        size: 22,
      ),
    );
  }
}

extension on _CameraPermissionState {
  IconData get icon {
    return switch (this) {
      _CameraPermissionState.granted => Icons.check_circle_rounded,
      _CameraPermissionState.denied ||
      _CameraPermissionState.permanentlyDenied =>
        Icons.camera_alt_outlined,
      _CameraPermissionState.failed => Icons.error_rounded,
      _CameraPermissionState.requesting => Icons.photo_camera_rounded,
      _CameraPermissionState.notRequired => Icons.task_alt_rounded,
      _CameraPermissionState.waiting => Icons.hourglass_top_rounded,
    };
  }
}

class _LogoAuraPainter extends CustomPainter {
  const _LogoAuraPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = .5 + math.sin(value * math.pi * 2) * .5;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD94F).withAlpha(75),
          const Color(0xFF18E7D2).withAlpha(22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: size.width * (.56 + pulse * .05),
      ));
    canvas.drawCircle(center, size.width * .58, glowPaint);

    for (var index = 0; index < 3; index++) {
      final rect = Rect.fromCircle(
        center: center,
        radius: size.width * (.43 + index * .065 + pulse * .018),
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF18E7D2).withAlpha(82 - index * 18);
      canvas.drawArc(
        rect,
        value * math.pi * 2 + index * .85,
        math.pi * .72,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoAuraPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _DescendingLightPainter extends CustomPainter {
  const _DescendingLightPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final y = (value * 1.35 % 1.0) * size.height;
    final rect = Rect.fromLTWH(0, y - 44, size.width, 88);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x33FFFFFF),
          Color(0x6618E7D2),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(40),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DescendingLightPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _ProgressGlowPainter extends CustomPainter {
  const _ProgressGlowPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final shimmerX = size.width * ((value * 1.4) % 1.0);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x88FFFFFF),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(shimmerX - 38, 0, 76, size.height));

    canvas.drawRect(Rect.fromLTWH(shimmerX - 38, 0, 76, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ProgressGlowPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _ElegantSplashBackground extends CustomPainter {
  const _ElegantSplashBackground({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF06101A),
          Color(0xFF071E2C),
          Color(0xFF062620),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(13)
      ..strokeWidth = 1;
    const grid = 58.0;
    final drift = (value * grid) % grid;
    for (double x = -grid + drift; x < size.width + grid; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -grid + drift; y < size.height + grid; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final sweepTop = size.height * ((value * 1.18) % 1.16) - size.height * .16;
    final sweepRect = Rect.fromLTWH(0, sweepTop, size.width, size.height * .24);
    final sweepPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x0DFFFFFF),
          Color(0x3318E7D2),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(sweepRect);
    canvas.drawRect(sweepRect, sweepPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF18E7D2).withAlpha(24)
      ..strokeWidth = 1.4;
    for (var index = -4; index < 8; index++) {
      final startX = index * 170.0 + value * 115;
      canvas.drawLine(
        Offset(startX, -20),
        Offset(startX + size.height * .54, size.height + 20),
        linePaint,
      );
    }

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF65FF93).withAlpha(70);
    const corner = 82.0;
    const inset = 28.0;

    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + corner)
        ..lineTo(inset, inset)
        ..lineTo(inset + corner, inset),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - inset - corner, inset)
        ..lineTo(size.width - inset, inset)
        ..lineTo(size.width - inset, inset + corner),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(inset, size.height - inset - corner)
        ..lineTo(inset, size.height - inset)
        ..lineTo(inset + corner, size.height - inset),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - inset - corner, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset - corner),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ElegantSplashBackground oldDelegate) {
    return oldDelegate.value != value;
  }
}
