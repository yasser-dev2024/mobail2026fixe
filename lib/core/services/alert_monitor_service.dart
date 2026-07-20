import 'dart:async';

import '../../features/notifications/data/notification_model.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/notifications/presentation/widgets/recurring_alert_dialog.dart';
import 'alert_sound_service.dart';
import 'settings_service.dart';

/// Runs for the lifetime of the app (started once from `main.dart`) and
/// keeps the notification system "alive" without any user action:
///  - every minute, checks whether it's time to run a full
///    `generateSmartNotifications()` sweep, at the interval the shop owner
///    configured (default 30 minutes, changeable live with no restart);
///  - every minute, re-fires (sound + popup) any unread, non-stopped,
///    non-snoozed alert whose recurrence interval has elapsed.
///
/// This is intentionally generic: it does not know about "warranty" or
/// "device stay" specifically — any current or future notification `type`
/// gets the same recurring/snooze/stop behavior for free.
class AlertMonitorService {
  static final AlertMonitorService _instance =
      AlertMonitorService._internal();
  factory AlertMonitorService() => _instance;
  AlertMonitorService._internal();

  static const _tickInterval = Duration(minutes: 1);

  Timer? _timer;
  DateTime? _lastFullSweep;
  final Set<String> _visibleAlertIds = {};
  bool _ticking = false;

  void start() {
    _timer?.cancel();
    unawaited(_tick());
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_ticking) return; // avoid overlapping ticks if a check runs long
    _ticking = true;
    try {
      await _maybeRunFullSweep();
      await _refireDueAlerts();
    } catch (_) {
      // A single failed tick must never stop future ticks.
    } finally {
      _ticking = false;
    }
  }

  Future<void> _maybeRunFullSweep() async {
    final settings = SettingsService();
    await settings.load();
    final interval =
        Duration(minutes: settings.alertCheckIntervalMinutes);
    final last = _lastFullSweep;
    if (last != null && DateTime.now().difference(last) < interval) return;
    _lastFullSweep = DateTime.now();
    await NotificationsRepository().generateSmartNotifications();
  }

  Future<void> _refireDueAlerts() async {
    final due = await NotificationsRepository().getDueForRefire();
    for (final notification in due) {
      if (_visibleAlertIds.contains(notification.id)) continue;
      await _fire(notification);
    }
  }

  Future<void> _fire(NotificationModel notification) async {
    _visibleAlertIds.add(notification.id);
    try {
      unawaited(AlertSoundService().playForType(notification.type));
      await NotificationsRepository().markFired(notification.id);
      await showRecurringAlertDialog(notification);
    } finally {
      _visibleAlertIds.remove(notification.id);
    }
  }
}
