import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final _repo = NotificationsRepository();

  NotificationsCubit() : super(NotificationsInitial());

  Future<void> loadNotifications({bool? unreadOnly}) async {
    emit(NotificationsLoading());
    try {
      final notifications = await _repo.getAll(unreadOnly: unreadOnly);
      final unreadCount = await _repo.getUnreadCount();
      emit(NotificationsLoaded(notifications, unreadCount));
    } catch (e) {
      emit(NotificationsError(e.toString()));
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repo.markAsRead(id);
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> generateSmartNotifications() async {
    try {
      await _repo.generateSmartNotifications();
      await loadNotifications();
    } catch (_) {}
  }

  int get unreadCount {
    final s = state;
    if (s is NotificationsLoaded) return s.unreadCount;
    return 0;
  }
}
