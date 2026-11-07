// lib/core/services/push_notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/routes/app_routes.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Stream for in-app broadcast alerts
  final StreamController<Map<String, dynamic>> _inAppAlertController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onInAppAlertReceived =>
      _inAppAlertController.stream;

  // Tracking last received notification timestamp to avoid duplicate alerts
  DateTime _lastBroadcastTimestamp =
      DateTime.now().toUtc().subtract(const Duration(seconds: 5));
  DateTime _lastPersonalTimestamp =
      DateTime.now().toUtc().subtract(const Duration(seconds: 5));

  StreamSubscription? _broadcastSub;
  StreamSubscription? _personalSub;

  String? _listeningUserId;
  String? _listeningBloodType;
  String? _listeningCity;
  DateTime? _notificationsPausedUntil;
  Map<String, dynamic> _notificationPreferences = const {};

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }
    if (_isInitialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();

        const emergencyChannel = AndroidNotificationChannel(
          'emergency_blood_channel',
          'Emergency Blood Appeals & Shortages',
          description:
              'High-priority emergency blood alerts requiring immediate response.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        const communityChannel = AndroidNotificationChannel(
          'community_updates_channel',
          'Community & Personal Updates',
          description:
              'Donor verifications, hospital updates, and fulfillment milestones.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidPlugin.createNotificationChannel(emergencyChannel);
        await androidPlugin.createNotificationChannel(communityChannel);
      }

      _isInitialized = true;
      debugPrint("PushNotificationService successfully initialized.");
    } catch (e) {
      debugPrint("PushNotificationService initialization error: $e");
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    try {
      if (payload.trim().startsWith('{')) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(jsonDecode(payload) as Map);
        final String screen = (data['screen'] ?? '').toString().trim();
        final String? id = data['id']?.toString();

        if ((screen == '/request-details' || screen == '/request_details') &&
            id != null &&
            id.isNotEmpty) {
          nav.pushNamed(AppRoutes.requestDetails, arguments: id);
          return;
        }
        if (screen == '/profile') {
          nav.pushNamed(AppRoutes.profile);
          return;
        }
        if (screen == '/map') {
          nav.pushNamed(AppRoutes.map);
          return;
        }
        if (screen == '/learn') {
          nav.pushNamed(AppRoutes.contentList);
          return;
        }
        if (screen == '/home') {
          nav.pushNamed(AppRoutes.home);
          return;
        }
        nav.pushNamed(AppRoutes.notifications);
        return;
      }

      // Legacy string fallback
      if (payload.startsWith('request_')) {
        final reqId = payload.substring('request_'.length);
        if (reqId.isNotEmpty) {
          nav.pushNamed(AppRoutes.requestDetails, arguments: reqId);
          return;
        }
      }
      nav.pushNamed(AppRoutes.notifications);
    } catch (e) {
      debugPrint("Notification navigation error: $e");
    }
  }

  void updateUserPreferences({
    DateTime? notificationsPausedUntil,
    Map<String, dynamic>? notificationPreferences,
  }) {
    _notificationsPausedUntil = notificationsPausedUntil;
    if (notificationPreferences != null) {
      _notificationPreferences =
          Map<String, dynamic>.from(notificationPreferences);
    }
  }

  bool get _isPaused {
    final until = _notificationsPausedUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  bool _isCategoryEnabled(String key) {
    if (_isPaused) return false;
    final val = _notificationPreferences[key];
    if (val is bool) return val;
    return true;
  }

  /// Displays high-priority emergency heads-up notification with custom vibration & sound.
  Future<void> showEmergencyNotification({
    required String title,
    required String body,
    String? payload,
    String? targetBloodType,
  }) async {
    if (_isPaused) return;
    try {
      final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

      final androidDetails = AndroidNotificationDetails(
        'emergency_blood_channel',
        'Emergency Blood Appeals & Shortages',
        channelDescription:
            'High-priority emergency blood alerts requiring immediate response.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Emergency Blood Alert',
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        enableLights: true,
        color: const Color(0xFFDC2626),
        ledColor: const Color(0xFFDC2626),
        ledOnMs: 1000,
        ledOffMs: 500,
        fullScreenIntent: false,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: targetBloodType != null && targetBloodType.isNotEmpty
              ? 'Target Blood: $targetBloodType'
              : 'Emergency Dispatch',
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final int notifId =
          DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
      await _localNotifications.show(
        notifId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error showing emergency notification: $e");
    }
  }

  /// Displays standard informational or community update notification.
  Future<void> showCommunityNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_isPaused) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        'community_updates_channel',
        'Community & Personal Updates',
        channelDescription:
            'Donor verifications, hospital updates, and fulfillment milestones.',
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFA41235),
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final int notifId =
          DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
      await _localNotifications.show(
        notifId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error showing community notification: $e");
    }
  }

  /// Sends a celebratory or countdown reminder notification for the 90-day WHO recovery window.
  Future<void> showEligibilityCountdownReminder({
    required int daysRemaining,
    String? bloodType,
    DateTime? nextEligibleDate,
  }) async {
    final bg = (bloodType != null && bloodType.trim().isNotEmpty)
        ? bloodType.trim().toUpperCase()
        : 'Donor';
    if (daysRemaining <= 0) {
      await showCommunityNotification(
        title: '🩸 You Are Eligible to Donate Again!',
        body:
            'Your 90-day WHO recovery window is complete. Your $bg blood can save up to 3 lives today!',
        payload: jsonEncode({'screen': '/home', 'type': 'eligibility_ready'}),
      );
    } else {
      final dateLabel = nextEligibleDate != null
          ? '${nextEligibleDate.day}/${nextEligibleDate.month}/${nextEligibleDate.year}'
          : 'in $daysRemaining days';
      await showCommunityNotification(
        title: '⏳ Recovery Countdown Armed ($daysRemaining days left)',
        body:
            'We will remind you when your 90-day recovery window finishes on $dateLabel.',
        payload: jsonEncode({'screen': '/profile', 'type': 'eligibility_countdown'}),
      );
    }
  }

  /// Connects realtime listeners to Supabase idempotently for immediate native push alerts.
  void startRealtimeAlertListeners({
    required String currentUserId,
    String? userBloodType,
    String? userCity,
    DateTime? notificationsPausedUntil,
    Map<String, dynamic>? notificationPreferences,
  }) {
    updateUserPreferences(
      notificationsPausedUntil: notificationsPausedUntil,
      notificationPreferences: notificationPreferences,
    );

    if (_broadcastSub != null &&
        _personalSub != null &&
        _listeningUserId == currentUserId &&
        _listeningBloodType == userBloodType &&
        _listeningCity == userCity) {
      return;
    }

    stopRealtimeAlertListeners();
    _listeningUserId = currentUserId;
    _listeningBloodType = userBloodType;
    _listeningCity = userCity;

    if (!SupabaseConfig.isInitialized || currentUserId.isEmpty) return;
    final supabase = SupabaseConfig.client;

    // 1. Listen to Emergency System Broadcasts (oldest-to-newest watermark processing)
    try {
      final broadcastStream = supabase
          .from('system_broadcasts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(5);

      _broadcastSub = broadcastStream.listen((rows) {
        if (rows.isEmpty || !_isCategoryEnabled('system_broadcasts')) return;

        final sorted = List<Map<String, dynamic>>.from(rows)
          ..sort((a, b) {
            final da = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return da.compareTo(db);
          });

        for (final row in sorted) {
          if (row['is_active'] == false) continue;
          final expiresAtStr = row['expires_at']?.toString();
          if (expiresAtStr != null) {
            final exp = DateTime.tryParse(expiresAtStr);
            if (exp != null && exp.isBefore(DateTime.now().toUtc())) continue;
          }

          final createdAtStr = row['created_at']?.toString();
          if (createdAtStr == null) continue;
          final createdAt = DateTime.tryParse(createdAtStr)?.toUtc();
          if (createdAt == null) continue;

          if (createdAt.isAfter(_lastBroadcastTimestamp)) {
            _lastBroadcastTimestamp = createdAt;

            final targetBlood = row['target_blood_type']?.toString().trim();
            final targetCity = row['target_city']?.toString().trim();

            final matchesBlood = targetBlood == null ||
                targetBlood.isEmpty ||
                targetBlood.toUpperCase() == 'ALL' ||
                (userBloodType != null &&
                    userBloodType.trim().isNotEmpty &&
                    (targetBlood.toUpperCase() ==
                            userBloodType.trim().toUpperCase() ||
                        BloodCompatibility.isCompatible(
                          donorBloodType: userBloodType,
                          recipientBloodType: targetBlood,
                        )));

            final matchesCity = targetCity == null ||
                targetCity.isEmpty ||
                (userCity != null &&
                    userCity.trim().isNotEmpty &&
                    userCity.toLowerCase().contains(targetCity.toLowerCase()));

            if (matchesBlood && matchesCity) {
              final title =
                  (row['title'] ?? 'Emergency Blood Alert').toString();
              final message =
                  (row['message'] ?? 'Critical shortage reported in your area.')
                      .toString();

              showEmergencyNotification(
                title: title,
                body: message,
                targetBloodType: targetBlood,
                payload: jsonEncode({
                  'screen': '/home',
                  'id': row['id']?.toString(),
                  'type': 'emergency_broadcast',
                }),
              );

              _inAppAlertController.add(row);
            }
          }
        }
      }, onError: (e) {
        debugPrint("Broadcasts realtime listener notice: $e");
      });
    } catch (e) {
      debugPrint("Error attaching broadcast realtime listener: $e");
    }

    // 2. Listen to Personal Notifications (oldest-to-newest watermark processing)
    try {
      final personalStream = supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(5);

      _personalSub = personalStream.listen((rows) {
        if (rows.isEmpty) return;

        final sorted = List<Map<String, dynamic>>.from(rows)
          ..sort((a, b) {
            final da = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return da.compareTo(db);
          });

        for (final row in sorted) {
          final createdAtStr = row['created_at']?.toString();
          if (createdAtStr == null) continue;
          final createdAt = DateTime.tryParse(createdAtStr)?.toUtc();
          if (createdAt == null) continue;

          if (createdAt.isAfter(_lastPersonalTimestamp)) {
            _lastPersonalTimestamp = createdAt;
            if (row['is_read'] == true) continue;

            final type = (row['type'] ?? 'system').toString();
            if (type == 'emergency_request' &&
                !_isCategoryEnabled('emergency_alerts')) {
              continue;
            }
            if ((type == 'donor_offer' ||
                    type == 'offer_accepted' ||
                    type == 'offer_declined' ||
                    type == 'request_update') &&
                !_isCategoryEnabled('offer_updates')) {
              continue;
            }

            final title = (row['title'] ?? 'Notification').toString();
            final body = (row['body'] ?? '').toString();
            final screen = (row['screen'] ?? '/notifications').toString();
            final resourceId = row['resource_id']?.toString();
            final payload = jsonEncode({
              'screen': screen,
              'id': resourceId,
              'notificationId': row['id']?.toString(),
              'type': type,
            });

            if (type == 'emergency_request' || type == 'emergency_broadcast') {
              showEmergencyNotification(
                title: title,
                body: body,
                payload: payload,
              );
            } else {
              showCommunityNotification(
                title: title,
                body: body,
                payload: payload,
              );
            }
          }
        }
      }, onError: (e) {
        debugPrint("Personal notifications realtime listener notice: $e");
      });
    } catch (e) {
      debugPrint("Error attaching personal notifications listener: $e");
    }
  }

  void stopRealtimeAlertListeners() {
    _broadcastSub?.cancel();
    _broadcastSub = null;
    _personalSub?.cancel();
    _personalSub = null;
    _listeningUserId = null;
  }
}
