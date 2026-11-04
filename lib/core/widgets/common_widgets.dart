// lib/core/widgets/common_widgets.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/notifications/data/services/notification_service.dart';
import 'package:red_cell_net_final/features/notifications/presentation/pages/notifications_page.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';

/// Clean, visually striking badge for displaying Blood Types (A+, O-, AB+, etc.)
class BloodGroupBadge extends StatelessWidget {
  final String bloodType;
  final double size;
  final bool isSelected;
  final bool isOutlined;
  final bool showGlow;

  const BloodGroupBadge({
    super.key,
    required this.bloodType,
    this.size = 46.0,
    this.isSelected = false,
    this.isOutlined = false,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isOutlined
        ? Colors.white
        : (isSelected ? AppColors.primary : AppColors.primaryContainer);
    final Color textColor = isOutlined || !isSelected ? AppColors.primaryDark : Colors.white;
    final Border border = isOutlined || isSelected
        ? Border.all(color: AppColors.primary, width: isSelected ? 2.0 : 1.2)
        : Border.all(color: AppColors.primaryLight, width: 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: border,
        boxShadow: (isSelected || showGlow)
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            bloodType,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.36,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual urgency level pill indicator
class UrgencyChip extends StatelessWidget {
  final String urgency;
  final bool compact;

  const UrgencyChip({
    super.key,
    required this.urgency,
    this.compact = false,
  });

  static Color getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'critical':
        return AppColors.critical;
      case 'high':
        return AppColors.high;
      case 'medium':
        return AppColors.medium;
      case 'low':
        return AppColors.low;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color getUrgencyLightColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'critical':
        return AppColors.criticalLight;
      case 'high':
        return AppColors.highLight;
      case 'medium':
        return AppColors.mediumLight;
      case 'low':
        return AppColors.lowLight;
      default:
        return AppColors.surfaceMuted;
    }
  }

  static IconData getUrgencyIcon(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'critical':
        return Icons.emergency_rounded;
      case 'high':
        return Icons.local_fire_department_rounded;
      case 'medium':
        return Icons.schedule_rounded;
      case 'low':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getUrgencyColor(urgency);
    final lightColor = getUrgencyLightColor(urgency);
    final icon = getUrgencyIcon(urgency);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              urgency.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            urgency,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard Section Title Header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? icon;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.icon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Modern Empty State Indicator
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryLight, width: 2),
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onAction != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Blood Donation Compatibility Banner
class CompatibilityBanner extends StatelessWidget {
  final String donorBloodType;
  final String recipientBloodType;
  final bool isCompatible;

  const CompatibilityBanner({
    super.key,
    required this.donorBloodType,
    required this.recipientBloodType,
    required this.isCompatible,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isCompatible ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final borderColor = isCompatible ? AppColors.success : AppColors.medium;
    final textColor = isCompatible ? const Color(0xFF065F46) : const Color(0xFF92400E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompatible ? Icons.check_circle_rounded : Icons.info_rounded,
              color: borderColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompatible
                      ? "You are a Compatible Donor!"
                      : "Blood Type Not Fully Compatible",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isCompatible
                      ? "Your blood type ($donorBloodType) can safely help this patient ($recipientBloodType)."
                      : "Your blood type ($donorBloodType) does not match requirements ($recipientBloodType).",
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Metric card for stats (Points, Lives, Donations)
class StatMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback? onTap;

  const StatMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing Live Emergency Dot
class PulseDot extends StatelessWidget {
  final Color color;
  final double size;

  const PulseDot({
    super.key,
    this.color = AppColors.critical,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

/// Dynamic Units Fulfillment Progress Bar
class UnitsProgressIndicator extends StatelessWidget {
  final int requiredUnits;
  final int acceptedUnits;
  final int remainingUnits;
  final bool compact;

  const UnitsProgressIndicator({
    super.key,
    required this.requiredUnits,
    required this.acceptedUnits,
    required this.remainingUnits,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = requiredUnits > 0
        ? (acceptedUnits / requiredUnits).clamp(0.0, 1.0)
        : 0.0;
    final bool isFulfilled = remainingUnits <= 0 && requiredUnits > 0;
    final bool isPartial = acceptedUnits > 0 && remainingUnits > 0;

    final Color progressColor = isFulfilled
        ? AppColors.success
        : (isPartial ? AppColors.warning : AppColors.primary);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$acceptedUnits / $requiredUnits Units',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isFulfilled
                      ? AppColors.successLight
                      : (isPartial ? AppColors.warningLight : AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFulfilled
                      ? 'Fulfilled'
                      : '$remainingUnits needed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isFulfilled
                        ? AppColors.success
                        : (isPartial ? AppColors.warningDark : AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 5,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isFulfilled
                        ? Icons.check_circle_rounded
                        : Icons.water_drop_rounded,
                    color: progressColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Fulfillment Progress",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isFulfilled
                      ? AppColors.successLight
                      : (isPartial ? AppColors.warningLight : AppColors.primaryContainer),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFulfilled
                      ? 'All Units Covered'
                      : '$remainingUnits Units Remaining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isFulfilled
                        ? AppColors.success
                        : (isPartial ? AppColors.warningDark : AppColors.primaryDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$acceptedUnits accepted of $requiredUnits requested",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "${(fraction * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Official Donor Verification Badge (Unverified / Pending / Verified / Rejected)
class VerificationBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const VerificationBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.toLowerCase();

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (cleanStatus) {
      case 'verified':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.verified_rounded;
        label = 'Verified Donor';
        break;
      case 'pending':
        bgColor = AppColors.warningLight;
        textColor = AppColors.warningDark;
        icon = Icons.hourglass_top_rounded;
        label = 'Verification Pending';
        break;
      case 'rejected':
        bgColor = AppColors.criticalLight;
        textColor = AppColors.critical;
        icon = Icons.cancel_outlined;
        label = 'Verification Action';
        break;
      default:
        bgColor = AppColors.surfaceMuted;
        textColor = AppColors.textSecondary;
        icon = Icons.shield_outlined;
        label = 'Unverified';
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification Bell Icon with Live Real-time Unread Counter
class NotificationBellAction extends StatelessWidget {
  final Color? iconColor;

  const NotificationBellAction({
    super.key,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return StreamBuilder<int>(
      stream: notificationService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                color: iconColor ?? AppColors.textPrimary,
              ),
              tooltip: "Notifications",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.critical,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Dialog to report content or suspicious requests
Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  String selectedReason = 'Commercial / Demanding Payment';
  final TextEditingController detailsCtrl = TextEditingController();
  bool isSubmitting = false;

  final reasons = [
    'Commercial / Demanding Payment',
    'False / Inaccurate Medical Details',
    'Duplicate / Spam Request',
    'Harassment or Inappropriate Behavior',
    'Patient Discharged / Already Resolved',
    'Other Suspicious Activity',
  ];

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.criticalLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded, color: AppColors.critical, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Report Content",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Help keep RedCellNet safe. Why are you reporting this?",
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: reasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Additional details or evidence (optional)...",
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          await RequestService().reportContent(
                            reportedType: targetType,
                            targetId: targetId,
                            reason: selectedReason,
                            details: detailsCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Report submitted. Our moderation team will investigate."),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.critical),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Submit Report"),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Official Lifesaver Certificate Modal Dialog
Future<void> showDonationCertificateDialog(
  BuildContext context, {
  required Map<String, dynamic> donation,
  required String donorName,
  required String bloodType,
}) async {
  final date = donation['date'] != null
      ? (donation['date'] is String
          ? donation['date']
          : donation['date'].toString().split('T').first)
      : 'Recent Donation';
  final facility = donation['center'] ?? donation['hospital'] ?? 'Verified Blood Center';
  final units = donation['units'] ?? 1;

  await showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryLight, width: 2),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Certificate Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 24),
                  ),
                  const Text(
                    "REDCELLNET RECOGNITION",
                    style: TextStyle(
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Certificate of Lifesaving",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Presented in sincere gratitude to",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Text(
                donorName.isNotEmpty ? donorName : "Honorable Donor",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              BloodGroupBadge(bloodType: bloodType, size: 40),
              const SizedBox(height: 14),
              Text(
                "for voluntary donation of $units unit(s) of life-giving blood, bringing hope and health to patients in critical need.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text("DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(date.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    Container(height: 24, width: 1, color: AppColors.border),
                    Column(
                      children: [
                        const Text("FACILITY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(facility.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text("Share Lifesaver Certificate"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Certificate link copied to clipboard! Thank you for saving lives."),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
