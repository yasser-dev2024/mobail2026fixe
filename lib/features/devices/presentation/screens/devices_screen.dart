import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/device_model.dart';
import '../cubit/devices_cubit.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _searchText {
    final value = _searchCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  void _reloadDevices(BuildContext context) {
    context.read<DevicesCubit>().loadAll(search: _searchText);
  }

  Future<void> _confirmDeleteDevice(
    BuildContext context,
    DeviceModel device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'حذف الجوال؟',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.phone_disabled_rounded,
                    color: AppColors.error,
                  ),
                ),
                title: Text(
                  device.displayName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  device.imei?.trim().isNotEmpty == true
                      ? 'IMEI: ${device.imei}'
                      : 'بدون IMEI',
                  style: GoogleFonts.cairo(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم إخفاء الجوال من القوائم، مع بقاء سجلات الصيانة السابقة محفوظة.',
                style: GoogleFonts.cairo(
                  color: AppColors.lightTextSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_rounded),
            label: Text(
              'حذف الجوال',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<DevicesCubit>().deleteDevice(
            device.id,
            search: _searchText,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الجوال', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الجوال', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DevicesCubit()..loadAll(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'الأجهزة',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: AppColors.lightText,
                fontSize: 18,
              ),
            ),
          ),
          body: BlocBuilder<DevicesCubit, DevicesState>(
            builder: (ctx, state) {
              return Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'بحث بالماركة أو الموديل أو IMEI...',
                        hintStyle: GoogleFonts.cairo(
                          color: AppColors.lightTextSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.primary, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ctx.read<DevicesCubit>().loadAll();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.lightBackground,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.lightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.lightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {});
                        ctx.read<DevicesCubit>().loadAll(
                              search: v.isEmpty ? null : v,
                            );
                      },
                    ),
                  ),
                  Expanded(
                    child: switch (state) {
                      DevicesLoading() =>
                        const Center(child: CircularProgressIndicator()),
                      DevicesError(:final message) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 48),
                              const SizedBox(height: 12),
                              Text(message,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.error)),
                            ],
                          ),
                        ),
                      DevicesLoaded(:final devices) when devices.isEmpty =>
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_android_outlined,
                                size: 64,
                                color: AppColors.lightTextSecondary
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لا يوجد أجهزة',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      DevicesLoaded(:final devices) => ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _DeviceCard(
                            device: devices[i],
                            onOpen: () async {
                              final changed = await ctx.push<bool>(
                                '/devices/${devices[i].id}',
                              );
                              if (changed == true && ctx.mounted) {
                                _reloadDevices(ctx);
                              }
                            },
                            onDelete: () =>
                                _confirmDeleteDevice(ctx, devices[i]),
                          ),
                        ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DeviceCard({
    required this.device,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_android_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.lightText,
                      ),
                    ),
                    if (device.imei != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.fingerprint,
                              size: 13, color: AppColors.lightTextSecondary),
                          const SizedBox(width: 3),
                          Text(
                            device.imei!,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (device.color != null)
                          _Chip(
                              label: device.color!,
                              icon: Icons.palette_outlined),
                        if (device.storage != null)
                          _Chip(
                              label: device.storage!,
                              icon: Icons.storage_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف الجوال',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
