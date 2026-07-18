import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

enum AlertSoundKind {
  deviceStay,
  warrantyExpiring,
}

class AlertSoundService {
  static final AlertSoundService _instance = AlertSoundService._internal();
  factory AlertSoundService() => _instance;
  AlertSoundService._internal();

  static const defaultDeviceStayAsset = 'sounds/device_stay_two_days.mp3';
  static const defaultWarrantyExpiringAsset = 'sounds/warranty_expiring.mp3';

  final AudioPlayer _player = AudioPlayer(playerId: 'proshop_alert_sounds');

  Future<void> playDeviceStayAlert() => play(AlertSoundKind.deviceStay);

  Future<void> playWarrantyExpiringAlert() =>
      play(AlertSoundKind.warrantyExpiring);

  Future<void> play(
    AlertSoundKind kind, {
    bool force = false,
    String? customPathOverride,
  }) async {
    final settings = SettingsService();
    await settings.load();
    if (!force && !settings.alertSoundsEnabled) return;

    final customPath = customPathOverride?.trim() ??
        switch (kind) {
          AlertSoundKind.deviceStay => settings.deviceStayAlertSoundPath,
          AlertSoundKind.warrantyExpiring => settings.warrantyAlertSoundPath,
        };
    final assetPath = switch (kind) {
      AlertSoundKind.deviceStay => defaultDeviceStayAsset,
      AlertSoundKind.warrantyExpiring => defaultWarrantyExpiringAsset,
    };

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      if (customPath.isNotEmpty && File(customPath).existsSync()) {
        await _player.play(DeviceFileSource(customPath));
      } else {
        await _player.play(AssetSource(assetPath));
      }
    } catch (_) {
      // Sound alerts should never block creating the actual notification.
    }
  }
}
