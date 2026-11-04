// lib/features/notifications/data/services/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';

class NotificationService {
  String? get _currentUserId => SupabaseAuthService().currentUserId;

  Stream<List<Map<String, dynamic>>> getUserNotificationsStream() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value([]);

    try {
      return supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50)
          .map((rows) => rows.map((m) {
                final Map<String, dynamic> item = Map<String, dynamic>.from(m);
                item['isRead'] ??= item['is_read'] ?? false;
                item['is_read'] ??= item['isRead'];
                item['relatedId'] ??= item['related_id'] ?? item['resource_id'] ?? item['resourceId'];
                item['createdAt'] ??= item['created_at'];
                return item;
              }).toList());
    } catch (e) {
      debugPrint("Error streaming notifications: $e");
      return Stream.value([]);
    }
  }

  Stream<int> getUnreadCountStream() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value(0);

    try {
      return supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .map((items) => items.where((n) => n['is_read'] != true && n['isRead'] != true).length);
    } catch (e) {
      debugPrint("Error streaming unread count: $e");
      return Stream.value(0);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    }
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String? screen,
    String? resourceId,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'screen': screen,
        'resource_id': resourceId,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error creating notification: $e");
    }
  }
}
