import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_cubit.dart';
import '../utils/platform_utils.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      backgroundColor: colors.background,
      drawer: _AppSideDrawer(currentLocation: location),
      body: Column(
        children: [
          _TopBar(
            title: _titleFor(location),
            location: location,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  String _titleFor(String location) {
    if (location.startsWith('/repair-board')) return 'إدارة أجهزة الصيانة';
    if (location.startsWith('/dashboard')) return 'لوحة المؤشرات';
    if (location.startsWith('/customers')) return 'العملاء';
    if (location.startsWith('/devices')) return 'الأجهزة';
    if (location.startsWith('/maintenance')) return 'سجل الصيانة';
    if (location.startsWith('/warranty')) return 'سجل الضمانات الكامل';
    if (location.startsWith('/notifications')) return 'التنبيهات';
    if (location.startsWith('/settings')) return 'الإعدادات';
    if (location.startsWith('/backup')) return 'النسخ الاحتياطي';
    if (location.startsWith('/whatsapp')) return 'رسائل واتساب';
    if (location.startsWith('/invoices')) return 'الفواتير والضمانات';
    if (location.startsWith('/reports')) return 'التقارير';
    if (location.startsWith('/analytics')) return 'التحليلات';
    if (location.startsWith('/technicians')) return 'الفنيون';
    if (location.startsWith('/users')) return 'المستخدمون';
    if (location.startsWith('/barcode')) return 'مسح الباركود';
    if (location.startsWith('/media')) return 'الوسائط والصور';
    if (location.startsWith('/search')) return 'البحث';
    return 'إدارة أجهزة الصيانة';
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String location;

  const _TopBar({
    required this.title,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Widget topBarIcon({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
      required bool compact,
      Color? color,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        constraints: compact
            ? const BoxConstraints.tightFor(width: 40, height: 44)
            : null,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
        icon: Icon(icon, size: compact ? 22 : null),
        color: color,
      );
    }

    Widget notificationsButton(bool compact) {
      return BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final count = state is NotificationsLoaded ? state.unreadCount : 0;
          if (count <= 0) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsetsDirectional.only(end: compact ? 4 : 8),
            child: Tooltip(
              message: 'التنبيهات',
              child: InkWell(
                onTap: () => context.go('/notifications'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 6 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.error,
                        size: compact ? 17 : 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: GoogleFonts.cairo(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;

              return Row(
                children: [
                  Builder(
                    builder: (buttonContext) => topBarIcon(
                      tooltip: 'القائمة الجانبية',
                      onPressed: () => Scaffold.of(buttonContext).openDrawer(),
                      icon: Icons.menu_rounded,
                      compact: compact,
                    ),
                  ),
                  if (!compact) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: compact ? 18 : 21,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 12),
                  notificationsButton(compact),
                  if (AppPlatform.supportsWindowControls) ...[
                    SizedBox(width: compact ? 0 : 4),
                    topBarIcon(
                      tooltip: 'تصغير',
                      onPressed: () => windowManager.minimize(),
                      icon: Icons.remove_rounded,
                      compact: compact,
                    ),
                    topBarIcon(
                      tooltip: 'تكبير / استعادة',
                      onPressed: () async {
                        if (await windowManager.isMaximized()) {
                          await windowManager.unmaximize();
                        } else {
                          await windowManager.maximize();
                        }
                      },
                      icon: Icons.crop_square_rounded,
                      compact: compact,
                    ),
                    topBarIcon(
                      tooltip: 'إغلاق البرنامج',
                      onPressed: () => windowManager.close(),
                      icon: Icons.close_rounded,
                      compact: compact,
                      color: AppColors.error,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppSideDrawer extends StatelessWidget {
  final String currentLocation;

  const _AppSideDrawer({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final drawerWidth = MediaQuery.sizeOf(context).width.clamp(300.0, 360.0);

    return Drawer(
      width: drawerWidth,
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(currentLocation: currentLocation),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  const _DrawerSectionLabel('التنقل'),
                  _DrawerTile(
                    path: '/repair-board',
                    currentLocation: currentLocation,
                    icon: Icons.home_rounded,
                    label: 'الصفحة الرئيسية',
                  ),
                  _DrawerTile(
                    path: '/dashboard',
                    currentLocation: currentLocation,
                    icon: Icons.dashboard_rounded,
                    label: 'لوحة المؤشرات',
                  ),
                  _DrawerTile(
                    path: '/whatsapp',
                    currentLocation: currentLocation,
                    icon: Icons.chat_rounded,
                    label: 'رسائل واتساب',
                  ),
                  _NotificationsDrawerTile(currentLocation: currentLocation),
                  const _DrawerSectionLabel('العمل'),
                  _DrawerTile(
                    path: '/customers',
                    currentLocation: currentLocation,
                    icon: Icons.people_alt_rounded,
                    label: 'العملاء',
                  ),
                  _DrawerTile(
                    path: '/devices',
                    currentLocation: currentLocation,
                    icon: Icons.phone_android_rounded,
                    label: 'الأجهزة',
                  ),
                  _DrawerTile(
                    path: '/maintenance',
                    currentLocation: currentLocation,
                    icon: Icons.build_circle_rounded,
                    label: 'سجل الصيانة',
                  ),
                  _DrawerTile(
                    path: '/warranty',
                    currentLocation: currentLocation,
                    icon: Icons.verified_user_rounded,
                    label: 'سجل الضمانات الكامل',
                    accentColor: AppColors.warrantyActive,
                  ),
                  _DrawerTile(
                    path: '/invoices',
                    currentLocation: currentLocation,
                    icon: Icons.receipt_long_rounded,
                    label: 'الفواتير والضمانات',
                  ),
                  const _DrawerSectionLabel('الأدوات'),
                  _DrawerTile(
                    path: '/search',
                    currentLocation: currentLocation,
                    icon: Icons.search_rounded,
                    label: 'البحث',
                  ),
                  _DrawerTile(
                    path: '/reports',
                    currentLocation: currentLocation,
                    icon: Icons.assessment_rounded,
                    label: 'التقارير',
                  ),
                  _DrawerTile(
                    path: '/analytics',
                    currentLocation: currentLocation,
                    icon: Icons.insights_rounded,
                    label: 'التحليلات',
                  ),
                  _DrawerTile(
                    path: '/barcode',
                    currentLocation: currentLocation,
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'مسح الباركود',
                  ),
                  _DrawerTile(
                    path: '/media',
                    currentLocation: currentLocation,
                    icon: Icons.photo_library_rounded,
                    label: 'الوسائط والصور',
                  ),
                  const _DrawerSectionLabel('الإعدادات'),
                  const _ThemeModeSwitchTile(),
                  _DrawerTile(
                    path: '/settings',
                    currentLocation: currentLocation,
                    icon: Icons.settings_rounded,
                    label: 'إعدادات التطبيق والمحل',
                  ),
                  _DrawerTile(
                    path: '/settings/alert-sounds',
                    currentLocation: currentLocation,
                    icon: Icons.notifications_active_rounded,
                    label: 'إعدادات صوت التنبيهات',
                  ),
                  _DrawerTile(
                    path: '/settings/whatsapp-messages',
                    currentLocation: currentLocation,
                    icon: Icons.chat_rounded,
                    label: 'إعدادات رسائل واتساب',
                  ),
                  _DrawerTile(
                    path: '/technicians',
                    currentLocation: currentLocation,
                    icon: Icons.engineering_rounded,
                    label: 'الفنيون',
                  ),
                  _DrawerTile(
                    path: '/users',
                    currentLocation: currentLocation,
                    icon: Icons.manage_accounts_rounded,
                    label: 'المستخدمون والصلاحيات',
                  ),
                  _DrawerTile(
                    path: '/backup',
                    currentLocation: currentLocation,
                    icon: Icons.backup_rounded,
                    label: 'النسخ الاحتياطي',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String currentLocation;

  const _DrawerHeader({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ProShop',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  _activeSectionLabel(currentLocation),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _activeSectionLabel(String location) {
    if (location.startsWith('/warranty')) return 'سجل الضمانات الكامل';
    if (location.startsWith('/whatsapp')) return 'رسائل العملاء';
    if (location.startsWith('/settings')) return 'إعدادات التطبيق والمحل';
    return 'إدارة أجهزة الصيانة';
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  final String label;

  const _DrawerSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final String path;
  final String currentLocation;
  final IconData icon;
  final String label;
  final Color? accentColor;

  const _DrawerTile({
    required this.path,
    required this.currentLocation,
    required this.icon,
    required this.label,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selected = _isSelected(currentLocation, path);
    final effectiveColor = accentColor ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        selected: selected,
        dense: true,
        minLeadingWidth: 22,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedTileColor: effectiveColor.withValues(alpha: 0.12),
        leading: Icon(
          icon,
          color: selected ? effectiveColor : colors.textSecondary,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? effectiveColor : colors.textPrimary,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (!selected) context.go(path);
        },
      ),
    );
  }

  bool _isSelected(String location, String path) {
    if (path == '/repair-board') return location.startsWith(path);
    return location == path || location.startsWith('$path/');
  }
}

class _NotificationsDrawerTile extends StatelessWidget {
  final String currentLocation;

  const _NotificationsDrawerTile({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final count = state is NotificationsLoaded ? state.unreadCount : 0;
        return Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: [
            _DrawerTile(
              path: '/notifications',
              currentLocation: currentLocation,
              icon: Icons.notifications_active_rounded,
              label: 'التنبيهات',
              accentColor: AppColors.error,
            ),
            if (count > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.cairo(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeModeSwitchTile extends StatelessWidget {
  const _ThemeModeSwitchTile();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = themeMode == ThemeMode.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SwitchListTile(
            value: isDark,
            onChanged: (value) {
              if (value) {
                context.read<ThemeCubit>().setDark();
              } else {
                context.read<ThemeCubit>().setLight();
              }
            },
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            secondary: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? AppColors.primary : colors.textSecondary,
            ),
            title: Text(
              'الوضع الداكن',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
