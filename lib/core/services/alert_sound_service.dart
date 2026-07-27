import 'dart:async';

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

  static const defaultDeviceStayAsset = 'sounds/1.mp3';
  static const defaultWarrantyExpiringAsset = 'sounds/2.mp3';

  final AudioPlayer _player = AudioPlayer(playerId: 'proshop_alert_sounds');
  StreamSubscription<void>? _repeatSub;

  Future<void> playDeviceStayAlert() => play(AlertSoundKind.deviceStay);

  Future<void> playWarrantyExpiringAlert() =>
      play(AlertSoundKind.warrantyExpiring);

  static AlertSoundKind? kindForType(String type) {
    if (type == 'device_stay_two_days' ||
        type.startsWith('maintenance_overdue')) {
      return AlertSoundKind.deviceStay;
    }
    if (type.startsWith('warranty_')) {
      return AlertSoundKind.warrantyExpiring;
    }
    return null;
  }

  static String? assetForType(String type) {
    return switch (kindForType(type)) {
      AlertSoundKind.deviceStay => defaultDeviceStayAsset,
      AlertSoundKind.warrantyExpiring => defaultWarrantyExpiringAsset,
      null => null,
    };
  }

  /// Only the two approved alert families have a sound:
  /// delayed maintenance uses sound 1, and warranty alerts use sound 2.
  Future<void> playForType(String type, {bool force = false}) {
    final kind = kindForType(type);
    if (kind == null) return Future<void>.value();
    return play(kind, force: force);
  }

  Future<void> playForTypes(
    Iterable<String> types, {
    bool force = false,
  }) {
    final kinds = types.map(kindForType).whereType<AlertSoundKind>().toSet();
    if (kinds.contains(AlertSoundKind.deviceStay)) {
      return play(AlertSoundKind.deviceStay, force: force);
    }
    if (kinds.contains(AlertSoundKind.warrantyExpiring)) {
      return play(AlertSoundKind.warrantyExpiring, force: force);
    }
    return Future<void>.value();
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
    double? volumeOverride,
    int? repeatCountOverride,
  }) async {
    final settings = SettingsService();
    await settings.load();
    if (!force && !settings.alertSoundsEnabled) return;

    final assetPath = switch (kind) {
      AlertSoundKind.deviceStay => defaultDeviceStayAsset,
      AlertSoundKind.warrantyExpiring => defaultWarrantyExpiringAsset,
    };
    final volume = volumeOverride ?? settings.alertVolume;
    final repeatCount = repeatCountOverride ?? settings.alertRepeatCount;
    final source = AssetSource(assetPath);

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
