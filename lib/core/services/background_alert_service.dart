import 'dart:io';

import 'package:flutter/services.dart';

import '../router/app_router.dart';

/// Bridges the Flutter notification repository to Android's alarm receiver.
///
/// Android owns the actual alarm after it is scheduled, so it can query the
/// same SQLite database and show a system notification even when Flutter is
/// no longer running.
class BackgroundAlertService {
  static final BackgroundAlertService _instance =
      BackgroundAlertService._internal();
  factory BackgroundAlertService() => _instance;
  BackgroundAlertService._internal();

  static const _channel =
      MethodChannel('com.proshop.mobile_shop_pro/background_alerts');

  bool _openNotificationsRequested = false;

  bool get _isSupported => Platform.isAndroid;

  Future<void> initialize() async {
    if (!_isSupported) return;
    try {
      _channel.setMethodCallHandler(_handleNativeCall);
      final shouldOpen =
          await _channel.invokeMethod<bool>('initialize') ?? false;
      if (shouldOpen) {
        _openNotifications();
      }
    } on PlatformException {
      // In-app alerts must continue working if the Android bridge is
      // temporarily unavailable.
    } on MissingPluginException {
      // Expected on non-Android test hosts and during an engine restart.
    }
  }

  bool takePendingOpenNotifications() {
    final requested = _openNotificationsRequested;
    _openNotificationsRequested = false;
    return requested;
  }

  Future<BackgroundAlertPermissionStatus> permissionStatus() async {
    if (!_isSupported) return const BackgroundAlertPermissionStatus();
    try {
      final values = await _channel.invokeMapMethod<String, dynamic>(
        'permissionStatus',
      );
      return BackgroundAlertPermissionStatus.fromMap(values);
    } on PlatformException {
      return const BackgroundAlertPermissionStatus();
    } on MissingPluginException {
      return const BackgroundAlertPermissionStatus();
    }
  }

  Future<bool> openExactAlarmSettings() =>
      _invokeSettings('openExactAlarmSettings');

  Future<bool> openAutoStartSettings() =>
      _invokeSettings('openAutoStartSettings');

  Future<bool> requestBatteryOptimizationExemption() =>
      _invokeSettings('requestBatteryOptimizationExemption');

  Future<bool> _invokeSettings(String method) async {
    if (!_isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'openNotifications') {
      _openNotifications();
    }
  }

  void _openNotifications() {
    final path = AppRouter.router.routerDelegate.currentConfiguration.uri.path;
    if (path == '/splash') {
      _openNotificationsRequested = true;
      return;
    }
    AppRouter.router.go('/notifications');
  }

  Future<void> reschedule() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('reschedule');
    } on PlatformException {
      // The next app lifecycle transition or boot receiver retries safely.
    } on MissingPluginException {
      // Expected on non-Android test hosts.
    }
  }
}

class BackgroundAlertPermissionStatus {
  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool batteryOptimizationIgnored;
  final bool requiresAutoStart;

  const BackgroundAlertPermissionStatus({
    this.notificationsGranted = true,
    this.exactAlarmsGranted = true,
    this.batteryOptimizationIgnored = true,
    this.requiresAutoStart = false,
  });

  factory BackgroundAlertPermissionStatus.fromMap(
    Map<String, dynamic>? values,
  ) {
    return BackgroundAlertPermissionStatus(
      notificationsGranted: values?['notificationsGranted'] != false,
      exactAlarmsGranted: values?['exactAlarmsGranted'] != false,
      batteryOptimizationIgnored:
          values?['batteryOptimizationIgnored'] != false,
      requiresAutoStart: values?['requiresAutoStart'] == true,
    );
  }
}
