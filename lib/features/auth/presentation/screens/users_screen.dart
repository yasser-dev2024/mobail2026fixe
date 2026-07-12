import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_service.dart';
import '../../data/auth_repository.dart';
import '../../data/user_model.dart';
import '../cubit/auth_cubit.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _repo = AuthRepository();
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await _repo.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleOwner:
        return AppColors.primary;
      case AppConstants.roleManager:
        return AppColors.secondary;
      case AppConstants.roleBranchManager:
        return AppColors.info;
      case AppConstants.roleCashier:
        return AppColors.success;
      case AppConstants.roleTechnician:
        return AppColors.warning;
      case AppConstants.roleReceptionist:
        return AppColors.info;
      case AppConstants.roleAccountant:
        return AppColors.warning;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  Future<void> _showUserDialog({UserModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final usernameCtrl = TextEditingController(text: existing?.username ?? '');
    final passwordCtrl = TextEditingController();
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String selectedRole = existing?.role ?? AppConstants.roleCashier;
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existing == null ? 'إضافة مستخدم جديد' : 'تعديل المستخدم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(
                          nameCtrl, 'الاسم الكامل', Icons.person_outline,
                          required: true),
                      const SizedBox(height: 12),
                      _dialogField(
                          usernameCtrl, 'اسم المستخدم', Icons.alternate_email,
                          required: true, enabled: existing == null),
                      const SizedBox(height: 12),
                      if (existing == null) ...[
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscure,
                          style: GoogleFonts.cairo(),
                          decoration: _fieldDecoration(
                                  'كلمة المرور', Icons.lock_outline)
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setDialogState(() => obscure = !obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'يجب أن تكون 6 أحرف على الأقل'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _dialogField(
                          emailCtrl, 'البريد الإلكتروني', Icons.email_outlined),
                      const SizedBox(height: 12),
                      _dialogField(phoneCtrl, 'الجوال', Icons.phone_outlined),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration:
                            _fieldDecoration('الصلاحية', Icons.shield_outlined),
                        style: GoogleFonts.cairo(
                            color: AppColors.lightText, fontSize: 14),
                        items: [
                          AppConstants.roleOwner,
                          AppConstants.roleManager,
                          AppConstants.roleBranchManager,
                          AppConstants.roleCashier,
                          AppConstants.roleTechnician,
                          AppConstants.roleReceptionist,
                          AppConstants.roleAccountant,
                        ]
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(_roleLabel(r),
                                      style: GoogleFonts.cairo()),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedRole = v!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء',
                    style:
                        GoogleFonts.cairo(color: AppColors.lightTextSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (existing == null) {
                    final hash =
                        DatabaseService.hashPassword(passwordCtrl.text);
                    final user = UserModel.create(
                      name: nameCtrl.text.trim(),
                      username: usernameCtrl.text.trim(),
                      passwordHash: hash,
                      role: selectedRole,
                      email: emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                    );
                    await _repo.createUser(user);
                  } else {
                    final updated = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      role: selectedRole,
                      email: emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await _repo.updateUser(updated);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadUsers();
                },
                child: Text('حفظ',
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(UserModel user) async {
    final updated = user.copyWith(
      isActive: !user.isActive,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.updateUser(updated);
    await _loadUsers();
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      style: GoogleFonts.cairo(fontSize: 14),
      decoration: _fieldDecoration(label, icon),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.cairo(color: AppColors.lightTextSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.lightBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppConstants.roleOwner:
        return 'مالك';
      case AppConstants.roleManager:
        return 'مدير';
      case AppConstants.roleBranchManager:
        return 'مدير فرع';
      case AppConstants.roleCashier:
        return 'كاشير';
      case AppConstants.roleTechnician:
        return 'فني';
      case AppConstants.roleReceptionist:
        return 'موظف استقبال';
      case AppConstants.roleAccountant:
        return 'محاسب';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthCubit?>()?.state;
    final isOwner = currentUser is AuthAuthenticated &&
        currentUser.user.role == AppConstants.roleOwner;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'إدارة المستخدمين',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              color: AppColors.lightText,
              fontSize: 18,
            ),
          ),
          actions: [
            if (isOwner)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text('مستخدم جديد',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showUserDialog(),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? Center(
                    child: Text(
                      'لا يوجد مستخدمون',
                      style: GoogleFonts.cairo(
                          color: AppColors.lightTextSecondary, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final user = _users[i];
                      final color = _roleColor(user.role);
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Text(
                              user.name.isNotEmpty ? user.name[0] : '?',
                              style: GoogleFonts.cairo(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${user.username}',
                                style: GoogleFonts.cairo(
                                    color: AppColors.lightTextSecondary,
                                    fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _roleLabel(user.role),
                                  style: GoogleFonts.cairo(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: isOwner
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: user.isActive,
                                      activeColor: AppColors.success,
                                      onChanged: (_) => _toggleActive(user),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: AppColors.primary),
                                      onPressed: () =>
                                          _showUserDialog(existing: user),
                                    ),
                                  ],
                                )
                              : Icon(
                                  user.isActive
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                                  color: user.isActive
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
