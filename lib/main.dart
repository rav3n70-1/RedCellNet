// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:red_cell_net_final/app/app.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important blood requests and alerts.',
  importance: Importance.max,
  playSound: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Backend
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
  }

  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  } catch (e) {
    debugPrint("Error setting up Android local notifications: $e");
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    defaultPresentAlert: true,
    defaultPresentBadge: true,
    defaultPresentSound: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  } catch (e) {
    debugPrint("Error initializing FlutterLocalNotificationsPlugin: $e");
  }

  runApp(const MyApp());
}

void onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;

  if (payload != null && payload.isNotEmpty) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String? screen = data['screen'];
      final String? id = data['id'];

      if (screen == '/request_details' && id != null) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => RequestDetailsPage(requestId: id),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing notification payload: $e");
    }
  }
}
