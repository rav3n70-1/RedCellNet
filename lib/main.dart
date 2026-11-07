// lib/main.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/app/app.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted theme, locale, onboarding state, and local caches
  await AppSettingsService().init();

  // Initialize Supabase Backend
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
  }

  // Initialize unified push notification service (Emergency & Community channels + deep links)
  try {
    await PushNotificationService().initialize(navigatorKey: navigatorKey);
  } catch (e) {
    debugPrint("Error initializing PushNotificationService: $e");
  }

  runApp(const MyApp());
}
