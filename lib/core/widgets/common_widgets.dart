// lib/core/widgets/common_widgets.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/push_notification_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/features/notifications/data/services/notification_service.dart';
import 'package:red_cell_net_final/features/notifications/presentation/pages/notifications_page.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Custom vector-rendered RedCellNet "LifePulse" Brand Logo.
/// Combines a 3D-graded arterial crimson blood droplet, glowing ECG lifeline wave,
/// geometric medical cross, and interconnected donor network nodes.
class RedCellNetLogo extends StatelessWidget {
  final double size;
  final bool showPulseGlow;
  final bool isMonochromeWhite;

  const RedCellNetLogo({
    super.key,
    this.size = 56.0,
    this.showPulseGlow = true,
    this.isMonochromeWhite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'RedCellNet LifePulse Logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isMonochromeWhite
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const RadialGradient(
                  center: Alignment(-0.2, -0.25),
                  radius: 0.95,
                  colors: [
                    Color(0xFF2A0915),
                    Color(0xFF14050B),
                    Color(0xFF090B12),
                  ],
                ),
          border: Border.all(
            color: isMonochromeWhite
                ? Colors.white.withValues(alpha: 0.32)
                : const Color(0xFFF41C47).withValues(alpha: 0.45),
            width: size * 0.032,
          ),
          boxShadow: showPulseGlow
              ? [
                  BoxShadow(
                    color: const Color(0xFFF41C47).withValues(alpha: 0.35),
                    blurRadius: size * 0.35,
                    spreadRadius: size * 0.02,
                    offset: Offset(0, size * 0.08),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          size: Size.square(size),
          painter: _RedCellNetLogoPainter(
            isMonochromeWhite: isMonochromeWhite,
          ),
        ),
      ),
    );
  }
}

class _RedCellNetLogoPainter extends CustomPainter {
  final bool isMonochromeWhite;

  const _RedCellNetLogoPainter({this.isMonochromeWhite = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    // 1. Blood Drop Silhouette Path
    final dropPath = Path()
      ..moveTo(cx, h * 0.14)
      ..cubicTo(
        w * 0.68,
        h * 0.36,
        w * 0.80,
        h * 0.52,
        w * 0.80,
        h * 0.64,
      )
      ..arcToPoint(
        Offset(w * 0.20, h * 0.64),
        radius: Radius.circular(w * 0.30),
        clockwise: true,
      )
      ..cubicTo(
        w * 0.20,
        h * 0.52,
        w * 0.32,
        h * 0.36,
        cx,
        h * 0.14,
      )
      ..close();

    final dropPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF3358),
          Color(0xFFD9143C),
          Color(0xFF8A0A25),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(dropPath, dropPaint);

    // 2. Specular 3D Left Rim Highlight
    final highlightPath = Path()
      ..moveTo(cx * 0.92, h * 0.24)
      ..quadraticBezierTo(w * 0.28, h * 0.50, w * 0.30, h * 0.68);
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.038
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(highlightPath, highlightPaint);

    // 3. Subtle Geometric Medical Cross inside upper-right of drop
    final crossColor = Colors.white.withValues(alpha: 0.92);
    final crossPaint = Paint()..color = crossColor;
    final crossCx = w * 0.58;
    final crossCy = h * 0.45;
    final armL = w * 0.13;
    final armT = w * 0.048;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(crossCx, crossCy), width: armL, height: armT),
        Radius.circular(w * 0.012),
      ),
      crossPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(crossCx, crossCy), width: armT, height: armL),
        Radius.circular(w * 0.012),
      ),
      crossPaint,
    );

    // 4. Connected Donor Network Nodes
    final nodePaint = Paint()
      ..color = const Color(0xFFFDA4AF).withValues(alpha: 0.70)
      ..strokeWidth = w * 0.014;
    final p1 = Offset(w * 0.36, h * 0.46);
    final p2 = Offset(w * 0.45, h * 0.37);
    final p3 = Offset(w * 0.66, h * 0.68);
    canvas.drawLine(p1, p2, nodePaint);
    canvas.drawCircle(p1, w * 0.022, Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawCircle(p2, w * 0.020, Paint()..color = const Color(0xFFFDA4AF));
    canvas.drawCircle(p3, w * 0.020, Paint()..color = const Color(0xFFFDA4AF));

    // 5. Glowing ECG Heartbeat Lifeline Wave across the droplet
    final ecgPath = Path()
      ..moveTo(w * 0.21, h * 0.62)
      ..lineTo(w * 0.33, h * 0.62)
      ..lineTo(w * 0.37, h * 0.55)
      ..lineTo(w * 0.41, h * 0.67)
      ..lineTo(w * 0.46, h * 0.42)
      ..lineTo(w * 0.51, h * 0.74)
      ..lineTo(w * 0.56, h * 0.59)
      ..lineTo(w * 0.61, h * 0.62)
      ..lineTo(w * 0.79, h * 0.62);

    final ecgGlowPaint = Paint()
      ..color = const Color(0xFFFFB4C2).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(ecgPath, ecgGlowPaint);

    final ecgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(ecgPath, ecgPaint);
  }

  @override
  bool shouldRepaint(covariant _RedCellNetLogoPainter oldDelegate) =>
      oldDelegate.isMonochromeWhite != isMonochromeWhite;
}

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

/// Interactive 3D Flippable Digital Donor Pass Card (Apple/Google Wallet Style)
/// with All-in-One Donor Details, Tier Color Grading, Holographic Sheen,
/// Multi-Tab Back Face, Fullscreen QR, Home Screen Widget Pinning, Referral Code,
/// and Official Printable PDF + High-Res PNG Card Export.
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

  // All-in-One Donor Details & Zero-Cost Pass Features
  final String? nickname;
  final String? email;
  final String? phone;
  final String? verificationStatus;
  final bool isAvailable;
  final int points;
  final int streakCount;
  final bool isStreakFrozen;
  final String? streakFreezeReason;
  final bool isEligible;
  final int daysUntilEligible;
  final String? city;
  final bool isPhoneVerified;
  final String? medicalNotes;
  final String? referralCode;
  final int referralCount;
  final bool showActionDock;
  final ValueChanged<bool>? onStreakFreezeChanged;
  final VoidCallback? onOpenReferralSheet;

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
    this.nickname,
    this.email,
    this.phone,
    this.verificationStatus,
    this.isAvailable = false,
    this.points = 0,
    this.streakCount = 0,
    this.isStreakFrozen = false,
    this.streakFreezeReason,
    this.isEligible = true,
    this.daysUntilEligible = 0,
    this.city,
    this.isPhoneVerified = false,
    this.medicalNotes,
    this.referralCode,
    this.referralCount = 0,
    this.showActionDock = false,
    this.onStreakFreezeChanged,
    this.onOpenReferralSheet,
  });

  @override
  State<DigitalPassCard> createState() => _DigitalPassCardState();
}

class _DigitalPassCardState extends State<DigitalPassCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;
  int _backSubTab = 0; // 0: QR & Medical, 1: Compatibility, 2: Perks & Notes
  bool _isExportingImage = false;
  late bool _localStreakFrozen;

  @override
  void initState() {
    super.initState();
    _localStreakFrozen =
        widget.isStreakFrozen || AppSettingsService().isStreakFrozen;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant DigitalPassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStreakFrozen != widget.isStreakFrozen) {
      _localStreakFrozen = widget.isStreakFrozen;
    }
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
    setState(() {
      _isFront = !_isFront;
    });
  }

  String get _tierLabel {
    if (_localStreakFrozen) return 'MEDICAL FREEZE';
    if (widget.totalDonations >= 5 || widget.points >= 500) {
      return 'GOLD GUARDIAN';
    }
    if (widget.totalDonations >= 2 || widget.points >= 200) {
      return 'SILVER HERO';
    }
    if (widget.totalDonations >= 1 || widget.isVerified) {
      return 'VERIFIED LIFESAVER';
    }
    return 'LIFEPULSE PASS';
  }

  String get _verificationBadgeText {
    if (widget.isVerified ||
        (widget.verificationStatus ?? '').toLowerCase() == 'approved') {
      return 'Verified by RedCellNet';
    }
    return 'Verification Pending';
  }

  LinearGradient get _frontGradient {
    if (_localStreakFrozen) return AppColors.passFrozenGradient;
    if (widget.totalDonations >= 5 || widget.points >= 500) {
      return AppColors.passGoldGuardianGradient;
    }
    if (widget.totalDonations >= 2 || widget.points >= 200) {
      return AppColors.passSilverHeroGradient;
    }
    return AppColors.passCrimsonGradient;
  }

  Color get _tierGlowColor {
    if (_localStreakFrozen) return AppColors.freezeIce;
    if (widget.totalDonations >= 5 || widget.points >= 500) {
      return AppColors.imperialGold;
    }
    if (widget.totalDonations >= 2 || widget.points >= 200) {
      return AppColors.secondary;
    }
    return AppColors.primaryAccent;
  }

  String get _effectiveReferralCode {
    if (widget.referralCode != null && widget.referralCode!.trim().isNotEmpty) {
      return widget.referralCode!.trim();
    }
    return AppSettingsService.generateReferralCode(
      userId: widget.donorId,
      fullName: widget.donorName,
      bloodGroup: widget.bloodType,
    );
  }

  String get _qrPayload =>
      'REDCELLNET|ID:${widget.donorId}|BG:${widget.bloodType.isNotEmpty ? widget.bloodType : "UNSET"}|VERIFIED:${widget.isVerified}|TIER:$_tierLabel|DONATIONS:${widget.totalDonations}';

  Future<Uint8List> _buildOfficialDonorCardPdf() async {
    final doc = pw.Document();
    final safeBg =
        widget.bloodType.trim().isNotEmpty ? widget.bloodType.trim() : 'Unset';
    final safeName = widget.donorName.trim().isNotEmpty
        ? widget.donorName.trim()
        : 'RedCellNet Donor';
    final safeCity = (widget.city ?? '').trim().isNotEmpty
        ? widget.city!.trim()
        : 'Bangladesh';
    final safePhone = (widget.phone ?? '').trim().isNotEmpty
        ? widget.phone!.trim()
        : 'On File';
    final safeEmail = (widget.email ?? '').trim().isNotEmpty
        ? widget.email!.trim()
        : 'On File';
    final safeIce = widget.emergencyContact.trim().isNotEmpty
        ? widget.emergencyContact.trim()
        : 'Not Specified';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Official Card Front
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF881337),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(18)),
                  border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFF43F5E),
                    width: 2,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'REDCELLNET',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'OFFICIAL DIGITAL DONOR PASS • $_tierLabel',
                              style: const pw.TextStyle(
                                color: PdfColor.fromInt(0xFFFDA4AF),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFE11D48),
                            borderRadius:
                                pw.BorderRadius.all(pw.Radius.circular(12)),
                          ),
                          child: pw.Text(
                            safeBg,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      safeName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '$_verificationBadgeText  •  Donor ID: ${widget.donorId}  •  City: $safeCity',
                      style: pw.TextStyle(
                        color: widget.isVerified
                            ? const PdfColor.fromInt(0xFF6EE7B7)
                            : const PdfColor.fromInt(0xFFFDE68A),
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Divider(color: const PdfColor.fromInt(0xFFFDA4AF)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('PHONE',
                                style: const pw.TextStyle(
                                    color: PdfColor.fromInt(0xFFFDA4AF),
                                    fontSize: 8)),
                            pw.Text(safePhone,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('EMAIL',
                                style: const pw.TextStyle(
                                    color: PdfColor.fromInt(0xFFFDA4AF),
                                    fontSize: 8)),
                            pw.Text(safeEmail,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('DONATIONS / LIVES SAVED',
                                style: const pw.TextStyle(
                                    color: PdfColor.fromInt(0xFFFDA4AF),
                                    fontSize: 8)),
                            pw.Text(
                                '${widget.totalDonations} Units / up to ${widget.livesSaved} Lives',
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // Official Card Back (Credentials & QR)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF0F172A),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(18)),
                  border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFF334155),
                    width: 1.5,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MEDICAL & EMERGENCY CREDENTIALS (BACK)',
                            style: pw.TextStyle(
                              color: const PdfColor.fromInt(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'Last Donation: ${widget.lastDonationDate.isNotEmpty ? widget.lastDonationDate : "None Logged"}',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Next Eligible: ${widget.nextEligibleDate.isNotEmpty ? widget.nextEligibleDate : "Eligible Now"}',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Emergency ICE Contact: $safeIce',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Medical Notes: ${(widget.medicalNotes ?? "").trim().isNotEmpty ? widget.medicalNotes!.trim() : "None recorded"}',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Invite Code: $_effectiveReferralCode',
                            style: pw.TextStyle(
                              color: const PdfColor.fromInt(0xFF34D399),
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: _qrPayload,
                        width: 96,
                        height: 96,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> _exportAndSharePassImage() async {
    if (_isExportingImage) return;
    setState(() => _isExportingImage = true);
    try {
      HapticFeedback.lightImpact();
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'RedCellNet_Donor_Pass_${widget.donorId}.png',
      );
      await Share.shareXFiles(
        [xFile],
        text:
            '🩸 Official RedCellNet Digital Donor Pass — ${widget.donorName} (${widget.bloodType.trim().isNotEmpty ? widget.bloodType.trim() : "Donor"}) • $_verificationBadgeText • Invite Code: $_effectiveReferralCode',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export pass image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingImage = false);
    }
  }

  Future<void> _showExportPassOptionsSheet() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export & Share Official Donor Pass',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(ctx),
                            ),
                          ),
                          Text(
                            'Share your verified digital pass or print a 2-sided PDF card',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.borderOf(ctx)),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Export 2-Sided Printable PDF Card',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Includes Front + Back, QR Code, ICE Contact & Verification Badge',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pdfBytes = await _buildOfficialDonorCardPdf();
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename: 'RedCellNet_Official_Pass_${widget.donorId}.pdf',
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.borderOf(ctx)),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.secondary,
                    child:
                        Icon(Icons.image_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Share High-Resolution PNG Pass Image',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const Text(
                    '3.5x HD pass card image ready for WhatsApp, Messenger or Gallery',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _exportAndSharePassImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFullscreenQrModal() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0B1120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      RedCellNetLogo(size: 32, showPulseGlow: false),
                      SizedBox(width: 10),
                      Text(
                        'HOSPITAL CHECK-IN QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _tierGlowColor.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrPayload,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.donorName.isNotEmpty
                    ? widget.donorName.toUpperCase()
                    : 'COMMUNITY MEMBER',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${widget.donorId} • Blood Group: ${widget.bloodType.trim().isNotEmpty ? widget.bloodType.trim() : "Unset"}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.isVerified
                      ? '✓ Verified Lab Credential on File'
                      : '⚠ Self-Reported • Mandatory Hospital Cross-Match Required',
                  style: TextStyle(
                    color: widget.isVerified
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFCD34D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMedicalStreakFreezeDialog() async {
    final nextState = !_localStreakFrozen;
    String selectedReason = 'Temporary Illness / Fever Recovery';
    final reasons = <String>[
      'Temporary Illness / Fever Recovery',
      'Low Hemoglobin / Iron Supplementation',
      'Recent Dental / Minor Medical Procedure',
      'Pregnancy / Postpartum Deferral',
      'Vaccination / Travel Deferral',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                nextState ? Icons.ac_unit_rounded : Icons.local_fire_department_rounded,
                color: nextState ? AppColors.freezeIce : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nextState
                      ? 'Activate Medical Streak Freeze'
                      : 'Resume Active Donor Streak',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nextState
                    ? 'Never lose your donation streak due to health or medical deferrals. Freezing pauses streak decay while prioritizing your clinical safety.'
                    : 'Your medical deferral freeze will be lifted and your normal donation streak counter will resume.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(ctx),
                  height: 1.4,
                ),
              ),
              if (nextState) ...[
                const SizedBox(height: 14),
                const Text(
                  'Deferral Reason (Private):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  items: reasons
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              r,
                              style: const TextStyle(fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedReason = v);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    nextState ? AppColors.secondary : AppColors.primary,
              ),
              child: Text(nextState ? 'Freeze Streak ❄️' : 'Resume Streak 🔥'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await AppSettingsService().setStreakFreezeState(
        nextState,
        reason: nextState ? selectedReason : null,
      );
      if (mounted) {
        setState(() => _localStreakFrozen = nextState);
      }
      widget.onStreakFreezeChanged?.call(nextState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final cardWidget = RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Semantics(
        button: true,
        label:
            'RedCellNet Digital Donor Pass for ${widget.donorName}. Blood Group ${widget.bloodType.trim().isNotEmpty ? widget.bloodType.trim() : "Unset"}. Tap to flip card.',
        child: GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle =
                  (reduceMotion ? (_isFront ? 0.0 : 1.0) : _flipAnimation.value) *
                      math.pi;
              final isUnder = angle > (math.pi / 2);

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
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
        ),
      ),
    );

    if (!widget.showActionDock) {
      return cardWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cardWidget,
        const SizedBox(height: 12),
        _buildActionDock(context),
      ],
    );
  }

  Widget _buildActionDock(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.92)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockAction(
            icon: _isExportingImage
                ? Icons.hourglass_top_rounded
                : Icons.ios_share_rounded,
            label: 'Export Card',
            color: AppColors.primary,
            onTap: _showExportPassOptionsSheet,
          ),
          _buildDockAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Hospital QR',
            color: AppColors.secondary,
            onTap: _openFullscreenQrModal,
          ),
          _buildDockAction(
            icon: _localStreakFrozen
                ? Icons.ac_unit_rounded
                : Icons.local_fire_department_rounded,
            label: _localStreakFrozen ? 'Frozen ❄️' : 'Streak Freeze',
            color: _localStreakFrozen ? AppColors.freezeIce : AppColors.warning,
            onTap: _showMedicalStreakFreezeDialog,
          ),
          _buildDockAction(
            icon: Icons.card_giftcard_rounded,
            label: 'Invite +50',
            color: AppColors.vitalEmerald,
            onTap: () {
              if (widget.onOpenReferralSheet != null) {
                widget.onOpenReferralSheet!();
              } else {
                showReferralProgramSheet(
                  context,
                  referralCode: _effectiveReferralCode,
                  referralCount: widget.referralCount,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDockAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontFace() {
    final hasBg = widget.bloodType.trim().isNotEmpty;
    final effectiveStreak = widget.streakCount > 0
        ? widget.streakCount
        : (widget.totalDonations > 0 ? 1 : 0);
    final safeCity = (widget.city ?? '').trim().isNotEmpty
        ? widget.city!.trim()
        : 'Bangladesh';
    final safePhone = (widget.phone ?? '').trim().isNotEmpty
        ? widget.phone!.trim()
        : 'Not set';
    final safeEmail = (widget.email ?? '').trim().isNotEmpty
        ? widget.email!.trim()
        : 'Not set';
    final safeLastDonation = widget.lastDonationDate.trim().isNotEmpty
        ? widget.lastDonationDate.trim()
        : 'No donations yet';
    final safeNextEligible = widget.nextEligibleDate.trim().isNotEmpty
        ? widget.nextEligibleDate.trim()
        : 'Eligible Now';
    final safeNickname = (widget.nickname ?? '').trim();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 336),
      decoration: BoxDecoration(
        gradient: _frontGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _tierGlowColor.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Holographic Iridescent Sheen + Subtle ECG Lifeline Watermark
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: AppColors.holographicSheenGradient,
                  ),
                  child: CustomPaint(
                    painter: _PassEcgWatermarkPainter(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Spacious Top Header: Brand Logo + Full "REDCELLNET" Title + Blood Group Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const RedCellNetLogo(
                        size: 40,
                        showPulseGlow: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REDCELLNET',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'OFFICIAL DIGITAL DONOR PASS • $_tierLabel',
                              style: const TextStyle(
                                color: Color(0xFFFDA4AF),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 7),
                        decoration: BoxDecoration(
                          color: hasBg
                              ? const Color(0xFFE11D48)
                              : Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.2,
                          ),
                          boxShadow: hasBg
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFE11D48)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          hasBg ? widget.bloodType.trim() : 'Unset',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: hasBg ? 19 : 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Donor Name, Nickname & Verification Badge Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.donorName.isNotEmpty
                                  ? widget.donorName.toUpperCase()
                                  : 'COMMUNITY MEMBER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (safeNickname.isNotEmpty)
                              Text(
                                'Preferred Name: $safeNickname',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3. Status Chips Row: Verified by RedCellNet / Verification Pending, Readiness, Streak
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: widget.isVerified
                              ? const Color(0xFF10B981).withValues(alpha: 0.26)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isVerified
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isVerified
                                  ? Icons.verified_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 12,
                              color: widget.isVerified
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFFDE68A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _verificationBadgeText,
                              style: TextStyle(
                                color: widget.isVerified
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFFFDE68A),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: (widget.isEligible &&
                                  widget.daysUntilEligible <= 0)
                              ? const Color(0xFF10B981).withValues(alpha: 0.22)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (widget.isEligible && widget.daysUntilEligible <= 0)
                              ? '● READY TO DONATE'
                              : '⏳ ${widget.daysUntilEligible}d RECOVERY',
                          style: TextStyle(
                            color: (widget.isEligible &&
                                    widget.daysUntilEligible <= 0)
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFDE68A),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: _localStreakFrozen
                              ? const Color(0xFF0EA5E9).withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _localStreakFrozen
                              ? '❄️ FROZEN'
                              : '🔥 $effectiveStreak STREAK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. All-in-One Donor Details Grid Inside the Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardDetailCell(
                                icon: Icons.fingerprint_rounded,
                                label: 'DONOR ID',
                                value: widget.donorId.isNotEmpty
                                    ? widget.donorId
                                    : 'UNASSIGNED',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCardDetailCell(
                                icon: Icons.location_on_outlined,
                                label: 'CITY',
                                value: safeCity,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardDetailCell(
                                icon: Icons.phone_outlined,
                                label: 'PHONE',
                                value: safePhone,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCardDetailCell(
                                icon: Icons.email_outlined,
                                label: 'EMAIL',
                                value: safeEmail,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardDetailCell(
                                icon: Icons.history_rounded,
                                label: 'LAST DONATION',
                                value: safeLastDonation,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCardDetailCell(
                                icon: Icons.event_available_rounded,
                                label: 'NEXT ELIGIBLE',
                                value: safeNextEligible,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Bottom Stats: Donations, Lives Saved, Points & Flip Hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildStatBadge(
                                'DONATIONS', '${widget.totalDonations}'),
                            _buildStatBadge(
                                'LIVES SAVED', 'up to ${widget.livesSaved}'),
                            _buildStatBadge('IMPACT', '${widget.points} pts'),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'FLIP FOR QR',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.flip_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetailCell({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: const Color(0xFFFDA4AF)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackFace() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 336),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF080D1A),
            Color(0xFF141E33),
            Color(0xFF0B1120),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Header + Interactive Mini Sub-Tabs on Back Face
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'MEDICAL & EMERGENCY CREDENTIALS',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBackTabPill(0, 'QR & ICE'),
                  const SizedBox(width: 4),
                  _buildBackTabPill(1, 'Match'),
                  const SizedBox(width: 4),
                  _buildBackTabPill(2, 'Referral'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Back Body based on selected sub-tab
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _backSubTab == 0
                ? _buildBackQrAndMedicalTab()
                : _backSubTab == 1
                    ? _buildBackCompatibilityTab()
                    : _buildBackPerksTab(),
          ),
          const SizedBox(height: 12),

          // Footer: Verification Status & Flip Back
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.isVerified
                      ? '✓ VERIFIED BY REDCELLNET'
                      : '⏳ VERIFICATION PENDING • HOSPITAL CROSS-MATCH REQUIRED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isVerified
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFCD34D),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    'FLIP TO FRONT',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.flip_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackTabPill(int index, String title) {
    final active = _backSubTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _backSubTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryAccent
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildBackQrAndMedicalTab() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackInfoItem(
                'EMERGENCY ICE CONTACT',
                widget.emergencyContact.isNotEmpty
                    ? widget.emergencyContact
                    : 'Not specified (Tap Edit ICE below)',
              ),
              const SizedBox(height: 10),
              _buildBackInfoItem(
                'MEDICAL / ALLERGY NOTES',
                (widget.medicalNotes ?? '').trim().isNotEmpty
                    ? widget.medicalNotes!.trim()
                    : 'No allergies or conditions recorded',
              ),
              const SizedBox(height: 10),
              _buildBackInfoItem(
                'LAST DONATION & NEXT ELIGIBLE',
                '${widget.lastDonationDate.isNotEmpty ? widget.lastDonationDate : "None"}  •  ${widget.nextEligibleDate.isNotEmpty ? widget.nextEligibleDate : "Eligible Now"}',
              ),
              const SizedBox(height: 10),
              _buildBackInfoItem(
                'PERSONAL INVITE CODE',
                '$_effectiveReferralCode (${widget.referralCount} joined)',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _openFullscreenQrModal,
          child: Column(
            children: [
              Container(
                width: 98,
                height: 98,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: _qrPayload,
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'TAP TO ENLARGE',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackCompatibilityTab() {
    final bg = widget.bloodType.trim().toUpperCase();
    final donateTo = BloodCompatibility.canDonateTo(bg);
    final receiveFrom = BloodCompatibility.canReceiveFrom(bg);

    if (bg.isEmpty || donateTo.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Set your blood group in Profile to view instant RBC & Plasma compatibility rules on your pass.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackInfoItem(
          'CAN DONATE RED CELLS TO (${donateTo.length} GROUPS)',
          donateTo.join('  •  '),
        ),
        const SizedBox(height: 10),
        _buildBackInfoItem(
          'CAN RECEIVE RED CELLS FROM (${receiveFrom.length} GROUPS)',
          receiveFrom.join('  •  '),
        ),
        const SizedBox(height: 10),
        _buildBackInfoItem(
          'CLINICAL ROLE',
          bg == 'O-'
              ? 'Universal Red Cell Donor (Emergency Trauma Priority)'
              : bg == 'AB+'
                  ? 'Universal Red Cell Recipient & Universal Plasma Donor'
                  : 'Standard ABO/Rh Type-Specific Donor',
        ),
      ],
    );
  }

  Widget _buildBackPerksTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackInfoItem(
          'PERSONAL INVITE & REFERRAL CODE',
          '$_effectiveReferralCode  •  ${widget.referralCount} Donors Invited (+${widget.referralCount * 50} pts)',
        ),
        const SizedBox(height: 10),
        _buildBackInfoItem(
          'STREAK PROTECTION STATUS',
          _localStreakFrozen
              ? '❄️ Medical Freeze Active (${widget.streakFreezeReason ?? "Protected"})'
              : '🔥 Active Streak Tracking (Medical Freeze Available)',
        ),
        const SizedBox(height: 10),
        _buildBackInfoItem(
          'VERIFICATION STATUS',
          _verificationBadgeText,
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
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
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PassEcgWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.68)
      ..lineTo(size.width * 0.35, size.height * 0.68)
      ..lineTo(size.width * 0.42, size.height * 0.52)
      ..lineTo(size.width * 0.47, size.height * 0.78)
      ..lineTo(size.width * 0.54, size.height * 0.28)
      ..lineTo(size.width * 0.60, size.height * 0.84)
      ..lineTo(size.width * 0.66, size.height * 0.62)
      ..lineTo(size.width * 0.72, size.height * 0.68)
      ..lineTo(size.width, size.height * 0.68);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ZERO-COST UI & FEATURE WIDGETS
// ============================================================================

/// Shimmer skeleton box that respects Reduce Motion accessibility settings.
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 14,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final baseColor =
        isDark ? const Color(0xFF1A2336) : const Color(0xFFE2E8F0);
    final highlightColor =
        isDark ? const Color(0xFF283550) : const Color(0xFFF1F5F9);

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, _controller.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder matching the geometry of an emergency blood request card.
class RequestCardSkeleton extends StatelessWidget {
  const RequestCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: const Row(
        children: [
          ShimmerSkeleton(width: 50, height: 50, borderRadius: 16),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: 160, height: 15, borderRadius: 6),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 220, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 110, height: 10, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual 90-day WHO Recovery Countdown Ring with 1-tap notification reminder.
class EligibilityCountdownRing extends StatelessWidget {
  final int daysRemaining;
  final int totalCooldownDays;
  final String? bloodType;
  final DateTime? nextEligibleDate;
  final double size;

  const EligibilityCountdownRing({
    super.key,
    required this.daysRemaining,
    this.totalCooldownDays = 90,
    this.bloodType,
    this.nextEligibleDate,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalCooldownDays <= 0 ? 90 : totalCooldownDays;
    final clampedRemaining = daysRemaining.clamp(0, safeTotal);
    final progress =
        ((safeTotal - clampedRemaining) / safeTotal).clamp(0.0, 1.0);
    final isReady = clampedRemaining <= 0;
    final ringColor = isReady ? AppColors.vitalEmerald : AppColors.warning;

    return Semantics(
      label: isReady
          ? 'Eligible to donate now, 100 percent recovered'
          : '$clampedRemaining days remaining in 90 day recovery window',
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          PushNotificationService().showEligibilityCountdownReminder(
            daysRemaining: clampedRemaining,
            bloodType: bloodType,
            nextEligibleDate: nextEligibleDate,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isReady
                    ? '🩸 You are 100% ready to donate!'
                    : '🔔 Recovery reminder armed ($clampedRemaining days remaining).',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(size),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: ringColor.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isReady
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_bottom_rounded,
                    size: size * 0.26,
                    color: ringColor,
                  ),
                  Text(
                    isReady ? 'READY' : '${clampedRemaining}d',
                    style: TextStyle(
                      fontSize: size * 0.17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the Community Leaderboard & Monthly Heroes Bottom Sheet.
Future<void> showCommunityLeaderboardSheet(
  BuildContext context, {
  String? userCity,
  String? referralCode,
}) async {
  final service = UserProfileService();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String? filterCity;
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderOf(ctx),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community Heroes Leaderboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(ctx),
                            ),
                          ),
                          Text(
                            'Privacy-safe anonymized verified lifesavers',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (userCity != null && userCity.trim().isNotEmpty)
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All Bangladesh'),
                        selected: filterCity == null,
                        onSelected: (_) =>
                            setSheetState(() => filterCity = null),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(userCity),
                        selected: filterCity == userCity,
                        onSelected: (_) =>
                            setSheetState(() => filterCity = userCity),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: service.getCommunityLeaderboard(city: filterCity),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          itemCount: 4,
                          itemBuilder: (_, __) => const RequestCardSkeleton(),
                        );
                      }
                      final leaders = snap.data ?? const [];
                      return ListView.separated(
                        itemCount: leaders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = leaders[i];
                          final rank = item['rank'] ?? (i + 1);
                          final name =
                              (item['display_name'] ?? 'Lifesaver').toString();
                          final bg = (item['blood_type'] ?? 'O+').toString();
                          final city = (item['city'] ?? 'Bangladesh').toString();
                          final donations = item['total_donations'] ?? 0;
                          final pts = item['points'] ?? 0;
                          final tier =
                              (item['tier'] ?? 'Verified Hero').toString();

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.mutedOf(ctx),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: i == 0
                                    ? AppColors.imperialGold
                                        .withValues(alpha: 0.5)
                                    : AppColors.borderOf(ctx),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: i == 0
                                      ? AppColors.imperialGold
                                      : i == 1
                                          ? AppColors.secondary
                                          : AppColors.primary,
                                  child: Text(
                                    '#$rank',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color:
                                                    AppColors.textPrimaryOf(ctx),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified_rounded,
                                              size: 15,
                                              color: AppColors.vitalEmerald),
                                        ],
                                      ),
                                      Text(
                                        '$city • $tier • $donations Donations',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondaryOf(ctx),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                BloodGroupBadge(bloodType: bg, size: 36),
                                const SizedBox(width: 10),
                                Text(
                                  '$pts pts',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.imperialGold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (referralCode != null && referralCode.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.diversity_3_rounded,
                            color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Invite a Donor • Earn +50 Impact Points',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                'Your Code: $referralCode',
                                style: const TextStyle(
                                  color: Color(0xFFFDA4AF),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            showReferralProgramSheet(
                              context,
                              referralCode: referralCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Referral Hub'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

/// Interactive Referral & Invite Program Sheet (Share Code + Redeem Friend's Code).
Future<void> showReferralProgramSheet(
  BuildContext context, {
  String? referralCode,
  int referralCount = 0,
  String? referredBy,
}) async {
  final service = UserProfileService();
  final codeController = TextEditingController();
  bool isSubmitting = false;
  String? statusMsg;
  bool isSuccess = false;
  final effectiveCode = (referralCode != null && referralCode.trim().isNotEmpty)
      ? referralCode.trim()
      : AppSettingsService.generateReferralCode(
          userId: SupabaseConfig.client.auth.currentUser?.id,
        );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderOf(ctx),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lifesaver Referral Program',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(ctx),
                            ),
                          ),
                          Text(
                            'Invite donors (+50 pts) or redeem a friend\'s code (+25 pts)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Your Invite Code Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.passCrimsonGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'YOUR PERSONAL INVITE CODE',
                            style: TextStyle(
                              color: Color(0xFFFDA4AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$referralCount Donors Invited (+${referralCount * 50} pts)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            effectiveCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Copy Code',
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: effectiveCode));
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Copied $effectiveCode!'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Share.share(
                                    '🩸 Join me on RedCellNet — Bangladesh\'s Emergency Blood Donor Network! Enter my referral code $effectiveCode when signing up (or in Profile -> Referral) to earn +25 bonus Impact Points!',
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                                icon:
                                    const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Share'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Redeem a Friend's Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mutedOf(ctx),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderOf(ctx)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Have a Friend\'s Referral Code?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimaryOf(ctx),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (referredBy != null && referredBy.trim().isNotEmpty)
                            ? '✓ You have already redeemed referral code: $referredBy'
                            : 'Enter a fellow donor\'s referral code below to claim +25 Impact Points for yourself and award +50 Points to them!',
                        style: TextStyle(
                          fontSize: 12,
                          color: (referredBy != null &&
                                  referredBy.trim().isNotEmpty)
                              ? AppColors.vitalEmerald
                              : AppColors.textSecondaryOf(ctx),
                        ),
                      ),
                      if (referredBy == null || referredBy.trim().isEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: codeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. RCN-O+-A1B2',
                                  prefixIcon: Icon(
                                      Icons.confirmation_number_outlined,
                                      size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final input =
                                          codeController.text.trim();
                                      if (input.isEmpty) return;
                                      setSheetState(() {
                                        isSubmitting = true;
                                        statusMsg = null;
                                      });
                                      try {
                                        final res = await service
                                            .applyReferralCode(input);
                                        final ok = res['success'] == true;
                                        setSheetState(() {
                                          isSubmitting = false;
                                          isSuccess = ok;
                                          statusMsg =
                                              (res['message'] ?? '').toString();
                                        });
                                        if (ok) {
                                          codeController.clear();
                                        }
                                      } catch (e) {
                                        setSheetState(() {
                                          isSubmitting = false;
                                          isSuccess = false;
                                          statusMsg = e
                                              .toString()
                                              .replaceAll('Exception: ', '');
                                        });
                                      }
                                    },
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Redeem +25'),
                            ),
                          ],
                        ),
                      ],
                      if (statusMsg != null && statusMsg!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          statusMsg!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSuccess
                                ? AppColors.vitalEmerald
                                : AppColors.critical,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Shows the Blood Camp Calendar & 1-Tap .ics / Google Calendar Export Sheet.
Future<void> showBloodCampCalendarSheet(BuildContext context) async {
  final settings = AppSettingsService();
  List<Map<String, dynamic>> camps = List<Map<String, dynamic>>.from(
    settings.getUpcomingBloodCamps(),
  );
  try {
    final rows = await SupabaseConfig.client
        .from('blood_camps')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    final liveCamps = List<Map<String, dynamic>>.from(rows);
    if (liveCamps.isNotEmpty) {
      camps = [...liveCamps, ...camps];
    }
  } catch (_) {}

  if (!context.mounted) return;
  String selectedCity = 'All';
  String searchQuery = '';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final cities = <String>{
          'All',
          'Dhaka',
          'Chattogram',
          'Sylhet',
          'Rajshahi',
          'Khulna',
        };
        for (final c in camps) {
          final cityStr = (c['city'] ?? '').toString().trim();
          if (cityStr.isNotEmpty) cities.add(cityStr);
        }

        final filteredCamps = camps.where((c) {
          final title = (c['title'] ?? '').toString().toLowerCase();
          final org = (c['organizer'] ?? '').toString().toLowerCase();
          final loc =
              '${c['location'] ?? ''} ${c['venue'] ?? ''} ${c['city'] ?? ''}'
                  .toLowerCase();
          if (selectedCity != 'All' &&
              !loc.contains(selectedCity.toLowerCase())) {
            return false;
          }
          if (searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            return title.contains(q) || org.contains(q) || loc.contains(q);
          }
          return true;
        }).toList();

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.86,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(ctx),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.event_available_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Blood Drives & Camps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryOf(ctx),
                          ),
                        ),
                        Text(
                          'Filter by city, call organizers, or sync to calendar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredCamps.length} Drives',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setSheetState(() => searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search blood camp, university, or organizer...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: cities.map((city) {
                    final active = selectedCity == city;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(city == 'All' ? 'All Cities' : city),
                        selected: active,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: active
                              ? Colors.white
                              : AppColors.textPrimaryOf(ctx),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setSheetState(() => selectedCity = city),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredCamps.isEmpty
                    ? Center(
                        child: Text(
                          'No blood camps match "$selectedCity" right now.',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(ctx),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredCamps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final camp = filteredCamps[i];
                          final title = (camp['title'] ?? 'Blood Donation Camp')
                              .toString();
                          final organizer =
                              (camp['organizer'] ?? 'RedCellNet').toString();
                          final rawVenue =
                              (camp['venue'] ?? '').toString().trim();
                          final rawLocation =
                              (camp['location'] ?? '').toString().trim();
                          final city = (camp['city'] ?? '').toString().trim();
                          final location = rawLocation.isNotEmpty
                              ? rawLocation
                              : [
                                  if (rawVenue.isNotEmpty) rawVenue,
                                  if (city.isNotEmpty) city
                                ].join(', ');
                          final rawDesc =
                              (camp['description'] ?? '').toString().trim();
                          final phone =
                              (camp['contact_phone'] ?? '').toString().trim();
                          final desc = rawDesc.isNotEmpty
                              ? rawDesc
                              : 'Voluntary community blood drive organized by $organizer.';
                          final startStr =
                              (camp['start_time'] ?? camp['event_date'] ?? '')
                                  .toString();
                          final start = DateTime.tryParse(startStr) ??
                              DateTime.now().add(const Duration(days: 3));
                          final end = DateTime.tryParse(
                                  (camp['end_time'] ?? '').toString()) ??
                              start.add(const Duration(hours: 5));

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.mutedOf(ctx),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.borderOf(ctx)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 12,
                                              color: AppColors.primary),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${start.day}/${start.month}/${start.year}',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.vitalEmerald
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Walk-Ins Welcome',
                                        style: TextStyle(
                                          color: AppColors.vitalEmerald,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Share Blood Camp',
                                      icon: const Icon(Icons.share_rounded,
                                          size: 17),
                                      onPressed: () {
                                        Share.share(
                                          '🩸 Upcoming Blood Donation Drive: $title\n📍 Location: $location\n📅 Date: ${start.day}/${start.month}/${start.year}\nOrganized by $organizer via RedCellNet',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimaryOf(ctx),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Organizer: $organizer',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondaryOf(ctx),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryOf(ctx),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (phone.isNotEmpty) ...[
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final uri =
                                              Uri.parse('tel:$phone');
                                          await launchUrl(uri);
                                        },
                                        icon: const Icon(Icons.call_rounded,
                                            size: 15),
                                        label: const Text('Call',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final icsContent =
                                              settings.generateBloodCampIcs(
                                            title: title,
                                            location: location,
                                            description: desc,
                                            startTime: start,
                                            endTime: end,
                                          );
                                          final xFile = XFile.fromData(
                                            Uint8List.fromList(
                                                utf8.encode(icsContent)),
                                            mimeType: 'text/calendar',
                                            name:
                                                '${camp['id'] ?? "camp"}.ics',
                                          );
                                          await Share.shareXFiles(
                                            [xFile],
                                            text: '📅 $title at $location',
                                          );
                                        },
                                        icon: const Icon(
                                            Icons.download_rounded,
                                            size: 15),
                                        label: const Text('.ics',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final gcalUrl = settings
                                              .buildGoogleCalendarUrl(
                                            title: title,
                                            location: location,
                                            description: desc,
                                            startTime: start,
                                            endTime: end,
                                          );
                                          final uri = Uri.parse(gcalUrl);
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        },
                                        icon: const Icon(
                                            Icons.calendar_month_rounded,
                                            size: 15),
                                        label: const Text('Google Cal',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Shows the Personal Donation & Hemoglobin Health Journal Sheet with PDF Export.
/// Designed with a responsive 2-tab layout and a sticky bottom "Save Wellness Entry"
/// button that never gets pushed off-screen.
Future<void> showHealthJournalSheet(
  BuildContext context, {
  String? donorName,
  String? bloodType,
}) async {
  final settings = AppSettingsService();
  final hbController = TextEditingController();
  final bpController = TextEditingController();
  final weightController = TextEditingController();
  final notesController = TextEditingController();
  bool ironSupplement = false;
  int feelingRating = 5;
  int activeTab = 0; // 0 = Log Vitals, 1 = History & PDF

  const moodLabels = <int, String>{
    1: 'Exhausted',
    2: 'Low Energy',
    3: 'Normal',
    4: 'Strong',
    5: 'Peak Vitality',
  };

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final mediaQuery = MediaQuery.of(ctx);
        final keyboardInset = mediaQuery.viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: settings.getHealthJournalEntries(),
              builder: (ctx, snap) {
                final entries = snap.data ?? const [];
                double? latestHb;
                String latestBp = '-';
                String latestWeight = '-';
                for (final e in entries) {
                  latestHb ??= double.tryParse(
                      (e['hemoglobin_g_dl'] ?? '').toString().trim());
                  if (latestBp == '-' &&
                      (e['blood_pressure'] ?? '').toString().trim().isNotEmpty) {
                    latestBp = e['blood_pressure'].toString().trim();
                  }
                  if (latestWeight == '-' &&
                      (e['weight_kg'] ?? '').toString().trim().isNotEmpty) {
                    latestWeight = '${e['weight_kg']} kg';
                  }
                }
                final double? typedHb =
                    double.tryParse(hbController.text.trim());
                final double? displayHb = typedHb ?? latestHb;
                final bool hbEligible = displayHb == null || displayHb >= 12.5;
                final double hbProgress = displayHb == null
                    ? 0.75
                    : ((displayHb - 8.0) / 10.0).clamp(0.05, 1.0);

                Future<void> exportPdfReport() async {
                  if (entries.isEmpty) return;
                  final doc = pw.Document();
                  doc.addPage(
                    pw.Page(
                      pageFormat: PdfPageFormat.a4,
                      build: (pw.Context pCtx) => pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RedCellNet — Personal Donor Health & Hemoglobin Log',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                              'Donor: ${donorName ?? "Community Donor"} | Blood Group: ${bloodType ?? "Unset"}'),
                          pw.Divider(),
                          ...entries.map(
                            (e) => pw.Padding(
                              padding:
                                  const pw.EdgeInsets.symmetric(vertical: 6),
                              child: pw.Text(
                                '• Date: ${(e['recorded_at'] ?? '').toString().split('T').first} | Hb: ${e['hemoglobin_g_dl'] ?? '-'} g/dL | BP: ${e['blood_pressure'] ?? '-'} | Weight: ${e['weight_kg'] ?? '-'} kg | Vitality: ${e['feeling_rating'] ?? 5}/5 | Notes: ${e['notes'] ?? ''}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  await Printing.layoutPdf(onLayout: (_) async => doc.save());
                }

                Future<void> saveEntry() async {
                  if (hbController.text.trim().isEmpty &&
                      bpController.text.trim().isEmpty &&
                      weightController.text.trim().isEmpty &&
                      notesController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please enter at least one vital sign or note before saving.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  FocusScope.of(ctx).unfocus();
                  await settings.addHealthJournalEntry({
                    'hemoglobin_g_dl': hbController.text.trim(),
                    'blood_pressure': bpController.text.trim(),
                    'weight_kg': weightController.text.trim(),
                    'feeling_rating': feelingRating,
                    'iron_supplement': ironSupplement,
                    'notes': notesController.text.trim(),
                  });
                  hbController.clear();
                  bpController.clear();
                  weightController.clear();
                  notesController.clear();
                  setSheetState(() {
                    activeTab = 1;
                  });
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Wellness & Hemoglobin entry saved to log!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Top Drag Handle & Header ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.borderOf(ctx),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.vitalGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                    Icons.monitor_heart_rounded,
                                    color: Colors.white,
                                    size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hemoglobin & Wellness Journal',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimaryOf(ctx),
                                      ),
                                    ),
                                    Text(
                                      'WHO Hb gauge (>= 12.5 g/dL), BP, weight & iron log',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondaryOf(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (entries.isNotEmpty)
                                IconButton(
                                  tooltip: 'Export PDF Health Log',
                                  onPressed: exportPdfReport,
                                  icon: const Icon(Icons.picture_as_pdf_rounded,
                                      color: AppColors.primary),
                                ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // --- Segmented 2-Tab Switcher ---
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.mutedOf(ctx),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderOf(ctx)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () =>
                                        setSheetState(() => activeTab = 0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 9),
                                      decoration: BoxDecoration(
                                        color: activeTab == 0
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.edit_note_rounded,
                                            size: 16,
                                            color: activeTab == 0
                                                ? Colors.white
                                                : AppColors.textSecondaryOf(
                                                    ctx),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Log Vitals',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: activeTab == 0
                                                  ? Colors.white
                                                  : AppColors.textSecondaryOf(
                                                      ctx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () =>
                                        setSheetState(() => activeTab = 1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 9),
                                      decoration: BoxDecoration(
                                        color: activeTab == 1
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.history_edu_rounded,
                                            size: 16,
                                            color: activeTab == 1
                                                ? Colors.white
                                                : AppColors.textSecondaryOf(
                                                    ctx),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'History (${entries.length})',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: activeTab == 1
                                                  ? Colors.white
                                                  : AppColors.textSecondaryOf(
                                                      ctx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Scrollable Middle Content ---
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: activeTab == 0
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Compact WHO Hemoglobin Readiness Banner
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          (hbEligible
                                                  ? AppColors.vitalEmerald
                                                  : AppColors.warning)
                                              .withValues(alpha: 0.14),
                                          AppColors.mutedOf(ctx),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: (hbEligible
                                                ? AppColors.vitalEmerald
                                                : AppColors.warning)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayHb != null
                                                    ? 'Hemoglobin: ${displayHb.toStringAsFixed(1)} g/dL'
                                                    : 'WHO Target: >= 12.5 g/dL',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13.5,
                                                  color:
                                                      AppColors.textPrimaryOf(
                                                          ctx),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (hbEligible
                                                        ? AppColors.vitalEmerald
                                                        : AppColors.warning)
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                displayHb == null
                                                    ? 'Enter Vitals Below'
                                                    : (hbEligible
                                                        ? 'WHO Optimal'
                                                        : 'Low Hb (<12.5)'),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: hbEligible
                                                      ? AppColors.vitalEmerald
                                                      : AppColors.warning,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: hbProgress,
                                            minHeight: 7,
                                            backgroundColor:
                                                AppColors.borderOf(ctx)
                                                    .withValues(alpha: 0.5),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              hbEligible
                                                  ? AppColors.vitalEmerald
                                                  : AppColors.warning,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              'Last BP: $latestBp',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColors.textSecondaryOf(
                                                        ctx),
                                              ),
                                            ),
                                            Text(
                                              'Last Weight: $latestWeight (Min 50 kg)',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColors.textSecondaryOf(
                                                        ctx),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // --- Spacious Clinical Vitals Inputs ---
                                  Text(
                                    '1. CLINICAL VITALS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                      color: AppColors.textMutedOf(ctx),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: hbController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => setSheetState(() {}),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimaryOf(ctx),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Hemoglobin Level (g/dL)',
                                      hintText: 'e.g. 14.2 (WHO min: 12.5)',
                                      prefixIcon: const Icon(
                                          Icons.water_drop_rounded,
                                          color: AppColors.primary,
                                          size: 20),
                                      filled: true,
                                      fillColor: AppColors.mutedOf(ctx),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (ctx, box) {
                                      final isNarrow = box.maxWidth < 310;
                                      final bpField = TextField(
                                        controller: bpController,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimaryOf(ctx),
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Blood Pressure (mmHg)',
                                          hintText: 'e.g. 120/80',
                                          prefixIcon: const Icon(
                                              Icons.favorite_border_rounded,
                                              color: AppColors.secondary,
                                              size: 20),
                                          filled: true,
                                          fillColor: AppColors.mutedOf(ctx),
                                        ),
                                      );
                                      final wtField = TextField(
                                        controller: weightController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimaryOf(ctx),
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Body Weight (kg)',
                                          hintText: 'e.g. 68',
                                          prefixIcon: const Icon(
                                              Icons.monitor_weight_outlined,
                                              color: AppColors.accent,
                                              size: 20),
                                          filled: true,
                                          fillColor: AppColors.mutedOf(ctx),
                                        ),
                                      );
                                      if (isNarrow) {
                                        return Column(
                                          children: [
                                            bpField,
                                            const SizedBox(height: 10),
                                            wtField,
                                          ],
                                        );
                                      }
                                      return Row(
                                        children: [
                                          Expanded(child: bpField),
                                          const SizedBox(width: 10),
                                          Expanded(child: wtField),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // --- Vitality & Recovery Rating ---
                                  Text(
                                    '2. HOW ARE YOU FEELING TODAY?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                      color: AppColors.textMutedOf(ctx),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: moodLabels.entries.map((entry) {
                                      final selected =
                                          feelingRating == entry.key;
                                      return ChoiceChip(
                                        label: Text(
                                            '${entry.key} • ${entry.value}'),
                                        selected: selected,
                                        selectedColor: AppColors.vitalEmerald,
                                        backgroundColor: AppColors.mutedOf(ctx),
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.textPrimaryOf(ctx),
                                        ),
                                        onSelected: (_) => setSheetState(
                                            () => feelingRating = entry.key),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 14),

                                  // --- Iron Supplement Toggle Card ---
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.mutedOf(ctx),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.borderOf(ctx)),
                                    ),
                                    child: SwitchListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 2),
                                      secondary: const Icon(
                                        Icons.medication_liquid_rounded,
                                        color: AppColors.vitalEmerald,
                                      ),
                                      title: Text(
                                        'Taking Iron / Folic Acid Supplement',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: AppColors.textPrimaryOf(ctx),
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Helps replenish red blood cells after donation',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondaryOf(ctx),
                                        ),
                                      ),
                                      value: ironSupplement,
                                      activeThumbColor: AppColors.vitalEmerald,
                                      onChanged: (v) => setSheetState(
                                          () => ironSupplement = v),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // --- Notes Field ---
                                  TextField(
                                    controller: notesController,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.textPrimaryOf(ctx),
                                    ),
                                    decoration: InputDecoration(
                                      labelText:
                                          'Post-Donation / Wellness Notes (Optional)',
                                      hintText:
                                          'Hydrated well, iron-rich meal, feeling energetic...',
                                      prefixIcon: const Icon(
                                          Icons.notes_rounded,
                                          size: 20),
                                      filled: true,
                                      fillColor: AppColors.mutedOf(ctx),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (entries.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.mutedOf(ctx),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: AppColors.borderOf(ctx)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.monitor_heart_outlined,
                                            size: 36,
                                            color: AppColors.vitalEmerald,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'No Vitals Logged Yet',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color:
                                                  AppColors.textPrimaryOf(ctx),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'WHO recommends Hemoglobin >= 12.5 g/dL (women) and >= 13.0 g/dL (men) before whole blood donation. Switch to "Log Vitals" to record your first check.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.4,
                                              color: AppColors.textSecondaryOf(
                                                  ctx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ...entries.map((e) {
                                      final id = e['id']?.toString() ?? '';
                                      final dateStr = (e['recorded_at'] ?? '')
                                          .toString()
                                          .split('T')
                                          .first;
                                      final hb = (e['hemoglobin_g_dl'] ?? '')
                                          .toString();
                                      final bp = (e['blood_pressure'] ?? '')
                                          .toString();
                                      final wt =
                                          (e['weight_kg'] ?? '').toString();
                                      final notes =
                                          (e['notes'] ?? '').toString();
                                      final iron =
                                          e['iron_supplement'] == true;
                                      final mood = e['feeling_rating'] ?? 5;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.mutedOf(ctx),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppColors.borderOf(ctx)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(9),
                                              decoration: BoxDecoration(
                                                color: AppColors.vitalEmerald
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.favorite_rounded,
                                                color: AppColors.vitalEmerald,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondaryOf(ctx),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    children: [
                                                      if (hb.isNotEmpty)
                                                        Text(
                                                          'Hb: $hb g/dL',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 13,
                                                            color: AppColors
                                                                .textPrimaryOf(
                                                                    ctx),
                                                          ),
                                                        ),
                                                      if (bp.isNotEmpty)
                                                        Text(
                                                          'BP: $bp',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12.5,
                                                            color: AppColors
                                                                .textPrimaryOf(
                                                                    ctx),
                                                          ),
                                                        ),
                                                      if (wt.isNotEmpty)
                                                        Text(
                                                          'Weight: $wt kg',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12.5,
                                                            color: AppColors
                                                                .textPrimaryOf(
                                                                    ctx),
                                                          ),
                                                        ),
                                                      Text(
                                                        'Vitality: $mood/5',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 12.5,
                                                          color: AppColors
                                                              .vitalEmerald,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (notes.isNotEmpty ||
                                                      iron) ...[
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      '${iron ? "💊 Iron Supplement • " : ""}$notes',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondaryOf(
                                                                ctx),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete entry',
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AppColors.critical,
                                                  size: 19),
                                              onPressed: () async {
                                                await settings
                                                    .deleteHealthJournalEntry(
                                                        id);
                                                setSheetState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                      ),
                    ),

                    // --- Sticky Bottom Action Footer (Always Visible on Screen) ---
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(ctx),
                        border: Border(
                          top: BorderSide(color: AppColors.borderOf(ctx)),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: activeTab == 0
                              ? ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.vitalEmerald,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: saveEntry,
                                  icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 20),
                                  label: const Text(
                                    'Save Wellness Entry',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: entries.isNotEmpty
                                      ? exportPdfReport
                                      : () => setSheetState(() => activeTab = 0),
                                  icon: Icon(
                                    entries.isNotEmpty
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.add_rounded,
                                    size: 19,
                                  ),
                                  label: Text(
                                    entries.isNotEmpty
                                        ? 'Export PDF Clinical Report'
                                        : 'Log First Vital Entry',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

/// Guest Emergency Preview Sheet for Action-First Onboarding / Login (60-Second Value Rule).
Future<void> showGuestEmergencyPreviewSheet(BuildContext context) async {
  final settings = AppSettingsService();
  final cached = await settings.loadCachedEmergencyRequests();
  final previewList = cached.isNotEmpty
      ? cached
      : <Map<String, dynamic>>[
          {
            'blood_type': 'O-',
            'blood_component': 'Whole Blood',
            'urgency': 'Critical',
            'hospital_name': 'Dhaka Medical College Hospital (DMCH)',
            'city': 'Dhaka',
            'units': 2,
            'units_fulfilled': 0,
            'patient_name': 'Emergency Trauma Case',
          },
          {
            'blood_type': 'A+',
            'blood_component': 'Platelets',
            'urgency': 'High',
            'hospital_name': 'Square Hospital Limited',
            'city': 'Dhaka',
            'units': 3,
            'units_fulfilled': 1,
            'patient_name': 'Dengue Recovery Ward',
          },
          {
            'blood_type': 'B+',
            'blood_component': 'Red Cells',
            'urgency': 'High',
            'hospital_name': 'Chittagong Medical College Hospital',
            'city': 'Chattogram',
            'units': 2,
            'units_fulfilled': 1,
            'patient_name': 'Thalassemia Care Unit',
          },
        ];

  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.80,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(ctx),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderOf(ctx),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const RedCellNetLogo(size: 38, showPulseGlow: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Emergency Radar (Guest Preview)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimaryOf(ctx),
                      ),
                    ),
                    Text(
                      'Sign in to offer blood, view hospital contacts & unlock your Digital Pass',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryOf(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: previewList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final r = previewList[i];
                final bg = (r['blood_type'] ?? 'O+').toString();
                final comp = (r['blood_component'] ?? 'Whole Blood').toString();
                final hosp = (r['hospital_name'] ?? 'Hospital').toString();
                final city = (r['city'] ?? 'Dhaka').toString();
                final urgency = (r['urgency'] ?? 'High').toString();

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mutedOf(ctx),
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(
                        color: AppColors.urgencyColor(urgency),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      BloodGroupBadge(bloodType: bg, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UrgencyChip(urgency: urgency),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    comp,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondaryOf(ctx),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hosp,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(ctx),
                              ),
                            ),
                            Text(
                              city,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue to Sign In / Register'),
            ),
          ),
        ],
      ),
    ),
  );
}

