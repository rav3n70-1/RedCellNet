// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:red_cell_net_final/firebase_options.dart'; // Ensure this path is correct
import 'package:red_cell_net_final/app/app.dart'; // Your main App Widget definition
import 'dart:convert'; // For jsonDecode in notification handler
// Import the page we navigate to from notifications
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';

// --- Global Navigator Key ---
// Used to navigate from notification handlers outside the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// --- End Global Navigator Key ---

// --- Local Notifications Plugin Initialization ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id (needs to be unique)
  'High Importance Notifications', // name (visible to user in settings)
  description:
      'This channel is used for important blood requests and alerts.', // description
  importance: Importance.max, // Max importance for heads-up display
  playSound: true, // Play sound for notifications on this channel
);
// --- End Local Notifications Plugin Initialization ---

// --- Background Message Handler (MUST be a top-level function) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Avoid complex logic or UI updates here
  // If Firebase needs init here (e.g., for Firestore access), do it carefully:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("-----------------------------------------");
  print("Handling a background message: ${message.messageId}");
  print("Message data: ${message.data}");
  if (message.notification != null) {
    print(
        "Message notification: ${message.notification?.title} / ${message.notification?.body}");
  }
  print("-----------------------------------------");
  // Consider if showing a local notification here is needed or if system tray handles it
}
// --- End Background Message Handler ---

// --- Main Application Entry Point ---
Future<void> main() async {
  // Ensure Flutter engine is ready
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Firebase Initialized");

  // Set the background messaging handler for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print("FCM Background Handler Set");

  // --- Local Notifications Setup ---
  try {
    // Create the Android Notification Channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    print("Android Notification Channel created/ensured");

    // Request notification permissions on Android 13+ via local plugin
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted =
        await androidImplementation?.requestNotificationsPermission();
    print("Local Notifications Android permission requested: Granted=$granted");
  } catch (e) {
    print("Error setting up Android local notifications: $e");
  }

  // --- Initialize FlutterLocalNotificationsPlugin ---
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings(
          '@mipmap/ic_launcher'); // Check if this icon exists

  // Configure iOS initialization settings (foreground presentation)
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    defaultPresentAlert: true,
    defaultPresentBadge: true,
    defaultPresentSound: true,
    // Deprecated callback removed
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
    // macOS: ..., // Add if supporting macOS
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        // Callback for when user taps a LOCAL notification
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
    print("FlutterLocalNotificationsPlugin Initialized");
  } catch (e) {
    print("Error initializing FlutterLocalNotificationsPlugin: $e");
  }
  // --- End Local Notifications Setup ---

  // Run the App
  runApp(const MyApp()); // Ensure MyApp is defined in app/app.dart
}

// --- Local Notification Callbacks ---

// Callback for when user taps a notification shown by this plugin
void onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  print("Local notification tapped with payload: $payload");

  if (payload != null && payload.isNotEmpty) {
    try {
      // Decode the JSON payload string
      final Map<String, dynamic> data = jsonDecode(payload);
      final String? screen = data['screen']; // e.g., '/request_details'
      final String? id = data['id']; // e.g., the Firestore document ID

      print("Parsed payload: screen=$screen, id=$id");

      // Check if the payload contains navigation info for request details
      if (screen == '/request_details' && id != null) {
        print("Attempting navigation to Request Details: $id");
        // Use the global key to access the Navigator state
        // Ensure the navigator is available before pushing
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              // Make sure RequestDetailsPage is imported correctly
              builder: (context) => RequestDetailsPage(requestId: id),
            ),
          );
          print("Navigation push initiated.");
        } else {
          print("Navigator state was null, cannot navigate.");
          // TODO: Handle navigation if navigator wasn't ready (e.g., store action)
        }
      } else {
        print("Payload doesn't contain valid navigation info.");
      }
      // TODO: Add else if conditions for other screen types based on payload
    } catch (e) {
      print("Error parsing notification payload or navigating: $e");
    }
  }
}
// --- End Local Notification Callbacks ---
