// lib/features/notifications/presentation/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/routes/app_routes.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/notifications/data/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late final Stream<List<Map<String, dynamic>>> _notificationsStream;
  late TabController _tabController;

  static const Set<String> _urgentAndOfferTypes = {
    'emergency_request',
    'emergency_broadcast',
    'emergency',
    'donor_offer',
    'new_offer',
    'offer_accepted',
    'offer_declined',
    'request_update',
    'donation_completed',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _notificationsStream = _notificationService.getUserNotificationsStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate().toLocal();
    } else if (timestamp is DateTime) {
      date = timestamp.toLocal();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp)?.toLocal() ?? DateTime.now();
    } else {
      date = DateTime.now();
    }
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'donor_offer':
      case 'new_offer':
        return Icons.volunteer_activism_rounded;
      case 'offer_accepted':
      case 'donation_completed':
        return Icons.check_circle_rounded;
      case 'offer_declined':
      case 'request_update':
        return Icons.sync_alt_rounded;
      case 'emergency_request':
      case 'emergency_broadcast':
      case 'emergency':
        return Icons.emergency_rounded;
      case 'verification':
        return Icons.verified_user_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'donor_offer':
      case 'new_offer':
        return AppColors.secondary;
      case 'offer_accepted':
      case 'donation_completed':
      case 'verification':
        return AppColors.success;
      case 'offer_declined':
      case 'request_update':
        return AppColors.warning;
      case 'emergency_request':
      case 'emergency_broadcast':
      case 'emergency':
        return AppColors.emergency;
      default:
        return AppColors.primary;
    }
  }

  void _navigateFromNotification(Map<String, dynamic> data) {
    final String screen = (data['screen'] ?? '').toString().trim();
    final String type = (data['type'] ?? '').toString().trim();
    final String? relatedId =
        (data['relatedId'] ?? data['resource_id'] ?? data['resourceId'])
            ?.toString();

    if (screen == '/request-details' ||
        screen == '/request_details' ||
        const {
          'emergency_request',
          'donor_offer',
          'new_offer',
          'offer_accepted',
          'offer_declined',
          'request_update',
        }.contains(type)) {
      if (relatedId != null && relatedId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailsPage(requestId: relatedId),
          ),
        );
      }
      return;
    }

    if (screen == '/profile' ||
        type == 'verification' ||
        type == 'donation_completed' ||
        type == 'role_update') {
      Navigator.pushNamed(context, AppRoutes.profile);
      return;
    }

    if (screen == '/home' || type == 'emergency_broadcast') {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamed(context, AppRoutes.home);
      }
      return;
    }

    if (screen == '/map') {
      Navigator.pushNamed(context, AppRoutes.map);
      return;
    }

    if (screen == '/learn') {
      Navigator.pushNamed(context, AppRoutes.contentList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService();

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(settings.tr('Notifications')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: settings.tr('Notification Preferences'),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark All as Read',
            onPressed: () async {
              await _notificationService.markAllAsRead();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: settings.tr('All')),
            const Tab(text: 'Requests & Offers'),
            const Tab(text: 'System & Account'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications: ${snapshot.error}',
                style: const TextStyle(color: AppColors.critical),
              ),
            );
          }

          final allDocs = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(allDocs),
              _buildList(allDocs
                  .where((d) =>
                      _urgentAndOfferTypes.contains((d['type'] ?? '').toString()))
                  .toList()),
              _buildList(allDocs
                  .where((d) =>
                      !_urgentAndOfferTypes.contains((d['type'] ?? '').toString()))
                  .toList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) {
      return const EmptyStateView(
        icon: Icons.notifications_none_rounded,
        title: 'No Notifications',
        message: 'You have no updates in this category right now.',
      );
    }

    final isDark = AppColors.isDark(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index];
        final String docId = data['id']?.toString() ?? '';
        final String title = (data['title'] ?? 'Notification').toString();
        final String body = (data['body'] ?? '').toString();
        final String? type = data['type']?.toString();
        final bool isRead = data['isRead'] == true || data['is_read'] == true;
        final createdAt = data['createdAt'] ?? data['created_at'];
        final timeStr = _formatTime(createdAt);

        final icon = _getIconForType(type);
        final color = _getColorForType(type);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isRead
                ? AppColors.cardBg(context)
                : (isDark
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : AppColors.primaryContainer.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? AppColors.borderOf(context)
                  : AppColors.primary.withValues(alpha: 0.4),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: isDark ? null : AppColors.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (!isRead && docId.isNotEmpty) {
                  await _notificationService.markAsRead(docId);
                }
                if (mounted) {
                  _navigateFromNotification(data);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead
                                        ? FontWeight.w700
                                        : FontWeight.w900,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMutedOf(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 12,
                              color: isRead
                                  ? AppColors.textSecondaryOf(context)
                                  : AppColors.textPrimaryOf(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
