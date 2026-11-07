// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

    return ListenableBuilder(
      listenable: Listenable.merge([
        settingsService.themeModeNotifier,
        settingsService.languageNotifier,
      ]),
      builder: (context, _) {
        final currentThemeMode = settingsService.themeModeNotifier.value;
        final currentLang = settingsService.languageNotifier.value;

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'RedCellNet',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          locale: Locale(currentLang),
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('en'),
            Locale('bn', 'BD'),
            Locale('bn'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          home: const AuthGate(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final clampedTextScaler = mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedTextScaler),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
