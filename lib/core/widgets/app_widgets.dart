import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Colors.white.withAlpha(220),
                fontWeight: FontWeight.w400,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.white.withAlpha(180),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: child,
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? color,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: colors.textSecondary.withAlpha(160),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.cairo(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.cairo(color: colors.textSecondary, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
          suffixIcon: onClear != null
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.clear_rounded, color: colors.textSecondary),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  const LoadingOverlay(
      {super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withAlpha(30),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.textSecondary),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: colors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'تأكيد',
    this.confirmColor,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'حذف',
    Color confirmColor = AppColors.error,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            confirmColor: confirmColor,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      content: Text(message, style: GoogleFonts.cairo()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('إلغاء', style: GoogleFonts.cairo()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppColors.error,
          ),
          child: Text(confirmLabel, style: GoogleFonts.cairo()),
        ),
      ],
    );
  }
}

class AppFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final Widget? suffix;
  final Widget? prefix;
  final bool required;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppFormField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffix,
    this.prefix,
    this.required = false,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
            children: required
                ? [
                    TextSpan(
                      text: ' *',
                      style: GoogleFonts.cairo(color: AppColors.error),
                    )
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            prefixIcon: prefix,
          ),
        ),
      ],
    );
  }
}
