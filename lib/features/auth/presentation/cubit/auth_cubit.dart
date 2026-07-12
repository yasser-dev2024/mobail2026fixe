import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../data/user_model.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;

  AuthCubit({AuthRepository? repo})
      : _repo = repo ?? AuthRepository(),
        super(AuthInitial());

  Future<void> login(String username, String password) async {
    emit(AuthLoading());
    try {
      final user = await _repo.login(username.trim(), password);
      if (user == null) {
        emit(AuthError('اسم المستخدم أو كلمة المرور غير صحيحة'));
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthError('حدث خطأ غير متوقع. يرجى المحاولة مجدداً.'));
    }
  }

  Future<void> logout() async {
    _repo.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> checkSession() async {
    final user = _repo.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }
}
