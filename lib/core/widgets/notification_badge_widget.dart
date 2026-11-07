// lib/core/widgets/notification_badge_widget.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/notifications/data/services/notification_service.dart';
import 'package:red_cell_net_final/features/notifications/presentation/pages/notifications_page.dart';

/// Reactive Notification Badge Widget that caches its unread-count stream
/// so rebuilds never spawn redundant Supabase Realtime channels.
class NotificationBadgeWidget extends StatefulWidget {
  final Color? iconColor;
  final Color? badgeColor;
  final double size;
  final EdgeInsetsGeometry padding;

  const NotificationBadgeWidget({
    super.key,
    this.iconColor,
    this.badgeColor,
    this.size = 24.0,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  State<NotificationBadgeWidget> createState() =>
      _NotificationBadgeWidgetState();
}

class _NotificationBadgeWidgetState extends State<NotificationBadgeWidget> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = NotificationService().getUnreadCountStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        final hasUnread = unreadCount > 0;
        final effectiveIconColor =
            widget.iconColor ?? AppColors.textPrimaryOf(context);
        final effectiveBadgeColor = widget.badgeColor ?? AppColors.critical;

        return IconButton(
          iconSize: widget.size,
          padding: widget.padding,
          tooltip: hasUnread
              ? '$unreadCount unread notifications'
              : 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: hasUnread ? AppColors.primary : effectiveIconColor,
                size: widget.size,
              ),
              if (hasUnread)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: effectiveBadgeColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.scaffoldOf(context),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveBadgeColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
