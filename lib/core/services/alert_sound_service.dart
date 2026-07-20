import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

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
  StreamSubscription<void>? _repeatSub;

  Future<void> playDeviceStayAlert() => play(AlertSoundKind.deviceStay);

  Future<void> playWarrantyExpiringAlert() =>
      play(AlertSoundKind.warrantyExpiring);

  /// Routes an arbitrary notification `type` string to the right sound —
  /// used by [AlertMonitorService] so newly-added alert types automatically
  /// get a sound without needing a new [AlertSoundKind] case each time.
  Future<void> playForType(String type, {bool force = false}) {
    if (type.startsWith('warranty_')) {
      return play(AlertSoundKind.warrantyExpiring, force: force);
    }
    if (type == 'device_stay_two_days') {
      return play(AlertSoundKind.deviceStay, force: force);
    }
    // Generic fallback for future alert types — reuses the warranty asset
    // rather than requiring a brand-new bundled audio file.
    return play(AlertSoundKind.warrantyExpiring, force: force);
  }

  /// Stops any in-progress playback and cancels a pending manual-repeat
  /// sequence (used by "repeat until stopped"/"repeat N times").
  Future<void> stop() async {
    await _repeatSub?.cancel();
    _repeatSub = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> play(
    AlertSoundKind kind, {
    bool force = false,
    String? customPathOverride,
    double? volumeOverride,
    int? repeatCountOverride,
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
    final volume = volumeOverride ?? settings.alertVolume;
    final repeatCount = repeatCountOverride ?? settings.alertRepeatCount;
    final source = (customPath.isNotEmpty && File(customPath).existsSync())
        ? DeviceFileSource(customPath)
        : AssetSource(assetPath);

    await _repeatSub?.cancel();
    _repeatSub = null;

    try {
      await _player.stop();
      await _player.setVolume(volume);
      if (repeatCount <= 0) {
        // Repeat until explicitly stopped via AlertSoundService.stop().
        await _player.setReleaseMode(ReleaseMode.loop);
      } else {
        await _player.setReleaseMode(ReleaseMode.stop);
        if (repeatCount > 1) {
          var playsRemaining = repeatCount - 1;
          _repeatSub = _player.onPlayerComplete.listen((_) async {
            if (playsRemaining <= 0) {
              await _repeatSub?.cancel();
              _repeatSub = null;
              return;
            }
            playsRemaining--;
            try {
              await _player.play(source);
            } catch (_) {}
          });
        }
      }
      await _player.play(source);
      if (settings.alertVibrationEnabled) {
        try {
          await HapticFeedback.vibrate();
        } catch (_) {
          // Vibration isn't supported on every platform (e.g. desktop) —
          // never let it block sound/notification creation.
        }
      }
    } catch (_) {
      // Sound alerts should never block creating the actual notification.
    }
  }
}
