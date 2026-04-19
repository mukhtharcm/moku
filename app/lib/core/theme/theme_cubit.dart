import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State
class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final bool powerSaver;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.powerSaver = false,
  });

  @override
  List<Object?> get props => [themeMode, powerSaver];
}

// Cubit
class ThemeCubit extends Cubit<ThemeState> {
  static const _key = 'theme_mode';
  static const _powerSaverKey = 'power_saver';

  ThemeCubit() : super(const ThemeState());

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_key) ?? 0;
    final powerSaver = prefs.getBool(_powerSaverKey) ?? false;
    emit(ThemeState(
      themeMode: ThemeMode.values[modeIndex],
      powerSaver: powerSaver,
    ));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
    emit(ThemeState(themeMode: mode, powerSaver: state.powerSaver));
  }

  Future<void> toggleTheme() async {
    final nextMode = switch (state.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(nextMode);
  }

  Future<void> setPowerSaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_powerSaverKey, enabled);
    emit(ThemeState(themeMode: state.themeMode, powerSaver: enabled));
  }
}
