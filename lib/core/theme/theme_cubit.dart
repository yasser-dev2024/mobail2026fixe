import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light);

  static const _key = 'theme_mode';

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'light';
    if (saved == 'dark') {
      emit(ThemeMode.dark);
    } else if (saved == 'system') {
      emit(ThemeMode.system);
    } else {
      emit(ThemeMode.light);
    }
  }

  Future<void> setLight() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'light');
    emit(ThemeMode.light);
  }

  Future<void> setDark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'dark');
    emit(ThemeMode.dark);
  }

  Future<void> setSystem() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'system');
    emit(ThemeMode.system);
  }

  Future<void> toggle() async {
    if (state == ThemeMode.light) {
      await setDark();
    } else {
      await setLight();
    }
  }
}
