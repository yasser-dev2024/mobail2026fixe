import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocConsumer<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                context.go('/repair-board');
              }
            },
            builder: (context, state) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        elevation: 24,
                        shadowColor: Colors.black38,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 48,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.asset(
                                    'assets/images/app_logo.png',
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'ProShop',
                                  style: GoogleFonts.cairo(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'نظام إدارة محل الجوالات',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: AppColors.lightTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // Error / Locked banners
                                if (state is AuthError) ...[
                                  _ErrorBanner(message: state.message),
                                  const SizedBox(height: 16),
                                ],
                                if (state is AuthLocked) ...[
                                  _ErrorBanner(
                                    message:
                                        'تم قفل الحساب. يرجى الانتظار ${state.minutes} دقيقة.',
                                    icon: Icons.lock_outline,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Username
                                TextFormField(
                                  controller: _usernameController,
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.cairo(fontSize: 15),
                                  decoration: _inputDecoration(
                                    label: 'اسم المستخدم',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'يرجى إدخال اسم المستخدم'
                                          : null,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.cairo(fontSize: 15),
                                  decoration: _inputDecoration(
                                    label: 'كلمة المرور',
                                    icon: Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'يرجى إدخال كلمة المرور'
                                      : null,
                                  onFieldSubmitted: (_) => _submit(context),
                                ),
                                const SizedBox(height: 32),

                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: state is AuthLoading
                                          ? null
                                          : () => _submit(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: state is AuthLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Text(
                                              'تسجيل الدخول',
                                              style: GoogleFonts.cairo(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: AppColors.lightTextSecondary),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: AppColors.lightBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const _ErrorBanner({
    required this.message,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
