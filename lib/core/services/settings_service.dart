import '../constants/app_constants.dart';
import '../database/database_service.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const defaultShopName = 'محل جوالات ProShop';
  static const defaultTrackingBaseUrl =
      'https://yasser-dev2024.github.io/mobail2026fixe/track/?ticket={ticket}';

  final DatabaseService _db = DatabaseService();

  // Cached settings in memory
  Map<String, String> _cache = {};
  bool _loaded = false;

  // ---------------------------------------------------------------------------
  // Field accessors (all read from cache with safe defaults)
  // ---------------------------------------------------------------------------

  String get shopName => _cache['shop_name'] ?? defaultShopName;
  String get shopPhone => _cache['shop_phone'] ?? '';
  String get shopPhone2 => _cache['shop_phone2'] ?? '';
  String get shopAddress => _cache['shop_address'] ?? '';
  String get shopEmail => _cache['shop_email'] ?? '';
  String get commercialRegister => _cache['commercial_register'] ?? '';
  String get taxNumber => _cache['tax_number'] ?? '';
  String get shopId => _cache['shop_id'] ?? 'default_shop';
  String get tradeName => _cache['trade_name'] ?? '';
  String get shopWhatsapp => _cache['shop_whatsapp'] ?? '';
  String get mapUrl => _cache['map_url'] ?? '';
  String get trackingBaseUrl {
    final value = (_cache['tracking_base_url'] ?? '').trim();
    if (value.isEmpty || _isUnsupportedTrackingUrl(value)) {
      return defaultTrackingBaseUrl;
    }
    return value;
  }

  String get privacyPolicyUrl {
    final value = (_cache['privacy_policy_url'] ?? '').trim();
    if (_isLegacyExternalUrl(value)) return '';
    return value;
  }

  String get privacyPolicyAcceptedVersion =>
      _cache['privacy_policy_accepted_version'] ?? '';
  double get taxRate => double.tryParse(_cache['tax_rate'] ?? '0') ?? 0;
  String get currency => _cache['currency'] ?? 'ر.س';
  String get warrantyTerms => _cache['warranty_terms'] ?? '';
  List<String> get deviceReceiverNames {
    final stored = _cache['device_receiver_names'] ?? '';
    final legacy = _cache['device_receiver_name'] ?? '';
    final names = <String>[
      ...stored.split('\n'),
      if (stored.trim().isEmpty) legacy,
    ]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return List.unmodifiable(names);
  }

  String get deviceReceiverName =>
      deviceReceiverNames.isEmpty ? '' : deviceReceiverNames.first;
  String get invoiceFooter => _cache['invoice_footer'] ?? '';
  String get invoiceIntroText => _cache['invoice_intro_text'] ?? '';
  String get invoiceGeneralTerms => _cache['invoice_general_terms'] ?? '';
  String get invoiceReturnPolicy => _cache['invoice_return_policy'] ?? '';
  String get invoiceLegalNotes => _cache['invoice_legal_notes'] ?? '';
  String get invoiceCopyright => _cache['invoice_copyright'] ?? '';
  String get invoiceMessageTemplate => _cache['invoice_message_template'] ?? '';
  String get invoicePrefix {
    final prefix = (_cache['invoice_prefix'] ?? 'INV').trim();
    return prefix.isEmpty ? 'INV' : prefix;
  }

  bool get invoiceResetYearly => _cache['invoice_reset_yearly'] != 'false';
  bool get invoiceIncludeIntakePhotos =>
      _cache['invoice_include_intake_photos'] != 'false';
  bool get invoiceShowSignature => _cache['invoice_show_signature'] != 'false';
  bool get autoBackup => _cache['auto_backup'] == 'true';
  bool get autoWhatsappSend => _cache['auto_whatsapp_send'] == 'true';
  bool get alertSoundsEnabled => _cache['alert_sounds_enabled'] != 'false';
  String get deviceStayAlertSoundPath =>
      _cache['device_stay_alert_sound_path'] ?? '';
  String get warrantyAlertSoundPath =>
      _cache['warranty_alert_sound_path'] ?? '';
  int get alertCheckIntervalMinutes {
    final minutes = int.tryParse(_cache['alert_check_interval_minutes'] ?? '');
    return (minutes == null || minutes <= 0) ? 30 : minutes;
  }

  double get alertVolume {
    final volume = double.tryParse(_cache['alert_volume'] ?? '');
    return (volume == null) ? 1.0 : volume.clamp(0.0, 1.0);
  }

  bool get alertVibrationEnabled =>
      _cache['alert_vibration_enabled'] != 'false';

  /// `0` or negative means "repeat until stopped".
  int get alertRepeatCount =>
      int.tryParse(_cache['alert_repeat_count'] ?? '') ?? 1;

  bool get whatsappMessageTypesMasterEnabled =>
      _cache['whatsapp_message_types_master_enabled'] != 'false';
  bool get shopSetupCompleted => _cache['shop_setup_completed'] == 'true';
  int get autoBackupInterval {
    final days = int.tryParse(_cache['auto_backup_interval'] ?? '') ??
        AppConstants.automaticBackupIntervalDays;
    return days < AppConstants.automaticBackupIntervalDays
        ? AppConstants.automaticBackupIntervalDays
        : days;
  }

  String get logoPath => _cache['logo_path'] ?? '';
  String get stampPath => _cache['stamp_path'] ?? '';
  String get signaturePath => _cache['signature_path'] ?? '';
  String get managerName => _cache['manager_name'] ?? '';
  String get managerTitle => _cache['manager_title'] ?? '';
  int get photoRequiredCount =>
      int.tryParse(_cache['photo_required_count'] ?? '0') ?? 0;
  int get photoMaxSizeMb =>
      int.tryParse(_cache['photo_max_size_mb'] ?? '10') ?? 10;
  int get photoQuality => int.tryParse(_cache['photo_quality'] ?? '85') ?? 85;
  bool get photoCompress => _cache['photo_compress'] != 'false';
  bool get photoKeepOriginal => _cache['photo_keep_original'] != 'false';
  bool get photoWatermarkReports => _cache['photo_watermark_reports'] == 'true';
  String get photoReportDefaultType =>
      _cache['photo_report_default_type'] ?? 'intake';
  int get photoReportImagesPerPage =>
      int.tryParse(_cache['photo_report_images_per_page'] ?? '4') ?? 4;
  bool get photoShowEmployee => _cache['photo_show_employee'] != 'false';
  bool get photoShowDateTime => _cache['photo_show_datetime'] != 'false';
  List<String> get photoRequiredTypes =>
      _lines(_cache['photo_required_types'] ?? '');
  List<String> get photoOptionalTypes {
    final values = _lines(_cache['photo_optional_types'] ?? '');
    return values.isEmpty ? AppConstants.defaultDevicePhotoTypes : values;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Loads all settings from the database into the in-memory cache.
  /// Subsequent accessor calls are served from cache until [reload] is called.
  Future<void> load() async {
    if (_loaded) return;
    _cache = await _db.getAllSettings();
    _loaded = true;
  }

  /// Persists each entry in [settings] to the database and updates the cache.
  Future<void> save(Map<String, String> settings) async {
    for (final entry in settings.entries) {
      await _db.setSetting(entry.key, entry.value);
      _cache[entry.key] = entry.value;
    }
  }

  /// Saves the one-time shop setup data and prevents showing the setup gate on
  /// later app launches.
  Future<void> completeShopSetup(Map<String, String> settings) async {
    await save({
      ...settings,
      'shop_setup_completed': 'true',
      'shop_setup_completed_at':
          DateTime.now().millisecondsSinceEpoch.toString(),
    });
  }

  /// Returns the value for [key].
  ///
  /// Served from cache when already loaded; falls back to a direct DB read
  /// otherwise (without marking the full cache as loaded).
  Future<String?> getSetting(String key) async {
    if (_loaded) return _cache[key];
    return _db.getSetting(key);
  }

  /// Writes [value] for [key] to both the database and the in-memory cache.
  Future<void> setSetting(String key, String value) async {
    await _db.setSetting(key, value);
    _cache[key] = value;
  }

  /// Invalidates the cache and reloads all settings from the database.
  Future<void> reload() async {
    _loaded = false;
    await load();
  }

  List<String> _lines(String value) {
    final seen = <String>{};
    return value
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((item) => seen.add(item))
        .toList(growable: false);
  }

  bool _isLegacyExternalUrl(String value) {
    final legacyHost = ['war', 'shati', 'app.com'].join();
    return value.toLowerCase().contains(legacyHost);
  }

  bool _isUnsupportedTrackingUrl(String value) {
    final lower = value.toLowerCase();
    return _isLegacyExternalUrl(lower) ||
        lower.contains('proshop.example.com') ||
        lower.startsWith('proshop://') ||
        lower.contains('proshop.local');
  }
}
