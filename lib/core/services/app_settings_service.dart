// lib/core/services/app_settings_service.dart
import 'package:flutter/material.dart';

class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>('en');

  void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }

  void setLanguage(String lang) {
    if (lang == 'en' || lang == 'bn') {
      languageNotifier.value = lang;
    }
  }

  bool get isBengali => languageNotifier.value == 'bn';

  String tr(String englishKey, {String? bn}) {
    if (isBengali && bn != null && bn.isNotEmpty) {
      return bn;
    }
    return englishKey;
  }
}
