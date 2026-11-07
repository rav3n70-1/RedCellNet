// lib/features/blood_requests/presentation/pages/request_details_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Top-level helper preserved for callers and tests, backed by component-aware [BloodCompatibility].
bool isBloodTypeCompatible(
  String? donorType,
  String? recipientType, {
  String componentType = 'Whole Blood',
}) {
  return BloodCompatibility.isCompatible(
    donorBloodType: donorType,
    recipientBloodType: recipientType,
    componentType: componentType,
  );
}

class RequestDetailsPage extends StatefulWidget {
  final String requestId;
  const RequestDetailsPage({super.key, required this.requestId});

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  final RequestService _requestService = RequestService();
  final UserProfileService _profileService = UserProfileService();

  late Stream<AppDocSnapshot> _requestStream;
  String? get currentUserId => SupabaseAuthService().currentUserId;

  bool _isProcessingAction = false;
  Map<String, dynamic>? _currentUserProfileData;

  @override
  void initState() {
    super.initState();
    _requestStream = _requestService.getRequestStream(widget.requestId);
    _checkCurrentUserProfile();
  }

  Future<void> _checkCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid != null && uid.isNotEmpty) {
      try {
        final doc = await _profileService.getUserProfile(uid);
        if (mounted && doc.exists) {
          setState(() {
            _currentUserProfileData = doc.data();
          });
        }
      } catch (e) {
        debugPrint('Error fetching current user profile: $e');
      }
    }
  }

  bool get _isStaff {
    final role =
        (_currentUserProfileData?['role'] ?? 'user').toString().toLowerCase();
    return role == 'admin' || role == 'moderator';
  }

  String _maskPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Not Provided';
    if (trimmed.length <= 5) return '•••••';
    final prefix = trimmed.substring(0, 4);
    final suffix = trimmed.substring(trimmed.length - 2);
    return '$prefix••••••$suffix';
  }

  String _formatTimestamp(Timestamp? timestamp, {bool detailed = false}) {
    if (timestamp == null) return 'Recently';
    final DateTime date = timestamp.toDate().toLocal();
    if (detailed) {
      return DateFormat.yMMMd().add_jm().format(date);
    }
    final Duration difference = DateTime.now().difference(date);
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  String _formatIsoTime(dynamic raw) {
    final ts = AppTimestamp.tryFromValue(raw);
    if (ts == null) return '';
    return _formatTimestamp(ts, detailed: true);
  }

  String _generateSOSText(Map<String, dynamic> data, {bool includePhone = false}) {
    final blood = data['requiredBloodType'] ?? '';
    final units = data['requiredUnits'] ?? data['unitsNeeded'] ?? 1;
    final remaining = data['remainingUnits'] ?? units;
    final component = data['componentType'] ?? 'Whole Blood';
    final hospital = data['hospitalName'] ?? '';
    final address = data['hospitalAddress'] ?? '';
    final city = data['city'] ?? '';
    final rawPhone = (data['contactPhone'] ?? data['contactNumber'] ?? '').toString();
    final urgency = data['urgencyLevel'] ?? 'Urgent';
    final isVerifiedCase = data['isVerifiedHospitalCase'] == true;

    return 'URGENT BLOOD REQUEST ($urgency)\n'
        'Patient needs $remaining of $units unit(s) of $blood ($component).\n'
        '• Hospital: $hospital${city.toString().isNotEmpty ? " ($city)" : ""}\n'
        '• Address: $address\n'
        '${includePhone && rawPhone.isNotEmpty ? "• Attendant Phone: $rawPhone\n" : "• Coordination: Respond via RedCellNet to unlock direct attendant contact\n"}'
        '${isVerifiedCase ? "• Verified Hospital Case (RedCellNet Staff)\n" : ""}'
        'Note: Hospital cross-matching required prior to transfusion.';
  }

  Future<void> _shareRequest(Map<String, dynamic> data, {bool includePhone = false}) async {
    HapticFeedback.lightImpact();
    final text = _generateSOSText(data, includePhone: includePhone);
    try {
      await Share.share(text, subject: 'Emergency Blood Request');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency broadcast message copied to clipboard.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _copySOSText(Map<String, dynamic> data, {bool includePhone = false}) async {
    HapticFeedback.lightImpact();
    final text = _generateSOSText(data, includePhone: includePhone);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert copied to clipboard.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _shareToWhatsApp(Map<String, dynamic> data, {bool includePhone = false}) async {
    HapticFeedback.mediumImpact();
    final text = _generateSOSText(data, includePhone: includePhone);
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await _shareRequest(data, includePhone: includePhone);
  }

  Future<void> _callPhoneNumber(String? phoneNumber) async {
    final cleaned = (phoneNumber ?? '').trim();
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number provided.')),
      );
      return;
    }
    final telUri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
        return;
      }
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: cleaned));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number copied to clipboard: $cleaned'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _smsPhoneNumber(String? phoneNumber, {String? body}) async {
    final cleaned = (phoneNumber ?? '').trim();
    if (cleaned.isEmpty) return;
    final uri = Uri(
      scheme: 'sms',
      path: cleaned,
      queryParameters: body != null && body.isNotEmpty ? {'body': body} : null,
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    await _callPhoneNumber(cleaned);
  }

  Future<void> _openHospitalDirections(
    GeoPoint? coords,
    String hospitalName,
    String address,
  ) async {
    final String query = coords != null
        ? '${coords.latitude},${coords.longitude}'
        : '$hospitalName, $address';
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: '$hospitalName — $address'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hospital address copied to clipboard.'),
          ),
        );
      }
    }
  }

  Future<void> _showOfferBloodDialog(Map<String, dynamic> requestData) async {
    final String? uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to offer a blood donation.'),
          backgroundColor: AppColors.high,
        ),
      );
      return;
    }

    if (requestData['requesterUserId'] == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot submit a donor offer on your own request.'),
        ),
      );
      return;
    }

    try {
      final userDoc = await _profileService.getUserProfile(uid);
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception(
          'Please complete your profile with your blood group first.',
        );
      }
      _currentUserProfileData = userDoc.data()!;
      final String? donorBloodType = _currentUserProfileData!['bloodType']?.toString();
      final String? requiredBloodType =
          requestData['requiredBloodType']?.toString();
      final String componentType =
          requestData['componentType']?.toString() ?? 'Whole Blood';
      final String donorVerification =
          (_currentUserProfileData!['verificationStatus'] ?? 'unverified')
              .toString();
      final bool isVerified = donorVerification.toLowerCase() == 'verified';

      if (donorBloodType == null || donorBloodType.trim().isEmpty) {
        throw Exception(
          'Please set your blood group in Edit Profile before offering to donate.',
        );
      }

      final eligibility = BloodCompatibility.checkEligibility(
        lastDonationDate: AppTimestamp.tryFromValue(
          _currentUserProfileData!['lastDonationDate'] ??
              _currentUserProfileData!['last_donation_date'],
        )?.toDate(),
        nextEligibleDate: AppTimestamp.tryFromValue(
          _currentUserProfileData!['nextEligibleDate'] ??
              _currentUserProfileData!['next_eligible_date'],
        )?.toDate(),
        cooldownDays: (_currentUserProfileData!['cooldownDays'] is num)
            ? (_currentUserProfileData!['cooldownDays'] as num).toInt()
            : 90,
      );
      if (!eligibility.isEligible) {
        throw Exception(
          '${eligibility.statusMessage}. Whole-blood recovery interval must complete before donating again.',
        );
      }

      if (!BloodCompatibility.isCompatible(
        donorBloodType: donorBloodType,
        recipientBloodType: requiredBloodType,
        componentType: componentType,
      )) {
        throw Exception(
          'Incompatible for $componentType: $donorBloodType donor cannot donate to a $requiredBloodType recipient.',
        );
      }

      final int remainingUnits = (requestData['remainingUnits'] ??
          (requestData['requiredUnits'] ?? requestData['unitsNeeded'] ?? 1)) as int;
      if (remainingUnits <= 0) {
        throw Exception('This request is already covered.');
      }

      int chosenUnits = 1;
      final noteCtrl = TextEditingController();

      if (!mounted) return;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = AppColors.isDark(ctx);
          return StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
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
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Offer Blood Donation',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
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
                        'Volunteering $donorBloodType ($componentType) at ${requestData['hospitalName'] ?? 'hospital'}.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryOf(ctx),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Units You Can Donate:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimaryOf(ctx),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMutedOf(ctx),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderOf(ctx)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: AppColors.textSecondaryOf(ctx),
                              ),
                              onPressed: chosenUnits > 1
                                  ? () => setDialogState(() => chosenUnits--)
                                  : null,
                            ),
                            Column(
                              children: [
                                Text(
                                  '$chosenUnits Unit${chosenUnits > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  'Remaining needed: $remainingUnits',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryOf(ctx),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.primary,
                              ),
                              onPressed: chosenUnits < remainingUnits
                                  ? () => setDialogState(() => chosenUnits++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        style:
                            TextStyle(color: AppColors.textPrimaryOf(ctx), fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Arrival ETA / Note (Optional)',
                          hintText: 'e.g. Can reach blood bank in 30 mins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        BloodCompatibility.medicalCrossMatchDisclaimer,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Submit Offer ($chosenUnits)',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      final noteText = noteCtrl.text.trim();
      noteCtrl.dispose();
      if (proceed != true) return;

      setState(() => _isProcessingAction = true);

      await _requestService.submitOffer(
        requestId: widget.requestId,
        donorId: uid,
        donorName:
            (_currentUserProfileData!['name'] ?? 'Volunteer Donor').toString(),
        donorBloodType: donorBloodType,
        offeredUnits: chosenUnits,
        donorIsVerified: isVerified,
        note: noteText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Offer for $chosenUnits unit(s) submitted! The requester has been notified.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _withdrawOffer(String offerId, {bool wasAccepted = false}) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          title: Text(
            'Withdraw Donation Offer?',
            style: TextStyle(
              color: AppColors.textPrimaryOf(ctx),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            wasAccepted
                ? 'Your offer was already accepted. Withdrawing will reopen your unit slot so another donor can help immediately.'
                : 'Are you sure you want to withdraw your pending donation offer?',
            style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Keep Offer',
                style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Withdraw Offer'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _requestService.withdrawOffer(widget.requestId, offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer withdrawn and remaining units updated.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _acceptOfferAction(
    String offerId,
    String donorId,
    String donorName,
    int offeredUnits,
    int remainingUnits,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          title: Text(
            'Accept Donor Offer',
            style: TextStyle(
              color: AppColors.textPrimaryOf(ctx),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Accept offer from $donorName for $offeredUnits unit(s)?\n\n'
            'Direct phone coordination will be unlocked between you and $donorName ($remainingUnits unit(s) currently needed).',
            style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Accept Offer'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _requestService.acceptOffer(
        widget.requestId,
        offerId,
        donorId,
        offeredUnits: offeredUnits,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted $donorName ($offeredUnits unit(s)).'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _rejectOfferAction(String offerId) async {
    setState(() => _isProcessingAction = true);
    try {
      await _requestService.rejectOffer(widget.requestId, offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer declined.'),
            backgroundColor: AppColors.high,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _completeDonationAction(
    String offerId,
    String donorName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          title: Text(
            'Verify Hospital Donation Completed?',
            style: TextStyle(
              color: AppColors.textPrimaryOf(ctx),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Confirm that $donorName completed the donation at the hospital blood bank?\n\n'
            'This issues an official verified RedCellNet Donation Certificate and activates their 90-day medical recovery cooldown.',
            style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Not Yet',
                style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Completed'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final res =
          await _requestService.completeDonation(widget.requestId, offerId);
      final certId = res['certificate_id']?.toString() ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              certId.isNotEmpty
                  ? 'Donation verified! Certificate $certId issued to $donorName.'
                  : 'Donation verified and recorded for $donorName.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _releaseAcceptedOfferAction(
    String offerId,
    String donorName,
  ) async {
    String selectedReason = 'Donor could not attend hospital';
    final reasons = [
      'Donor could not attend hospital',
      'Deferred during hospital pre-screening',
      'Could not reach donor by phone',
      'Other coordination issue',
    ];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBg(dCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: isDark ? AppColors.borderSideOf(dCtx) : BorderSide.none,
              ),
              title: Text(
                'Release Slot ($donorName)',
                style: TextStyle(
                  color: AppColors.textPrimaryOf(dCtx),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Releasing this slot reopens the unit requirement so other compatible donors can volunteer immediately:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(dCtx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReason,
                    dropdownColor: AppColors.cardBg(dCtx),
                    items: reasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimaryOf(dCtx),
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDState(() => selectedReason = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warningDark,
                  ),
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('Reopen Slot'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _requestService.releaseAcceptedOffer(
        widget.requestId,
        offerId,
        reason: selectedReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot reopened for new compatible donors.'),
            backgroundColor: AppColors.warningDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _cancelRequest() async {
    String selectedReason = 'Patient recovered / Discharged';
    final reasons = [
      'Patient recovered / Discharged',
      'Blood units arranged elsewhere',
      'Cancelled by attending doctor',
      'Created by mistake / Duplicate',
      'Other',
    ];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBg(dCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: isDark ? AppColors.borderSideOf(dCtx) : BorderSide.none,
              ),
              title: Text(
                'Cancel Blood Request',
                style: TextStyle(
                  color: AppColors.textPrimaryOf(dCtx),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please select a reason so active donors are notified promptly:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(dCtx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReason,
                    dropdownColor: AppColors.cardBg(dCtx),
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(dCtx),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: reasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: AppColors.textPrimaryOf(dCtx),
                                  fontSize: 13,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDState(() => selectedReason = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(
                    'Keep Active',
                    style: TextStyle(color: AppColors.textSecondaryOf(dCtx)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.critical,
                  ),
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('Confirm Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _requestService.cancelBloodRequest(
        widget.requestId,
        reason: selectedReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood request cancelled and donors notified.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _deleteRequest() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          title: Text(
            'Delete Blood Request?',
            style: TextStyle(
              color: AppColors.textPrimaryOf(ctx),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete this blood request?',
            style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
              ),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isProcessingAction = true);
      try {
        await _requestService.deleteBloodRequest(widget.requestId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blood request deleted.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete error: $e'),
              backgroundColor: AppColors.critical,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessingAction = false);
      }
    }
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20.0,
            color: iconColor ?? AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 12.0),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
                fontSize: 13.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not Provided',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniOpenStreetMap(GeoPoint coords, String hospitalName) {
    final location = LatLng(coords.latitude, coords.longitude);
    final isDark = AppColors.isDark(context);

    return Container(
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: location,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.red_cell_net',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hospital Pin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBroadcastCard(
    BuildContext context,
    Map<String, dynamic> data, {
    required bool canSeeFullContact,
  }) {
    final isDark = AppColors.isDark(context);
    final blood = data['requiredBloodType'] ?? '';
    final remaining = data['remainingUnits'] ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1216) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SHARE EMERGENCY APPEAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE11D48),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$remaining Unit(s) $blood',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Forward this verified hospital blood need to compatible donors in your community.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white70 : const Color(0xFF881337),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _shareToWhatsApp(
                    data,
                    includePhone: canSeeFullContact,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _shareRequest(
                    data,
                    includePhone: canSeeFullContact,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text(
                    'Share',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white : AppColors.textPrimary,
                    side: BorderSide(color: AppColors.borderOf(context)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _copySOSText(
                    data,
                    includePhone: canSeeFullContact,
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text(
                    'Copy',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedDonorsSection({
    required List<Map<String, dynamic>> acceptedOffers,
    required bool canManageRequest,
  }) {
    if (acceptedOffers.isEmpty) return const SizedBox.shrink();
    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Confirmed Donors',
          subtitle: 'Accepted volunteers coordinating hospital donation',
          icon: Icons.check_circle_outline_rounded,
        ),
        const SizedBox(height: 8),
        ...acceptedOffers.map((offer) {
          final String offerId = offer['id']?.toString() ?? '';
          final String donorId = offer['donorId']?.toString() ?? '';
          final String donorName =
              offer['donorName']?.toString() ?? 'Volunteer Donor';
          final String donorBloodType =
              offer['donorBloodType']?.toString() ?? '';
          final String donorPhone = offer['donorPhone']?.toString() ?? '';
          final bool donorIsVerified = offer['donorIsVerified'] == true;
          final int offeredUnits = (offer['offeredUnits'] ?? 1) as int;
          final bool donationVerified = offer['donationVerified'] == true;
          final String? certificateId = offer['certificateId']?.toString();
          final String note = offer['note']?.toString() ?? '';
          final bool isSelf = donorId.isNotEmpty && donorId == currentUserId;
          final bool canViewDonorPhone =
              canManageRequest || _isStaff || isSelf;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF064E3B).withValues(alpha: 0.32)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BloodGroupBadge(bloodType: donorBloodType, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                donorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              VerificationBadge(
                                status:
                                    donorIsVerified ? 'verified' : 'unverified',
                                compact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            donationVerified
                                ? 'Verified Donation ($offeredUnits unit(s))${certificateId != null ? " • Cert $certificateId" : ""}'
                                : 'Accepted for $offeredUnits unit(s) • En route / Coordinating',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF166534),
                            ),
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Note: $note',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                          if (canViewDonorPhone && donorPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Phone: $donorPhone',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canViewDonorPhone && donorPhone.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.call_rounded,
                          color: AppColors.success,
                        ),
                        tooltip: 'Call Donor',
                        onPressed: () => _callPhoneNumber(donorPhone),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.sms_outlined,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        tooltip: 'SMS Donor',
                        onPressed: () => _smsPhoneNumber(donorPhone),
                      ),
                    ],
                  ],
                ),
                if (canManageRequest && !donationVerified) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.verified_rounded,
                            size: 16,
                          ),
                          label: Text(
                            AppSettingsService().tr('Mark Donation Completed'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: _isProcessingAction
                              ? null
                              : () => _completeDonationAction(
                                    offerId,
                                    donorName,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningDark,
                          side: BorderSide(
                            color: AppColors.warningDark.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: Text(
                          AppSettingsService().tr('Release Slot'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _isProcessingAction
                            ? null
                            : () => _releaseAcceptedOfferAction(
                                  offerId,
                                  donorName,
                                ),
                      ),
                    ],
                  ),
                ],
                if (isSelf && !donationVerified) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isProcessingAction
                          ? null
                          : () => _withdrawOffer(offerId, wasAccepted: true),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 15,
                        color: AppColors.critical,
                      ),
                      label: const Text(
                        'Cannot Attend? Release My Slot',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.critical,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPendingOffersSection({
    required List<Map<String, dynamic>> pendingOffers,
    required int remainingUnits,
    required bool canManageRequest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SectionHeader(
          title: canManageRequest ? 'Pending Donor Offers' : 'Volunteer Responses',
          subtitle: canManageRequest
              ? 'Review and accept compatible offers until all units are covered'
              : 'Community donors volunteering to help this patient',
          icon: Icons.volunteer_activism_rounded,
        ),
        const SizedBox(height: 8),
        if (pendingOffers.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Center(
              child: Text(
                canManageRequest
                    ? 'No pending donor offers right now. Compatible nearby donors have been alerted.'
                    : 'No pending offers yet. Volunteer if you are compatible and eligible!',
                style: TextStyle(
                  color: AppColors.textMutedOf(context),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...pendingOffers.map((offerData) {
            final String offerId = offerData['id']?.toString() ?? '';
            final String donorName =
                offerData['donorName']?.toString() ?? 'Volunteer Donor';
            final String donorBloodType =
                offerData['donorBloodType']?.toString() ?? 'N/A';
            final int offeredUnits = (offerData['offeredUnits'] ?? 1) as int;
            final bool donorIsVerified = offerData['donorIsVerified'] == true;
            final String donorId = offerData['donorId']?.toString() ?? '';
            final String note = offerData['note']?.toString() ?? '';
            final Timestamp? offerTime =
                AppTimestamp.tryFromValue(offerData['offerTimestamp']);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
                boxShadow:
                    AppColors.isDark(context) ? null : AppColors.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodGroupBadge(bloodType: donorBloodType, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  donorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                VerificationBadge(
                                  status: donorIsVerified
                                      ? 'verified'
                                      : 'unverified',
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Offering $offeredUnits Unit${offeredUnits > 1 ? 's' : ''} • ${_formatTimestamp(offerTime)}',
                              style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Note: $note',
                                style: TextStyle(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (donorId.isNotEmpty && donorId != currentUserId)
                        IconButton(
                          icon: Icon(
                            Icons.flag_outlined,
                            size: 18,
                            color: AppColors.textMutedOf(context),
                          ),
                          tooltip: 'Report Donor Profile',
                          onPressed: () => showReportDialog(
                            context,
                            targetType: 'profile',
                            targetId: donorId,
                          ),
                        ),
                    ],
                  ),
                  if (canManageRequest) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isProcessingAction
                              ? null
                              : () => _rejectOfferAction(offerId),
                          child: Text(AppSettingsService().tr('Decline')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text(
                            '${AppSettingsService().tr('Accept')} ($offeredUnits)',
                          ),
                          onPressed: _isProcessingAction
                              ? null
                              : () => _acceptOfferAction(
                                    offerId,
                                    donorId,
                                    donorName,
                                    offeredUnits,
                                    remainingUnits,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTimelineSection(List<dynamic> rawTimeline) {
    if (rawTimeline.isEmpty) return const SizedBox.shrink();
    final items = rawTimeline
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
        .reversed
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    String describeAction(Map<String, dynamic> entry) {
      final action = (entry['action'] ?? '').toString();
      final by = (entry['by'] ?? '').toString();
      final units = entry['units'];
      final note = (entry['note'] ?? '').toString();
      switch (action) {
        case 'created':
          return 'Blood request published';
        case 'request_edited':
          return 'Request details updated by requester';
        case 'offer_submitted':
          return '${by.isNotEmpty ? by : "Volunteer"} offered ${units ?? 1} unit(s)';
        case 'offer_accepted':
          return 'Accepted ${units ?? 1} unit(s)${by.isNotEmpty ? " from $by" : ""}';
        case 'request_fulfilled':
          return 'All required blood units covered!';
        case 'donation_completed':
          return 'Hospital donation verified${by.isNotEmpty ? " ($by)" : ""}';
        case 'offer_withdrawn':
          return 'Donor withdrew offer (${units ?? 1} unit(s))';
        case 'offer_released':
          return 'Slot reopened${note.isNotEmpty ? ": $note" : ""}';
        case 'offer_declined':
          return 'Offer declined';
        case 'request_cancelled':
          return 'Request cancelled${note.isNotEmpty ? ": $note" : ""}';
        case 'request_expired':
          return 'Request reached auto-expiry window';
        default:
          return action.replaceAll('_', ' ');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Case Activity Log',
          subtitle: 'Real-time fulfillment & verification audit trail',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final timeText = _formatIsoTime(item['time']);
              return Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            describeAction(item),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          if (timeText.isNotEmpty)
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedOf(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId;
    final settings = AppSettingsService();

    return StreamBuilder<AppDocSnapshot>(
      stream: _requestStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Request Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Request Details')),
            body: EmptyStateView(
              icon: Icons.error_outline_rounded,
              title: 'Request Not Found',
              message: 'This blood request may have been removed or closed.',
              buttonText: 'Back to Requests',
              onAction: () => Navigator.pop(context),
            ),
          );
        }

        final requestData = snapshot.data!.data();
        final String patientInfo =
            requestData['patientIdentifier']?.toString() ?? 'N/A';
        final String reason = requestData['reason']?.toString() ?? '';
        final String bloodType =
            requestData['requiredBloodType']?.toString() ?? 'N/A';
        final String componentType =
            requestData['componentType']?.toString() ?? 'Whole Blood';

        final int requiredUnits = (requestData['requiredUnits'] ??
            requestData['unitsNeeded'] ??
            1) as int;
        final int acceptedUnits = (requestData['acceptedUnits'] ?? 0) as int;
        final int remainingUnits = (requestData['remainingUnits'] ??
            (requiredUnits - acceptedUnits)) as int;

        final String urgency =
            requestData['urgencyLevel']?.toString() ?? 'Medium';
        final String hospitalName =
            requestData['hospitalName']?.toString() ?? 'Unknown Hospital';
        final String hospitalAddress =
            requestData['hospitalAddress']?.toString() ?? 'No address provided';
        final String city = requestData['city']?.toString() ?? '';
        final String contactPerson =
            requestData['contactPerson']?.toString() ?? 'N/A';
        final String contactNumber =
            (requestData['contactPhone'] ?? requestData['contactNumber'] ?? '')
                .toString();
        final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
        final Timestamp? expiryAt = requestData['expiryAt'] as Timestamp?;
        final String status = requestData['status']?.toString() ?? 'Open';
        final String? cancellationReason =
            requestData['cancellationReason']?.toString();

        final String? requesterUserId =
            requestData['requesterUserId']?.toString();
        final bool isRequester =
            requesterUserId != null && uid != null && requesterUserId == uid;
        final bool canManageRequest = isRequester || _isStaff;

        final List<Map<String, dynamic>> allOffers =
            (requestData['offers'] is List)
                ? (requestData['offers'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
                : <Map<String, dynamic>>[];

        final List<Map<String, dynamic>> acceptedOffers =
            allOffers.where((o) => o['status'] == 'accepted').toList();
        final List<Map<String, dynamic>> pendingOffers =
            allOffers.where((o) => o['status'] == 'pending').toList();

        String? myPendingOfferId;
        int myOfferedUnits = 1;
        bool hasAcceptedOffer = false;
        if (uid != null && uid.isNotEmpty) {
          for (final o in allOffers) {
            if (o['donorId']?.toString() == uid) {
              if (o['status'] == 'pending') {
                myPendingOfferId = o['id']?.toString();
                myOfferedUnits = (o['offeredUnits'] ?? 1) as int;
              } else if (o['status'] == 'accepted') {
                hasAcceptedOffer = true;
              }
            }
          }
        }

        final bool canSeeFullContact =
            isRequester || _isStaff || hasAcceptedOffer;

        GeoPoint? geoPoint;
        final dynamic rawCoords = requestData['hospitalCoords'] ??
            requestData['location_coords'] ??
            requestData['locationCoords'];
        if (rawCoords is GeoPoint) {
          geoPoint = rawCoords;
        } else if (rawCoords is Map) {
          final lat = (rawCoords['latitude'] ?? rawCoords['lat']);
          final lng = (rawCoords['longitude'] ?? rawCoords['lng']);
          if (lat is num && lng is num) {
            geoPoint = GeoPoint(lat.toDouble(), lng.toDouble());
          }
        }

        final String? userBloodType =
            _currentUserProfileData?['bloodType']?.toString();
        final bool isCompatible = userBloodType != null &&
                userBloodType.trim().isNotEmpty
            ? BloodCompatibility.isCompatible(
                donorBloodType: userBloodType,
                recipientBloodType: bloodType,
                componentType: componentType,
              )
            : false;

        final bool isRequestActive =
            (status == 'Open' || status == 'Partially Fulfilled') &&
                remainingUnits > 0;
        final isDark = AppColors.isDark(context);

        return Scaffold(
          backgroundColor: AppColors.scaffoldOf(context),
          appBar: AppBar(
            title: const Text('Request Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (canManageRequest &&
                  status != 'Cancelled' &&
                  status != 'Expired')
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: settings.tr('Edit Request'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateRequestPage(
                        existingRequestId: widget.requestId,
                        existingRequest: requestData,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: settings.tr('Share Request'),
                onPressed: () => _shareRequest(
                  requestData,
                  includePhone: canSeeFullContact,
                ),
              ),
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: AppColors.cardBg(context),
                onSelected: (val) {
                  if (val == 'report_request') {
                    showReportDialog(
                      context,
                      targetType: 'request',
                      targetId: widget.requestId,
                    );
                  } else if (val == 'report_requester' &&
                      requesterUserId != null &&
                      requesterUserId.isNotEmpty) {
                    showReportDialog(
                      context,
                      targetType: 'profile',
                      targetId: requesterUserId,
                    );
                  } else if (val == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateRequestPage(
                          existingRequestId: widget.requestId,
                          existingRequest: requestData,
                        ),
                      ),
                    );
                  } else if (val == 'cancel') {
                    _cancelRequest();
                  } else if (val == 'delete') {
                    _deleteRequest();
                  }
                },
                itemBuilder: (ctx) => [
                  if (!isRequester)
                    const PopupMenuItem(
                      value: 'report_request',
                      child: Row(
                        children: [
                          Icon(
                            Icons.report_problem_outlined,
                            color: AppColors.critical,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Report Request',
                            style: TextStyle(color: AppColors.critical),
                          ),
                        ],
                      ),
                    ),
                  if (!isRequester &&
                      requesterUserId != null &&
                      requesterUserId.isNotEmpty)
                    PopupMenuItem(
                      value: 'report_requester',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_off_outlined,
                            color: AppColors.high,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Report Requester Account',
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (canManageRequest &&
                      status != 'Cancelled' &&
                      status != 'Expired')
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            color: AppColors.secondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            settings.tr('Edit Request'),
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (canManageRequest && isRequestActive)
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cancel_outlined,
                            color: AppColors.high,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            settings.tr('Cancel Request'),
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (canManageRequest)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.critical,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Request',
                            style: TextStyle(color: AppColors.critical),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Cancelled / Expired Status Banners ---
                    if (status == 'Cancelled') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.critical.withValues(alpha: 0.2)
                              : AppColors.criticalLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.critical.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.critical,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Request Cancelled: ${cancellationReason ?? "Closed by requester"}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFFCA5A5)
                                      : AppColors.critical,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (status == 'Expired') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.warning.withValues(alpha: 0.2)
                              : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_off_outlined,
                              color: AppColors.warningDark,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This blood request reached its auto-expiration window and is no longer accepting offers.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFFDE68A)
                                      : AppColors.warningDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    LifeSaverTracker(
                      currentStep: status == 'Fulfilled'
                          ? 3
                          : (acceptedUnits > 0
                              ? 2
                              : (allOffers.isNotEmpty ? 1 : 0)),
                      statusBadge: status,
                    ),
                    const SizedBox(height: 14),

                    // --- Hero Overview Card ---
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderOf(context)),
                        boxShadow: isDark ? null : AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (requestData['isVerifiedHospitalCase'] == true) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B)
                                    .withValues(alpha: isDark ? 0.45 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: Color(0xFF10B981),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'HOSPITAL VERIFIED CASE • Confirmed by Moderation Staff',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFF065F46),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              BloodGroupBadge(
                                bloodType: bloodType,
                                size: 60,
                                showGlow: true,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        UrgencyChip(urgency: urgency),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'Fulfilled'
                                                ? AppColors.success
                                                    .withValues(alpha: 0.16)
                                                : (status ==
                                                        'Partially Fulfilled'
                                                    ? AppColors.warning
                                                        .withValues(alpha: 0.18)
                                                    : AppColors.surfaceMutedOf(
                                                        context)),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: status == 'Fulfilled'
                                                  ? AppColors.success
                                                  : (status ==
                                                          'Partially Fulfilled'
                                                      ? AppColors.warningDark
                                                      : AppColors
                                                          .textSecondaryOf(
                                                              context)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      componentType,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimaryOf(context),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          UnitsProgressIndicator(
                            requiredUnits: requiredUnits,
                            acceptedUnits: acceptedUnits,
                            remainingUnits: remainingUnits,
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            color: AppColors.borderOf(context),
                            height: 1,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.personal_injury_outlined,
                            'Patient / Ward',
                            patientInfo,
                          ),
                          if (reason.isNotEmpty)
                            _buildDetailRow(
                              Icons.medical_services_outlined,
                              'Indication',
                              reason,
                            ),
                          _buildDetailRow(
                            Icons.schedule_rounded,
                            'Requested',
                            _formatTimestamp(createdAt, detailed: true),
                          ),
                          if (expiryAt != null)
                            _buildDetailRow(
                              Icons.hourglass_bottom_rounded,
                              'Expires',
                              _formatTimestamp(expiryAt, detailed: true),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Mandatory Clinical Cross-Match Notice ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.secondary.withValues(alpha: 0.14)
                            : AppColors.secondaryLight.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.medical_information_rounded,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              BloodCompatibility.medicalCrossMatchDisclaimer,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isRequester &&
                        userBloodType != null &&
                        userBloodType.trim().isNotEmpty) ...[
                      CompatibilityBanner(
                        donorBloodType: userBloodType,
                        recipientBloodType: '$bloodType ($componentType)',
                        isCompatible: isCompatible,
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildEmergencyBroadcastCard(
                      context,
                      requestData,
                      canSeeFullContact: canSeeFullContact,
                    ),
                    const SizedBox(height: 16),

                    // --- Hospital Location & OpenStreetMap Card ---
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderOf(context)),
                        boxShadow: isDark ? null : AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_hospital_rounded,
                                    color: AppColors.secondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hospital & Directions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => _openHospitalDirections(
                                  geoPoint,
                                  hospitalName,
                                  hospitalAddress,
                                ),
                                icon: const Icon(
                                  Icons.directions_rounded,
                                  size: 16,
                                ),
                                label: const Text('Directions'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.apartment_rounded,
                            'Hospital',
                            hospitalName,
                          ),
                          _buildDetailRow(
                            Icons.location_on_outlined,
                            'Address',
                            city.isNotEmpty &&
                                    !hospitalAddress
                                        .toLowerCase()
                                        .contains(city.toLowerCase())
                                ? '$hospitalAddress, $city'
                                : hospitalAddress,
                          ),
                          if (geoPoint != null) ...[
                            const SizedBox(height: 14),
                            _buildMiniOpenStreetMap(geoPoint, hospitalName),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Contact Person Card (Privacy Masked Until Offer Acceptance) ---
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderOf(context)),
                        boxShadow: isDark ? null : AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.contact_phone_rounded,
                                color: AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Attendant Contact',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.person_outline_rounded,
                            'Attendant',
                            contactPerson,
                          ),
                          _buildDetailRow(
                            Icons.phone_outlined,
                            'Phone',
                            canSeeFullContact
                                ? (contactNumber.isNotEmpty
                                    ? contactNumber
                                    : 'Not Set')
                                : _maskPhone(contactNumber),
                          ),
                          if (!canSeeFullContact && contactNumber.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.mutedOf(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Privacy protection: Direct phone & SMS unlock automatically once the requester accepts your donation offer.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            AppColors.textSecondaryOf(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (canSeeFullContact &&
                              contactNumber.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _callPhoneNumber(contactNumber),
                                    icon: const Icon(
                                      Icons.call_rounded,
                                      size: 16,
                                    ),
                                    label: Text(settings.tr('Call Contact')),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _smsPhoneNumber(contactNumber),
                                    icon: const Icon(
                                      Icons.sms_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Send SMS'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // --- Confirmed / Accepted Donors Section ---
                    _buildAcceptedDonorsSection(
                      acceptedOffers: acceptedOffers,
                      canManageRequest: canManageRequest,
                    ),

                    // --- Pending Offers Section ---
                    if (isRequestActive || pendingOffers.isNotEmpty)
                      _buildPendingOffersSection(
                        pendingOffers: pendingOffers,
                        remainingUnits: remainingUnits,
                        canManageRequest: canManageRequest,
                      ),

                    // --- Timeline Section ---
                    _buildTimelineSection(
                      (requestData['timeline'] as List?) ?? const [],
                    ),

                    const SizedBox(height: 110),
                  ],
                ),
              ),

              // --- Bottom Action Bar ---
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    border: Border(
                      top: BorderSide(color: AppColors.borderOf(context)),
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        if (canSeeFullContact && contactNumber.isNotEmpty) ...[
                          Expanded(
                            flex: 4,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: Text(settings.tr('Call Contact')),
                              onPressed: () => _callPhoneNumber(contactNumber),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (!isRequester)
                          Expanded(
                            flex: 6,
                            child: hasAcceptedOffer
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.success),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Offer Accepted — Coordinate with Attendant',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.success,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : (myPendingOfferId != null
                                    ? ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          '${settings.tr('Withdraw Offer')} ($myOfferedUnits)',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.critical,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        onPressed: _isProcessingAction
                                            ? null
                                            : () => _withdrawOffer(
                                                  myPendingOfferId!,
                                                ),
                                      )
                                    : (isRequestActive
                                        ? ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.volunteer_activism_rounded,
                                              size: 20,
                                            ),
                                            label: Text(
                                              settings.tr('Offer to Donate'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            onPressed: _isProcessingAction
                                                ? null
                                                : () => _showOfferBloodDialog(
                                                      requestData,
                                                    ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceMutedOf(
                                                context,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                status == 'Fulfilled'
                                                    ? 'Request Fulfilled'
                                                    : 'Request $status',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.textSecondaryOf(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ))),
                          )
                        else if (isRequester && isRequestActive)
                          Expanded(
                            flex: 6,
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.cancel_outlined,
                                size: 18,
                                color: AppColors.critical,
                              ),
                              label: Text(
                                settings.tr('Cancel Request'),
                                style: const TextStyle(
                                  color: AppColors.critical,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color:
                                      AppColors.critical.withValues(alpha: 0.5),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed:
                                  _isProcessingAction ? null : _cancelRequest,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isProcessingAction)
                Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
