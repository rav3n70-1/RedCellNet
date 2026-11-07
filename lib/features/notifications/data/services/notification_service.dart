// lib/features/notifications/data/services/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';

class NotificationService {
  String? get _currentUserId => SupabaseAuthService().currentUserId;

  List<Map<String, dynamic>> _normalizeList(List<dynamic> rows) {
    return rows.map((m) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(m as Map);
      item['isRead'] ??= item['is_read'] ?? false;
      item['is_read'] ??= item['isRead'];
      item['relatedId'] ??= item['related_id'] ?? item['resource_id'] ?? item['resourceId'];
      item['createdAt'] ??= item['created_at'];
      return item;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getUserNotificationsStream() {
    return _getUserNotificationsStreamImpl().asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> _getUserNotificationsStreamImpl() async* {
    final uid = _currentUserId;
    if (uid == null) {
      yield [];
      return;
    }

    // 1. Initial REST fetch
    try {
      final initialRows = await supabase
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      yield _normalizeList(initialRows);
    } catch (e) {
      debugPrint("Initial notifications REST fetch notice: $e");
      yield [];
    }

    // 2. Realtime Stream
    try {
      final stream = supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50)
          .handleError((e) {
            debugPrint("Handled notifications realtime error: $e");
          });

      await for (final rows in stream) {
        yield _normalizeList(rows);
      }
    } catch (e) {
      debugPrint("Notifications realtime fallback: $e");
    }
  }

  Stream<int> getUnreadCountStream() {
    return _getUnreadCountStreamImpl().asBroadcastStream();
  }

  Stream<int> _getUnreadCountStreamImpl() async* {
    final uid = _currentUserId;
    if (uid == null) {
      yield 0;
      return;
    }

    // 1. Initial REST count
    try {
      final rows = await supabase
          .from('notifications')
          .select('id, is_read')
          .eq('user_id', uid)
          .eq('is_read', false);
      yield rows.length;
    } catch (e) {
      debugPrint("Initial unread count REST notice: $e");
      yield 0;
    }

    // 2. Realtime Stream
    try {
      final stream = supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .handleError((e) {
            debugPrint("Handled unread count realtime error: $e");
          });

      await for (final items in stream) {
        final unread = items.where((n) => n['is_read'] != true && n['isRead'] != true).length;
        yield unread;
      }
    } catch (e) {
      debugPrint("Unread count realtime fallback: $e");
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
    String type = 'system',
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'screen': screen,
        'resource_id': resourceId,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error creating notification: $e");
    }
  }
}
