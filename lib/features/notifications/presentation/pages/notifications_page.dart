// lib/features/notifications/presentation/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    if (diff.inMinutes < 60) {
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
      case 'new_offer':
        return Icons.volunteer_activism_rounded;
      case 'offer_accepted':
        return Icons.check_circle_rounded;
      case 'emergency':
        return Icons.emergency_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'new_offer':
        return AppColors.secondary;
      case 'offer_accepted':
        return AppColors.success;
      case 'emergency':
        return AppColors.emergency;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Offers & Emergencies'),
            Tab(text: 'System'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationService.getUserNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
              _buildList(allDocs.where((d) {
                final type = d['type'] ?? '';
                return type == 'new_offer' || type == 'offer_accepted' || type == 'emergency';
              }).toList()),
              _buildList(allDocs.where((d) {
                final type = d['type'] ?? '';
                return type != 'new_offer' && type != 'offer_accepted' && type != 'emergency';
              }).toList()),
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
        message: 'You have no updates or notifications at the moment.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index];
        final String docId = data['id']?.toString() ?? '';
        final String title = data['title'] ?? 'Notification';
        final String body = data['body'] ?? '';
        final String? type = data['type'];
        final String? relatedId = data['relatedId'] ?? data['resource_id'] ?? data['resourceId'];
        final bool isRead = data['isRead'] == true || data['is_read'] == true;
        final createdAt = data['createdAt'] ?? data['created_at'];
        final timeStr = _formatTime(createdAt);

        final icon = _getIconForType(type);
        final color = _getColorForType(type);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : AppColors.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.3),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (!isRead && docId.isNotEmpty) {
                  await _notificationService.markAsRead(docId);
                }
                if (relatedId != null && relatedId.isNotEmpty && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestDetailsPage(requestId: relatedId),
                    ),
                  );
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
                        color: color.withValues(alpha: 0.12),
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
                                    fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
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
                              color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
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
