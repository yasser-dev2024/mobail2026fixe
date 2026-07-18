import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_service.dart';
import '../../../customers/data/customer_model.dart';
import '../../../customers/data/customers_repository.dart';
import '../../../auth/data/user_model.dart';
import '../../../devices/data/device_model.dart';
import '../../../devices/data/devices_repository.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../data/maintenance_model.dart';
import '../../data/maintenance_part_model.dart';
import '../../data/maintenance_repository.dart';
import '../cubit/maintenance_cubit.dart';
import '../../../auth/data/auth_repository.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final String? maintenanceId;
  final String? customerId;
  final String? deviceId;

  const MaintenanceFormScreen({
    super.key,
    this.maintenanceId,
    this.customerId,
    this.deviceId,
  });

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _faultCtrl = TextEditingController();
  final _laborCostCtrl = TextEditingController(text: '0');
  final _advanceCtrl = TextEditingController(text: '0');
  final _warrantyDaysCtrl = TextEditingController(text: '30');
  final _notesCtrl = TextEditingController();
  final _internalNotesCtrl = TextEditingController();
  final _partSearchCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  // State
  CustomerModel? _selectedCustomer;
  List<CustomerModel> _customerSuggestions = [];
  List<DeviceModel> _customerDevices = [];
  bool _loadingCustomers = false;
  bool _loadingCustomerDevices = false;

  List<UserModel> _technicians = [];
  UserModel? _selectedTechnician;

  String? _selectedDeviceId;
  String _selectedStatus = AppConstants.statusNew;
  String? _selectedWarrantyType;
  DateTime? _estimatedDelivery;
  int _expectedRepairDays = 2;

  final List<MaintenancePartModel> _parts = [];
  final List<_PendingIntakePhoto> _intakePhotos = [];

  bool _isLoading = false;
  bool _isEdit = false;
  MaintenanceModel? _existing;

  final _customersRepo = CustomersRepository();
  final _maintenanceRepo = MaintenanceRepository();
  final _devicesRepo = DevicesRepository();

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
    if (widget.maintenanceId != null) {
      _isEdit = true;
      _loadExisting();
    } else if (widget.customerId != null || widget.deviceId != null) {
      _loadPrefill();
    }
  }

  Future<void> _loadPrefill() async {
    if (widget.customerId != null) {
      final customer = await _customersRepo.getById(widget.customerId!);
      if (customer != null && mounted) {
        setState(() => _selectedCustomer = customer);
        await _loadCustomerDevices(customer.id);
      }
    }

    if (widget.deviceId != null) {
      final device = await _devicesRepo.getById(widget.deviceId!);
      if (device != null && mounted) {
        _selectDevice(device);

        if (_selectedCustomer == null) {
          final customer = await _customersRepo.getById(device.customerId);
          if (customer != null && mounted) {
            setState(() => _selectedCustomer = customer);
            await _loadCustomerDevices(customer.id);
          }
        }
      }
    }
  }

  Future<void> _loadCustomerDevices(String customerId) async {
    setState(() => _loadingCustomerDevices = true);
    final devices = await _devicesRepo.getByCustomer(customerId);
    if (!mounted) return;
    setState(() {
      _customerDevices = devices;
      _loadingCustomerDevices = false;
    });
  }

  Future<void> _selectCustomer(CustomerModel customer) async {
    setState(() {
      _selectedCustomer = customer;
      _selectedDeviceId = null;
      _customerDevices = [];
      if (!_isEdit) {
        _brandCtrl.clear();
        _modelCtrl.clear();
        _imeiCtrl.clear();
        _colorCtrl.clear();
      }
    });
    await _loadCustomerDevices(customer.id);
  }

  void _selectDevice(DeviceModel device) {
    setState(() {
      _selectedDeviceId = device.id;
      _brandCtrl.text = device.brand;
      _modelCtrl.text = device.model;
      _imeiCtrl.text = device.imei ?? '';
      _colorCtrl.text = device.color ?? '';
    });
  }

  void _selectNewDevice() {
    setState(() {
      _selectedDeviceId = null;
      _brandCtrl.clear();
      _modelCtrl.clear();
      _imeiCtrl.clear();
      _colorCtrl.clear();
    });
  }

  Future<void> _loadTechnicians() async {
    final db = DatabaseService();
    final rows = await db.query(
      'users',
      where: "role = ? AND is_active = 1 AND deleted_at IS NULL",
      whereArgs: [AppConstants.roleTechnician],
      orderBy: 'name ASC',
    );
    if (!mounted) return;
    setState(() {
      _technicians = rows.map(UserModel.fromMap).toList();
    });
  }

  Future<void> _loadExisting() async {
    final m = await _maintenanceRepo.getById(widget.maintenanceId!);
    if (m == null || !mounted) return;
    final parts = await _maintenanceRepo.getParts(m.id);
    setState(() {
      _existing = m;
      _selectedDeviceId = m.deviceId;
      _brandCtrl.text = m.brand;
      _modelCtrl.text = m.model;
      _imeiCtrl.text = m.imei ?? '';
      _colorCtrl.text = m.color ?? '';
      _faultCtrl.text = m.faultDescription;
      _laborCostCtrl.text = m.laborCost.toStringAsFixed(0);
      _advanceCtrl.text = m.advancePaid.toStringAsFixed(0);
      _notesCtrl.text = m.notes ?? '';
      _internalNotesCtrl.text = m.internalNotes ?? '';
      _selectedStatus = m.status;
      _selectedWarrantyType = m.warrantyType;
      _warrantyDaysCtrl.text = (m.warrantyDays ?? 30).toString();
      if (m.estimatedDelivery != null) {
        _estimatedDelivery =
            DateTime.fromMillisecondsSinceEpoch(m.estimatedDelivery!);
        final received = DateTime.fromMillisecondsSinceEpoch(m.receivedAt);
        _expectedRepairDays =
            _estimatedDelivery!.difference(received).inDays.clamp(1, 30);
      }
      if (m.technicianId != null) {
        _selectedTechnician =
            _technicians.where((t) => t.id == m.technicianId).firstOrNull;
      }
      _parts.addAll(parts);
    });

    // Load customer
    if (m.customerId.isNotEmpty) {
      final c = await _customersRepo.getById(m.customerId);
      if (c != null && mounted) {
        setState(() => _selectedCustomer = c);
        await _loadCustomerDevices(c.id);
      }
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.length < 2) {
      setState(() => _customerSuggestions = []);
      return;
    }
    setState(() => _loadingCustomers = true);
    final results = await _customersRepo.getAll(search: query);
    if (mounted) {
      setState(() {
        _customerSuggestions = results;
        _loadingCustomers = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار عميل', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final laborCost = double.tryParse(_laborCostCtrl.text) ?? 0;
      final advance = double.tryParse(_advanceCtrl.text) ?? 0;
      final partsCost = _parts.fold<double>(0, (s, p) => s + p.totalPrice);
      final warrantyDays = int.tryParse(_warrantyDaysCtrl.text);
      final deliveredAt = _selectedStatus == AppConstants.statusDelivered
          ? (_existing?.deliveredAt ?? DateTime.now().millisecondsSinceEpoch)
          : null;

      if (_isEdit && _existing != null) {
        final updated = _existing!.copyWith(
          brand: _brandCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          imei: _imeiCtrl.text.trim().isEmpty ? null : _imeiCtrl.text.trim(),
          color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          faultDescription: _faultCtrl.text.trim(),
          technicianId: _selectedTechnician?.id,
          deviceId: _selectedDeviceId,
          status: _selectedStatus,
          deliveredAt: deliveredAt,
          laborCost: laborCost,
          partsCost: partsCost,
          totalCost: laborCost + partsCost,
          advancePaid: advance,
          warrantyType: _selectedWarrantyType,
          warrantyDays: _selectedWarrantyType == AppConstants.warrantyCustom
              ? warrantyDays
              : null,
          estimatedDelivery: (_estimatedDelivery ??
                  DateTime.now().add(Duration(days: _expectedRepairDays)))
              .millisecondsSinceEpoch,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          internalNotes: _internalNotesCtrl.text.trim().isEmpty
              ? null
              : _internalNotesCtrl.text.trim(),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        if (mounted) {
          context.read<MaintenanceCubit>().update(updated);
        }
      } else {
        var deviceId = _selectedDeviceId;
        if (deviceId == null) {
          final device = DeviceModel.create(
            customerId: _selectedCustomer!.id,
            brand: _brandCtrl.text.trim(),
            model: _modelCtrl.text.trim(),
            imei: _imeiCtrl.text.trim().isEmpty ? null : _imeiCtrl.text.trim(),
            color:
                _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          );
          deviceId = await _devicesRepo.create(device);
        }

        final ticketNumber = await _maintenanceRepo.generateTicketNumber();
        final maintenance = MaintenanceModel.create(
          ticketNumber: ticketNumber,
          customerId: _selectedCustomer!.id,
          deviceId: deviceId,
          brand: _brandCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          imei: _imeiCtrl.text.trim().isEmpty ? null : _imeiCtrl.text.trim(),
          color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          faultDescription: _faultCtrl.text.trim(),
          technicianId: _selectedTechnician?.id,
          laborCost: laborCost,
          partsCost: partsCost,
          totalCost: laborCost + partsCost,
          advancePaid: advance,
          warrantyType: _selectedWarrantyType,
          warrantyDays: _selectedWarrantyType == AppConstants.warrantyCustom
              ? warrantyDays
              : null,
          estimatedDelivery: (_estimatedDelivery ??
                  DateTime.now().add(Duration(days: _expectedRepairDays)))
              .millisecondsSinceEpoch,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          internalNotes: _internalNotesCtrl.text.trim().isEmpty
              ? null
              : _internalNotesCtrl.text.trim(),
          createdBy: AuthRepository().getCurrentUser()?.id ?? 'user_admin',
        ).copyWith(status: _selectedStatus, deliveredAt: deliveredAt);
        if (mounted) {
          context.read<MaintenanceCubit>().create(
                maintenance,
                _parts,
                _intakePhotos.map((photo) => photo.path).toList(),
              );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _imeiCtrl.dispose();
    _colorCtrl.dispose();
    _faultCtrl.dispose();
    _laborCostCtrl.dispose();
    _advanceCtrl.dispose();
    _warrantyDaysCtrl.dispose();
    _notesCtrl.dispose();
    _internalNotesCtrl.dispose();
    _partSearchCtrl.dispose();
    super.dispose();
  }

  void _cancel() {
    if (widget.deviceId != null) {
      context.go('/devices/${widget.deviceId}');
      return;
    }
    context.go('/maintenance');
  }

  Future<void> _captureIntakePhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (file == null) return;
      _addIntakePhoto(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر فتح الكاميرا: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickIntakePhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
    );
    final paths = result?.files
            .map((file) => file.path)
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    for (final path in paths) {
      _addIntakePhoto(path);
    }
  }

  void _addIntakePhoto(String path) {
    if (_intakePhotos.any((photo) => photo.path == path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هذه الصورة مضافة بالفعل', style: GoogleFonts.cairo()),
        ),
      );
      return;
    }
    setState(() => _intakePhotos.add(_PendingIntakePhoto(path: path)));
  }

  void _removeIntakePhoto(int index) {
    setState(() => _intakePhotos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocListener<MaintenanceCubit, MaintenanceState>(
      listener: (context, state) {
        if (state is MaintenanceSaved) {
          context.read<NotificationsCubit>().loadNotifications();
          // Always go to maintenance detail so the user sees the QR + print label
          // justCreated=1 triggers the print-label prompt dialog
          final suffix = _isEdit ? '' : '?justCreated=1';
          context.go('/maintenance/${state.id}$suffix');
        }
        if (state is MaintenanceError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(
            _isEdit ? 'تعديل بيانات الجهاز' : 'استلام جهاز جديد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: _cancel,
          ),
          actions: [
            if (_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ))
            else
              TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, color: AppColors.primary),
                label: Text(
                  _isEdit ? 'حفظ' : 'حفظ واستلام',
                  style: GoogleFonts.cairo(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isEdit ? 'حفظ التعديلات' : 'حفظ واستلام الجهاز',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _cancel,
                  icon: const Icon(Icons.close_rounded),
                  label: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Customer ──────────────────────────────────────────────────
              _FormSection(
                title: 'بيانات العميل',
                child: Column(
                  children: [
                    // Autocomplete customer search
                    Autocomplete<CustomerModel>(
                      displayStringForOption: (c) => '${c.name} - ${c.phone}',
                      optionsBuilder: (v) async {
                        await _searchCustomers(v.text);
                        return _customerSuggestions;
                      },
                      onSelected: (c) {
                        _selectCustomer(c);
                      },
                      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                        if (_selectedCustomer != null && ctrl.text.isEmpty) {
                          ctrl.text =
                              '${_selectedCustomer!.name} - ${_selectedCustomer!.phone}';
                        }
                        return TextFormField(
                          controller: ctrl,
                          focusNode: focusNode,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'اسم العميل أو رقم الهاتف',
                            labelStyle: GoogleFonts.cairo(),
                            prefixIcon: const Icon(Icons.person_search_rounded),
                            suffixIcon: _loadingCustomers
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ))
                                : null,
                          ),
                          onChanged: (value) {
                            final selectedLabel = _selectedCustomer == null
                                ? ''
                                : '${_selectedCustomer!.name} - ${_selectedCustomer!.phone}';
                            if (_selectedCustomer != null &&
                                value.trim() != selectedLabel) {
                              setState(() {
                                _selectedCustomer = null;
                                _selectedDeviceId = null;
                                _customerDevices = [];
                              });
                            }
                          },
                          validator: (_) => _selectedCustomer == null
                              ? 'يرجى اختيار عميل'
                              : null,
                        );
                      },
                      optionsViewBuilder: (ctx, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (ctx, i) {
                                  final c = options.elementAt(i);
                                  return ListTile(
                                    leading: const Icon(Icons.person_rounded,
                                        color: AppColors.primary),
                                    title: Text(c.name,
                                        style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(c.phone,
                                        style: GoogleFonts.cairo(fontSize: 12)),
                                    onTap: () => onSelected(c),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  await context.push('/customers/new');
                                },
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text('إضافة عميل جديد',
                              style: GoogleFonts.cairo()),
                        ),
                        if (_selectedCustomer != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => context
                                .push('/customers/${_selectedCustomer!.id}'),
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text('فتح ملف العميل',
                                style: GoogleFonts.cairo()),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Device ────────────────────────────────────────────────────
              _FormSection(
                title: 'بيانات الجهاز',
                child: Column(
                  children: [
                    if (!_isEdit) ...[
                      _CustomerDevicePicker(
                        selectedCustomer: _selectedCustomer,
                        devices: _customerDevices,
                        selectedDeviceId: _selectedDeviceId,
                        loading: _loadingCustomerDevices,
                        onSelectDevice: _selectDevice,
                        onNewDevice: _selectNewDevice,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _brandCtrl,
                            label: 'الماركة',
                            icon: Icons.phone_android_rounded,
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _modelCtrl,
                            label: 'الموديل',
                            icon: Icons.devices_rounded,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _imeiCtrl,
                            label: 'رقم IMEI',
                            icon: Icons.numbers_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _colorCtrl,
                            label: 'اللون',
                            icon: Icons.color_lens_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _FormSection(
                title: 'تصوير حالة الجهاز عند الاستلام',
                child: _IntakePhotoCapturePanel(
                  photos: _intakePhotos,
                  onCamera: _captureIntakePhoto,
                  onPick: _pickIntakePhotos,
                  onRemove: _removeIntakePhoto,
                ),
              ),

              const SizedBox(height: 12),

              // ── Fault description ─────────────────────────────────────────
              _FormSection(
                title: 'المشكلة والوصف',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _faultCtrl,
                      textDirection: TextDirection.rtl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'وصف المشكلة *',
                        labelStyle: GoogleFonts.cairo(),
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.report_problem_rounded),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'يرجى وصف المشكلة'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesCtrl,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        labelStyle: GoogleFonts.cairo(),
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 28),
                          child: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _internalNotesCtrl,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات داخلية',
                        labelStyle: GoogleFonts.cairo(),
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 28),
                          child: Icon(Icons.lock_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Technician & warranty ─────────────────────────────────────
              _FormSection(
                title: 'الفني والضمان',
                child: Column(
                  children: [
                    // Technician dropdown
                    DropdownButtonFormField<UserModel>(
                      value: _selectedTechnician,
                      decoration: InputDecoration(
                        labelText: 'الفني المسؤول',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.engineering_rounded),
                      ),
                      hint: Text('اختر فني', style: GoogleFonts.cairo()),
                      items: _technicians
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name, style: GoogleFonts.cairo()),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTechnician = v),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fact_check_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isEdit
                                  ? 'حالة الجهاز الحالية: ${AppConstants.maintenanceStageLabel(_selectedStatus)}'
                                  : 'بعد الحفظ سيظهر الجهاز تلقائياً ضمن أجهزة بانتظار الصيانة',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w600,
                                color: context.appColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Warranty type dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedWarrantyType,
                      decoration: InputDecoration(
                        labelText: 'نوع الضمان',
                        labelStyle: GoogleFonts.cairo(),
                        prefixIcon: const Icon(Icons.verified_user_rounded),
                      ),
                      hint: Text('بدون ضمان', style: GoogleFonts.cairo()),
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
                            child: Text('سنة كاملة')),
                        DropdownMenuItem(
                            value: AppConstants.warranty2Years,
                            child: Text('سنتين')),
                        DropdownMenuItem(
                            value: AppConstants.warrantyCustom,
                            child: Text('مخصص')),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedWarrantyType = v),
                    ),

                    if (_selectedWarrantyType == AppConstants.warrantyCustom)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextFormField(
                          controller: _warrantyDaysCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'مدة الضمان المخصص',
                            labelStyle: GoogleFonts.cairo(),
                            prefixIcon: const Icon(Icons.timelapse_rounded),
                            suffixText: 'يوم',
                          ),
                          validator: (v) {
                            if (_selectedWarrantyType !=
                                AppConstants.warrantyCustom) {
                              return null;
                            }
                            final days = int.tryParse(v ?? '');
                            if (!AppConstants.isValidWarrantyDays(days)) {
                              return 'حدد مدة الضمان من يوم واحد إلى سنتين.';
                            }
                            return null;
                          },
                        ),
                      ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مدة الصيانة المتوقعة (أساس التنبيه)',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              color: context.appColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'يتكرر التنبيه يومياً بعد تجاوز المدة حتى إغلاق طلب الصيانة.',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: context.appColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            value: _expectedRepairDays,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'المدة المتوقعة',
                              prefixIcon: const Icon(Icons.timer_outlined),
                              suffixText: 'يوم',
                              labelStyle: GoogleFonts.cairo(),
                            ),
                            items: List.generate(30, (index) => index + 1)
                                .map((days) => DropdownMenuItem(
                                      value: days,
                                      child: Text(
                                        days == 1 ? 'يوم واحد' : '$days أيام',
                                        style: GoogleFonts.cairo(),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (days) {
                              if (days == null) return;
                              setState(() {
                                _expectedRepairDays = days;
                                final base = _existing == null
                                    ? DateTime.now()
                                    : DateTime.fromMillisecondsSinceEpoch(
                                        _existing!.receivedAt);
                                _estimatedDelivery =
                                    base.add(Duration(days: days));
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            final date = _estimatedDelivery ??
                                DateTime.now().add(
                                  Duration(days: _expectedRepairDays),
                                );
                            return Text(
                              'موعد التنبيه: ${date.day}/${date.month}/${date.year}',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Cost ──────────────────────────────────────────────────────
              _FormSection(
                title: 'التكلفة والدفعة',
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _laborCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'أجرة الصيانة',
                          labelStyle: GoogleFonts.cairo(),
                          prefixIcon: const Icon(Icons.build_rounded),
                          suffixText: 'ر.س',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _advanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'المبلغ المقدم',
                          labelStyle: GoogleFonts.cairo(),
                          prefixIcon: const Icon(Icons.payments_rounded),
                          suffixText: 'ر.س',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Parts ─────────────────────────────────────────────────────
              _FormSection(
                title: 'القطع المستخدمة',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add part row
                    _AddPartInline(
                      onAdd: (part) {
                        setState(() => _parts.add(part));
                      },
                      tempMaintenanceId: 'temp',
                    ),
                    const SizedBox(height: 12),
                    // Parts list
                    if (_parts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد قطع مضافة',
                            style: GoogleFonts.cairo(
                                color: context.appColors.textSecondary)),
                      )
                    else
                      Column(
                        children: _parts.asMap().entries.map((e) {
                          final p = e.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.build_circle_rounded,
                                color: AppColors.primary, size: 18),
                            title: Text(p.productName,
                                style: GoogleFonts.cairo(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${p.quantity.toStringAsFixed(0)} × ${p.unitPrice.toStringAsFixed(2)} ر.س',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p.totalPrice.toStringAsFixed(2)} ر.س',
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () =>
                                      setState(() => _parts.removeAt(e.key)),
                                  child: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 18,
                                      color: AppColors.error),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    if (_parts.isNotEmpty) ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('إجمالي القطع: ',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w600)),
                          Text(
                            '${_parts.fold<double>(0, (s, p) => s + p.totalPrice).toStringAsFixed(2)} ر.س',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intake photos
// ─────────────────────────────────────────────────────────────────────────────

class _PendingIntakePhoto {
  final String path;

  const _PendingIntakePhoto({required this.path});
}

class _IntakePhotoCapturePanel extends StatelessWidget {
  final List<_PendingIntakePhoto> photos;
  final VoidCallback onCamera;
  final VoidCallback onPick;
  final void Function(int index) onRemove;

  const _IntakePhotoCapturePanel({
    required this.photos,
    required this.onCamera,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'التقط صور الواجهة، الخلفية، الشاشة، الخدوش، والملحقات عند الحاجة.',
                  style: GoogleFonts.cairo(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${photos.length} صورة',
                  style: GoogleFonts.cairo(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(
                'فتح الكاميرا والتقاط الصور',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                'إضافة صور من المعرض أو الملفات',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (photos.isEmpty)
          Text(
            'لا توجد صور بعد. يمكن إكمال الاستلام الآن، وسيتم حفظ أي صور مضافة داخل ملف العميل والجهاز والصيانة.',
            style: GoogleFonts.cairo(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              mainAxisExtent: 150,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final exists = File(photo.path).existsSync();
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    exists
                        ? Image.file(File(photo.path), fit: BoxFit.cover)
                        : Container(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(Icons.broken_image_rounded),
                          ),
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: IconButton.filledTonal(
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add part inline
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerDevicePicker extends StatelessWidget {
  final CustomerModel? selectedCustomer;
  final List<DeviceModel> devices;
  final String? selectedDeviceId;
  final bool loading;
  final void Function(DeviceModel device) onSelectDevice;
  final VoidCallback onNewDevice;

  const _CustomerDevicePicker({
    required this.selectedCustomer,
    required this.devices,
    required this.selectedDeviceId,
    required this.loading,
    required this.onSelectDevice,
    required this.onNewDevice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (selectedCustomer == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'اختر العميل أولاً لعرض الجوالات السابقة أو تسجيل جوال جديد له',
                style: GoogleFonts.cairo(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الجوالات السابقة للعميل',
                style: GoogleFonts.cairo(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onNewDevice,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('جوال جديد', style: GoogleFonts.cairo()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _DeviceChoiceTile(
          title: 'تسجيل جوال جديد لهذا العميل',
          subtitle: 'اكتب الماركة والموديل وسيضاف تلقائياً إلى ملف العميل',
          icon: Icons.add_circle_outline_rounded,
          selected: selectedDeviceId == null,
          onTap: onNewDevice,
        ),
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'لا توجد أجهزة سابقة لهذا العميل',
              style: GoogleFonts.cairo(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          )
        else
          ...devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _DeviceChoiceTile(
                title: device.displayName,
                subtitle: [
                  if (device.imei?.trim().isNotEmpty == true)
                    'IMEI: ${device.imei}',
                  if (device.color?.trim().isNotEmpty == true) device.color,
                  if (device.storage?.trim().isNotEmpty == true) device.storage,
                ].whereType<String>().join(' - '),
                icon: Icons.phone_android_rounded,
                selected: selectedDeviceId == device.id,
                onTap: () => onSelectDevice(device),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeviceChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DeviceChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = selected ? AppColors.primary : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.45)
                : colors.border,
          ),
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
                    style: GoogleFonts.cairo(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPartInline extends StatefulWidget {
  final void Function(MaintenancePartModel) onAdd;
  final String tempMaintenanceId;

  const _AddPartInline({required this.onAdd, required this.tempMaintenanceId});

  @override
  State<_AddPartInline> createState() => _AddPartInlineState();
}

class _AddPartInlineState extends State<_AddPartInline> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: 'اسم القطعة',
              labelStyle: GoogleFonts.cairo(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'كمية',
              labelStyle: GoogleFonts.cairo(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'سعر',
              labelStyle: GoogleFonts.cairo(),
              suffixText: 'ر.س',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final qty = double.tryParse(_qtyCtrl.text) ?? 1;
            final price = double.tryParse(_priceCtrl.text) ?? 0;
            final part = MaintenancePartModel.create(
              maintenanceId: widget.tempMaintenanceId,
              productName: name,
              quantity: qty,
              unitPrice: price,
            );
            widget.onAdd(part);
            _nameCtrl.clear();
            _qtyCtrl.text = '1';
            _priceCtrl.clear();
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormSection({required this.title, required this.child});

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
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textDirection: TextDirection.rtl,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: GoogleFonts.cairo(),
        prefixIcon: Icon(icon),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }
}
