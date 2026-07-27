import 'package:flutter/material.dart';

import '../../../../core/services/alert_sound_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/widgets/app_widgets.dart';

const _intervalChoices = [15, 30, 60];

class AlertSoundSettingsScreen extends StatefulWidget {
  const AlertSoundSettingsScreen({super.key});

  @override
  State<AlertSoundSettingsScreen> createState() =>
      _AlertSoundSettingsScreenState();
}

class _AlertSoundSettingsScreenState extends State<AlertSoundSettingsScreen> {
  final _service = SettingsService();
  final _customIntervalCtrl = TextEditingController();
  final _repeatCountCtrl = TextEditingController();

  bool _alertSoundsEnabled = true;
  bool _vibrationEnabled = true;
  double _volume = 1.0;
  int _intervalMinutes = 30;
  bool _repeatUntilStopped = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customIntervalCtrl.dispose();
    _repeatCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _service.reload();
    _alertSoundsEnabled = _service.alertSoundsEnabled;
    _vibrationEnabled = _service.alertVibrationEnabled;
    _volume = _service.alertVolume;
    _intervalMinutes = _service.alertCheckIntervalMinutes;
    if (!_intervalChoices.contains(_intervalMinutes)) {
      _customIntervalCtrl.text = _intervalMinutes.toString();
    }
    final repeatCount = _service.alertRepeatCount;
    _repeatUntilStopped = repeatCount <= 0;
    _repeatCountCtrl.text = _repeatUntilStopped ? '3' : repeatCount.toString();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final interval = _intervalChoices.contains(_intervalMinutes)
        ? _intervalMinutes
        : (int.tryParse(_customIntervalCtrl.text.trim()) ?? 30);
    final repeatCount = _repeatUntilStopped
        ? 0
        : (int.tryParse(_repeatCountCtrl.text.trim()) ?? 1).clamp(1, 20);
    await _service.save({
      'alert_sounds_enabled': _alertSoundsEnabled ? 'true' : 'false',
      // Keep legacy values empty so older app versions also fall back to the
      // two approved sounds bundled with the application.
      'device_stay_alert_sound_path': '',
      'warranty_alert_sound_path': '',
      'alert_vibration_enabled': _vibrationEnabled ? 'true' : 'false',
      'alert_volume': _volume.toString(),
      'alert_check_interval_minutes': interval.toString(),
      'alert_repeat_count': repeatCount.toString(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ إعدادات التنبيهات'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _testAlertSound(AlertSoundKind kind) async {
    await AlertSoundService().play(
      kind,
      force: true,
      volumeOverride: _volume,
      repeatCountOverride: _repeatUntilStopped ? 0 : 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('إعدادات صوت التنبيهات')),
      body: LoadingOverlay(
        isLoading: _loading,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildMasterSection(colors),
            const SizedBox(height: 16),
            _buildDefaultSound(
              label: 'الصوت 1 — الصيانة المتأخرة وبقاء الجوال في المحل',
              assetLabel: '1.mp3',
              kind: AlertSoundKind.deviceStay,
              colors: colors,
            ),
            const SizedBox(height: 12),
            _buildDefaultSound(
              label: 'الصوت 2 — الضمان المنتهي أو القريب من الانتهاء',
              assetLabel: '2.mp3',
              kind: AlertSoundKind.warrantyExpiring,
              colors: colors,
            ),
            const SizedBox(height: 16),
            _buildIntervalSection(colors),
            const SizedBox(height: 16),
            _buildRepeatSection(colors),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSection(AppColorsExtension colors) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تفعيل أصوات التنبيهات',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch(
                value: _alertSoundsEnabled,
                activeColor: AppColors.warning,
                onChanged: (value) =>
                    setState(() => _alertSoundsEnabled = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('مستوى الصوت', style: TextStyle(color: colors.textSecondary)),
          Slider(
            value: _volume,
            onChanged: (value) => setState(() => _volume = value),
            label: '${(_volume * 100).round()}%',
            divisions: 20,
          ),
          if (!AppPlatform.isDesktop)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الاهتزاز مع التنبيه'),
              value: _vibrationEnabled,
              activeColor: AppColors.warning,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
            ),
        ],
      ),
    );
  }

  Widget _buildIntervalSection(AppColorsExtension colors) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فترة فحص التنبيهات المتكررة',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'إذا لم تتم معالجة التنبيه، سيُعاد تشغيله وعرضه كل هذه المدة حتى يتم تأجيله أو إيقافه.',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in _intervalChoices)
                ChoiceChip(
                  label: Text('$minutes دقيقة'),
                  selected: _intervalMinutes == minutes,
                  onSelected: (_) => setState(() => _intervalMinutes = minutes),
                ),
              ChoiceChip(
                label: const Text('مخصص'),
                selected: !_intervalChoices.contains(_intervalMinutes),
                onSelected: (_) => setState(() => _intervalMinutes = -1),
              ),
            ],
          ),
          if (!_intervalChoices.contains(_intervalMinutes)) ...[
            const SizedBox(height: 10),
            AppFormField(
              label: 'عدد الدقائق',
              controller: _customIntervalCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatSection(AppColorsExtension colors) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'عدد مرات تكرار الصوت عند كل تنبيه',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تكرار حتى الإيقاف'),
            subtitle: const Text('يستمر الصوت في التكرار حتى تفتح التنبيه'),
            value: _repeatUntilStopped,
            activeColor: AppColors.warning,
            onChanged: (value) => setState(() => _repeatUntilStopped = value),
          ),
          if (!_repeatUntilStopped)
            AppFormField(
              label: 'عدد مرات التكرار',
              controller: _repeatCountCtrl,
              keyboardType: TextInputType.number,
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultSound({
    required String label,
    required String assetLabel,
    required AlertSoundKind kind,
    required AppColorsExtension colors,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$assetLabel — صوت افتراضي ثابت ومعتمد داخل التطبيق',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _testAlertSound(kind),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('تجربة الصوت'),
            ),
          ),
        ],
      ),
    );
  }
}
