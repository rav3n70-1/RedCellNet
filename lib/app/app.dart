// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/routes/app_routes.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/auth_gate.dart';
import 'package:red_cell_net_final/main.dart'; // For navigatorKey

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = AppSettingsService();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settingsService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'RedCellNet',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          debugShowCheckedModeBanner: false,
          home: const AuthGate(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}
