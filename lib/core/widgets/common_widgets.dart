// lib/core/widgets/common_widgets.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/notifications/data/services/notification_service.dart';
import 'package:red_cell_net_final/features/notifications/presentation/pages/notifications_page.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:share_plus/share_plus.dart';

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
    final isDark = AppColors.isDark(context);
    final Color bgColor = isOutlined
        ? (isDark ? AppColors.surfaceOf(context) : Colors.white)
        : (isSelected
            ? AppColors.primary
            : (isDark
                ? AppColors.primary.withValues(alpha: 0.22)
                : AppColors.primaryContainer));
    final Color textColor = isOutlined || !isSelected
        ? (isDark ? Colors.white : AppColors.primaryDark)
        : Colors.white;
    final Border border = isOutlined || isSelected
        ? Border.all(color: AppColors.primary, width: isSelected ? 2.0 : 1.2)
        : Border.all(
            color:
                isDark ? AppColors.borderOf(context) : AppColors.primaryLight,
            width: 1.0);

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
    final isDark = AppColors.isDark(context);
    final color = getUrgencyColor(urgency);
    final bg =
        isDark ? color.withValues(alpha: 0.18) : getUrgencyLightColor(urgency);
    final icon = getUrgencyIcon(urgency);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border:
              isDark ? Border.all(color: color.withValues(alpha: 0.35)) : null,
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
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);

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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceMutedOf(context)
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(color: AppColors.borderOf(context))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        color:
                            isDark ? AppColors.primaryLight : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color:
                          isDark ? AppColors.primaryLight : AppColors.primary,
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
    final isDark = AppColors.isDark(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceMutedOf(context)
                    : AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.borderOf(context)
                      : AppColors.primaryLight,
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
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
    final isDark = AppColors.isDark(context);
    final bgColor = isCompatible
        ? (isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.35)
            : const Color(0xFFECFDF5))
        : (isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.35)
            : const Color(0xFFFFFBEB));
    final borderColor = isCompatible ? AppColors.success : AppColors.medium;
    final textColor = isCompatible
        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
        : (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E));

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
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? null : AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isFulfilled
                      ? AppColors.successLight
                      : (isPartial
                          ? AppColors.warningLight
                          : AppColors.surfaceMutedOf(context)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFulfilled ? 'Fulfilled' : '$remainingUnits needed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isFulfilled
                        ? AppColors.success
                        : (isPartial
                            ? AppColors.warningDark
                            : AppColors.textSecondaryOf(context)),
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
              backgroundColor: AppColors.borderOf(context),
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
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
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
                  Text(
                    "Fulfillment Progress",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isFulfilled
                      ? AppColors.successLight
                      : (isPartial
                          ? AppColors.warningLight
                          : (AppColors.isDark(context)
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.primaryContainer)),
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
                        : (isPartial
                            ? AppColors.warningDark
                            : (AppColors.isDark(context)
                                ? AppColors.primaryLight
                                : AppColors.primaryDark)),
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
              backgroundColor: AppColors.surfaceMutedOf(context),
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
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
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
    final isDark = AppColors.isDark(context);
    final cleanStatus = status.toLowerCase().trim();

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (cleanStatus) {
      case 'verified':
        bgColor = isDark
            ? AppColors.success.withValues(alpha: 0.20)
            : AppColors.successLight;
        textColor = isDark ? const Color(0xFF6EE7B7) : AppColors.success;
        icon = Icons.verified_rounded;
        label = 'Verified Donor';
        break;
      case 'pending':
        bgColor = isDark
            ? AppColors.warning.withValues(alpha: 0.20)
            : AppColors.warningLight;
        textColor = isDark ? const Color(0xFFFCD34D) : AppColors.warningDark;
        icon = Icons.hourglass_top_rounded;
        label = 'Verification Pending';
        break;
      case 'rejected':
        bgColor = isDark
            ? AppColors.critical.withValues(alpha: 0.20)
            : AppColors.criticalLight;
        textColor = isDark ? const Color(0xFFFCA5A5) : AppColors.critical;
        icon = Icons.cancel_outlined;
        label = 'Resubmission Needed';
        break;
      default:
        bgColor = AppColors.surfaceMutedOf(context);
        textColor = AppColors.textSecondaryOf(context);
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
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
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

/// Notification Bell Icon with Cached Live Real-time Unread Counter
class NotificationBellAction extends StatefulWidget {
  final Color? iconColor;

  const NotificationBellAction({
    super.key,
    this.iconColor,
  });

  @override
  State<NotificationBellAction> createState() => _NotificationBellActionState();
}

class _NotificationBellActionState extends State<NotificationBellAction> {
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

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                color: widget.iconColor ?? AppColors.textPrimaryOf(context),
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

/// Dialog to report suspicious requests or abusive user profiles
Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final bool isProfile = targetType.toLowerCase() == 'profile';
  final reasons = isProfile
      ? [
          'Commercial Broker / Demanding Payment',
          'Impersonation or Fake Medical Document',
          'Harassment or Abusive Conduct',
          'Repeated No-Show / Unreliable Pledge',
          'Spam or Unauthorized Solicitation',
          'Other Safety Concern',
        ]
      : [
          'Commercial / Demanding Payment',
          'False / Inaccurate Medical Details',
          'Duplicate / Spam Request',
          'Harassment or Inappropriate Behavior',
          'Patient Discharged / Already Resolved',
          'Other Suspicious Activity',
        ];
  String selectedReason = reasons.first;
  final TextEditingController detailsCtrl = TextEditingController();
  bool isSubmitting = false;

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          final isDark = AppColors.isDark(ctx);
          return AlertDialog(
            backgroundColor: AppColors.cardBg(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.critical
                        .withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded,
                      color: AppColors.critical, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isProfile ? "Report User Profile" : "Report Blood Request",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.textPrimaryOf(ctx),
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Help keep RedCellNet safe and strictly voluntary. Select a reason:",
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondaryOf(ctx)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReason,
                    dropdownColor: AppColors.cardBg(ctx),
                    style: TextStyle(
                        color: AppColors.textPrimaryOf(ctx), fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: reasons
                        .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r,
                                style: TextStyle(
                                    color: AppColors.textPrimaryOf(ctx),
                                    fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    style: TextStyle(
                        color: AppColors.textPrimaryOf(ctx), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Additional details or evidence (optional)...",
                      hintStyle: TextStyle(
                          fontSize: 12, color: AppColors.textMutedOf(ctx)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          await RequestService().reportContent(
                            reportedType: isProfile ? 'profile' : 'request',
                            targetId: targetId,
                            reason: selectedReason,
                            details: detailsCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Report submitted. Our moderation team will investigate."),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: AppColors.critical),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text("Submit Report"),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<Uint8List> _buildDonationCertificatePdf({
  required String donorName,
  required String bloodType,
  required String date,
  required String facility,
  required int units,
  required String certificateId,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(32),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: const PdfColor.fromInt(0xFFA41235),
              width: 3,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    'REDCELLNET EMERGENCY BLOOD FULFILLMENT NETWORK',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFFA41235),
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Certificate of Verified Blood Donation',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F172A),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Presented in grateful recognition to',
                    style: const pw.TextStyle(
                      fontSize: 13,
                      color: PdfColor.fromInt(0xFF475569),
                    ),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    donorName.isNotEmpty ? donorName : 'Verified Donor',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFFA41235),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFE4E6),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(20)),
                    ),
                    child: pw.Text(
                      'Blood Group: ${bloodType.isNotEmpty ? bloodType : "Recorded"}  •  Units Donated: $units',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF881337),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'For voluntary, non-remunerated hospital blood donation verified through RedCellNet.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 13,
                      color: PdfColor.fromInt(0xFF334155),
                    ),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FACILITY / HOSPITAL',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF64748B))),
                      pw.SizedBox(height: 2),
                      pw.Text(facility,
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('DONATION DATE',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF64748B))),
                      pw.SizedBox(height: 2),
                      pw.Text(date,
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('CERTIFICATE ID',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF64748B))),
                      pw.SizedBox(height: 2),
                      pw.Text(certificateId,
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
  return doc.save();
}

/// Official Lifesaver Certificate Modal Dialog (Restricted to Verified Hospital Donations)
Future<void> showDonationCertificateDialog(
  BuildContext context, {
  required Map<String, dynamic> donation,
  required String donorName,
  required String bloodType,
}) async {
  final bool isVerifiedDonation = donation['verified'] == true ||
      (donation['certificateId'] != null &&
          donation['certificateId'].toString().trim().isNotEmpty);

  if (!isVerifiedDonation) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Official certificates are issued only for verified hospital donations completed through RedCellNet.',
        ),
        backgroundColor: AppColors.secondary,
      ),
    );
    return;
  }

  final rawDate = donation['date']?.toString() ?? '';
  final date = rawDate.contains('T')
      ? rawDate.split('T').first
      : (rawDate.isNotEmpty ? rawDate : 'Verified Date');
  final facility =
      (donation['center'] ?? donation['hospital'] ?? 'Verified Hospital')
          .toString();
  final int units = int.tryParse('${donation['units'] ?? 1}') ?? 1;
  final String certId =
      (donation['certificateId'] ?? 'RCN-VERIFIED').toString();
  final String safeBloodType =
      bloodType.trim().isNotEmpty ? bloodType.trim() : 'Verified';

  await showDialog(
    context: context,
    builder: (ctx) {
      final isDark = AppColors.isDark(ctx);

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.cardBg(ctx),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderOf(ctx) : AppColors.primaryLight,
              width: 2,
            ),
            boxShadow: isDark ? null : AppColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  Expanded(
                    child: Text(
                      "VERIFIED DONATION • $certId",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textPrimaryOf(ctx)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Certificate of Verified Donation",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimaryOf(ctx),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Presented in sincere gratitude to",
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(ctx),
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Text(
                donorName.isNotEmpty ? donorName : "Verified Donor",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              BloodGroupBadge(bloodType: safeBloodType, size: 42),
              const SizedBox(height: 14),
              Text(
                "for voluntary donation of $units unit(s) of blood verified via RedCellNet hospital coordination.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(ctx),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMutedOf(ctx),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text("DATE",
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondaryOf(ctx))),
                        const SizedBox(height: 2),
                        Text(date,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(ctx))),
                      ],
                    ),
                    Container(
                        height: 24, width: 1, color: AppColors.borderOf(ctx)),
                    Flexible(
                      child: Column(
                        children: [
                          Text("FACILITY",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryOf(ctx))),
                          const SizedBox(height: 2),
                          Text(
                            facility,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(ctx)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                      label: const Text("Export PDF"),
                      onPressed: () async {
                        try {
                          final pdfBytes = await _buildDonationCertificatePdf(
                            donorName: donorName,
                            bloodType: safeBloodType,
                            date: date,
                            facility: facility,
                            units: units,
                            certificateId: certId,
                          );
                          await Printing.sharePdf(
                            bytes: pdfBytes,
                            filename: 'RedCellNet_Certificate_$certId.pdf',
                          );
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('PDF export error: $e'),
                                backgroundColor: AppColors.critical,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text("Share"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await Share.share(
                          'Verified Blood Donation Certificate ($certId)\n'
                          'Donor: ${donorName.isNotEmpty ? donorName : "RedCellNet Donor"} ($safeBloodType)\n'
                          'Facility: $facility\n'
                          'Date: $date • Units: $units\n'
                          'Issued by RedCellNet Emergency Blood Network',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================================
// "LifePulse" Design System - Core Reusable Components
// ============================================================================

/// Frosted Glass container with translucent gradient borders and backdrop blur.
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 14.0,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
    this.border,
    this.gradient,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final effectiveBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        );

    final effectiveGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF161F30).withValues(alpha: 0.75),
                  const Color(0xFF0F172A).withValues(alpha: 0.55),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.75),
                ],
        );

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? effectiveGradient : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: boxShadow ?? (isDark ? null : AppColors.softShadow),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap!();
          },
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}

/// Dynamic Heartbeat Breathing Aura around high-urgency badges.
class PulseUrgencyBadge extends StatefulWidget {
  final String urgency;
  final bool compact;
  final bool enablePulse;

  const PulseUrgencyBadge({
    super.key,
    required this.urgency,
    this.compact = false,
    this.enablePulse = true,
  });

  @override
  State<PulseUrgencyBadge> createState() => _PulseUrgencyBadgeState();
}

class _PulseUrgencyBadgeState extends State<PulseUrgencyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    final isUrgent = widget.urgency.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'high';
    if (widget.enablePulse && isUrgent) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulseUrgencyBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isUrgent = widget.urgency.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'high';
    if (widget.enablePulse && isUrgent && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!isUrgent && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = UrgencyChip.getUrgencyColor(widget.urgency);
    final icon = UrgencyChip.getUrgencyIcon(widget.urgency);
    final isUrgent = widget.urgency.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'high';

    if (!widget.enablePulse || !isUrgent) {
      return UrgencyChip(urgency: widget.urgency, compact: widget.compact);
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(widget.compact ? 8 : 24),
            border: Border.all(
              color: color.withValues(alpha: _glowAnimation.value),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _glowAnimation.value * 0.40),
                blurRadius: 10 + (_glowAnimation.value * 6),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.compact ? 6 : 8,
                height: widget.compact ? 6 : 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (!widget.compact) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                widget.urgency.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: widget.compact ? 10 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tactile Gradient Action Button with haptics, spring feedback, and loading state.
class GradientActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool isLoading;
  final double height;
  final double? width;
  final double borderRadius;
  final Color textColor;
  final bool haptic;

  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.isLoading = false,
    this.height = 52.0,
    this.width,
    this.borderRadius = 16.0,
    this.textColor = Colors.white,
    this.haptic = true,
  });

  @override
  State<GradientActionButton> createState() => _GradientActionButtonState();
}

class _GradientActionButtonState extends State<GradientActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppColors.emergencyGradient;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeInOut,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? effectiveGradient
              : LinearGradient(
                  colors: [Colors.grey.shade600, Colors.grey.shade700],
                ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color:
                        effectiveGradient.colors.first.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onHighlightChanged: (val) {
              setState(() => _isPressed = val);
            },
            onTap: isEnabled
                ? () {
                    if (widget.haptic) HapticFeedback.mediumImpact();
                    widget.onPressed!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon,
                                size: 20, color: widget.textColor),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: widget.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uber/Delivery Style LifeSaver Progress Tracker for Blood Requests.
class LifeSaverTracker extends StatelessWidget {
  final int currentStep; // 0: Posted, 1: Pledged, 2: In Transit, 3: Fulfilled
  final String? statusBadge;

  const LifeSaverTracker({
    super.key,
    required this.currentStep,
    this.statusBadge,
  });

  static const List<Map<String, dynamic>> _defaultSteps = [
    {'title': 'Posted', 'icon': Icons.campaign_rounded},
    {'title': 'Pledged', 'icon': Icons.volunteer_activism_rounded},
    {'title': 'In Transit', 'icon': Icons.directions_bike_rounded},
    {'title': 'Fulfilled', 'icon': Icons.favorite_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
                      color: AppColors.primaryAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "LifeSaver Status Tracker",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              if (statusBadge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentStep >= 3
                        ? AppColors.successLight
                        : AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusBadge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: currentStep >= 3
                          ? AppColors.success
                          : AppColors.primaryAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Steps layout
          Row(
            children: List.generate(_defaultSteps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connecting line
                final stepIndex = index ~/ 2;
                final isDone = stepIndex < currentStep;
                return Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.primaryAccent
                          : (isDark
                              ? const Color(0xFF243048)
                              : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              // Step Node
              final stepIndex = index ~/ 2;
              final isCompleted = stepIndex < currentStep;
              final isCurrent = stepIndex == currentStep;
              final stepData = _defaultSteps[stepIndex];

              Color nodeColor;
              Color iconColor;
              if (isCompleted) {
                nodeColor = AppColors.success;
                iconColor = Colors.white;
              } else if (isCurrent) {
                nodeColor = AppColors.primaryAccent;
                iconColor = Colors.white;
              } else {
                nodeColor =
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
                iconColor =
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
              }

              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: nodeColor,
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: nodeColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : (stepData['icon'] as IconData),
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stepData['title'] as String,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: isCurrent
                          ? AppColors.textPrimaryOf(context)
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Interactive 3D Flippable Digital Donor Pass Card (Apple/Google Wallet Style).
class DigitalPassCard extends StatefulWidget {
  final String donorName;
  final String bloodType;
  final String donorId;
  final bool isVerified;
  final int totalDonations;
  final int livesSaved;
  final String lastDonationDate;
  final String nextEligibleDate;
  final String emergencyContact;

  const DigitalPassCard({
    super.key,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    required this.isVerified,
    required this.totalDonations,
    required this.livesSaved,
    required this.lastDonationDate,
    required this.nextEligibleDate,
    required this.emergencyContact,
  });

  @override
  State<DigitalPassCard> createState() => _DigitalPassCardState();
}

class _DigitalPassCardState extends State<DigitalPassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.mediumImpact();
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;
          final isUnder = angle > (math.pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: isUnder
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildBackFace(),
                  )
                : _buildFrontFace(),
          );
        },
      ),
    );
  }

  Widget _buildFrontFace() {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF881337), // Rose 900
            Color(0xFF4C0519), // Rose 950
            Color(0xFF0F172A), // Slate 900
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Brand & Blood Group Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFF43F5E),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "REDCELLNET",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "OFFICIAL DIGITAL DONOR PASS",
                            style: TextStyle(
                              color: Color(0xFFFDA4AF),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.bloodType.trim().isNotEmpty
                      ? const Color(0xFFE11D48)
                      : Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: widget.bloodType.trim().isNotEmpty
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFFE11D48).withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  widget.bloodType.trim().isNotEmpty
                      ? widget.bloodType.trim()
                      : 'Unset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.bloodType.trim().isNotEmpty ? 18 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          // Middle: Donor Name & ID
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.donorName.isNotEmpty
                          ? widget.donorName.toUpperCase()
                          : "COMMUNITY MEMBER",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF34D399),
                      size: 18,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "ID: ${widget.donorId.isNotEmpty ? widget.donorId : 'UNASSIGNED'}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          // Bottom Stats: Donations, Lives Saved & Tap to Flip hint
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildStatBadge("DONATIONS", "${widget.totalDonations}"),
                  const SizedBox(width: 12),
                  _buildStatBadge("LIVES SAVED", "up to ${widget.livesSaved}"),
                ],
              ),
              Row(
                children: [
                  Text(
                    "TAP TO FLIP",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.flip_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackFace() {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
            Color(0xFF111827), // Gray 900
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "MEDICAL & EMERGENCY CREDENTIALS",
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(
                Icons.qr_code_2_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackInfoItem(
                      "LAST DONATION",
                      widget.lastDonationDate.isNotEmpty
                          ? widget.lastDonationDate
                          : "No donations logged",
                    ),
                    const SizedBox(height: 10),
                    _buildBackInfoItem(
                      "NEXT ELIGIBILITY",
                      widget.nextEligibleDate.isNotEmpty
                          ? widget.nextEligibleDate
                          : "Eligible Now",
                    ),
                    const SizedBox(height: 10),
                    _buildBackInfoItem(
                      "EMERGENCY CONTACT",
                      widget.emergencyContact.isNotEmpty
                          ? widget.emergencyContact
                          : "Not specified",
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data:
                      'REDCELLNET|ID:${widget.donorId}|BG:${widget.bloodType.isNotEmpty ? widget.bloodType : "UNSET"}|VERIFIED:${widget.isVerified}',
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.isVerified
                      ? "VERIFIED BY REDCELLNET STAFF"
                      : "SELF-REPORTED • HOSPITAL CROSS-MATCH REQUIRED",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isVerified
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFCD34D),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    "FLIP BACK",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.flip_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
