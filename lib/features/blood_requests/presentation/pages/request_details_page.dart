// lib/features/blood_requests/presentation/pages/request_details_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';

// --- Blood Type Compatibility Logic ---
bool isBloodTypeCompatible(String? donorType, String? recipientType) {
  if (donorType == null ||
      recipientType == null ||
      !_isValidBloodType(donorType) ||
      !_isValidBloodType(recipientType)) {
    return false;
  }
  if (donorType == 'O-') return true;
  if (recipientType == 'AB+') return true;

  bool donorIsRhNegative = donorType.endsWith('-');
  bool recipientIsRhPositive = recipientType.endsWith('+');
  if (!donorIsRhNegative && !recipientIsRhPositive) {
    return false;
  }

  String donorABO = donorType.replaceAll(RegExp(r'[+-]'), '');
  String recipientABO = recipientType.replaceAll(RegExp(r'[+-]'), '');

  if (donorABO == 'O') return true;
  if (donorABO == 'A' && (recipientABO == 'A' || recipientABO == 'AB')) {
    return true;
  }
  if (donorABO == 'B' && (recipientABO == 'B' || recipientABO == 'AB')) {
    return true;
  }
  if (donorABO == 'AB' && recipientABO == 'AB') return true;

  return false;
}

bool _isValidBloodType(String type) =>
    RegExp(r'^(A|B|AB|O)[+-]$').hasMatch(type);

class RequestDetailsPage extends StatefulWidget {
  final String requestId;
  const RequestDetailsPage({super.key, required this.requestId});

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  final RequestService _requestService = RequestService();
  final UserProfileService _profileService = UserProfileService();

  String? get currentUserId => SupabaseAuthService().currentUserId;

  bool _isProcessingAction = false;
  Map<String, dynamic>? _currentUserProfileData;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserProfile();
  }

  Future<void> _checkCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        final doc = await _profileService.getUserProfile(uid);
        if (mounted && doc.exists) {
          setState(() {
            _currentUserProfileData = doc.data();
          });
        }
      } catch (e) {
        debugPrint("Error fetching current user profile: $e");
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp, {bool detailed = false}) {
    if (timestamp == null) return 'Unknown date';
    final DateTime date = timestamp.toDate().toLocal();
    if (detailed) {
      return DateFormat.yMMMMd().add_jm().format(date);
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

  void _shareRequest(Map<String, dynamic> data) {
    final blood = data['requiredBloodType'] ?? '';
    final units = data['requiredUnits'] ?? data['unitsNeeded'] ?? 1;
    final remaining = data['remainingUnits'] ?? units;
    final component = data['componentType'] ?? 'Whole Blood';
    final hospital = data['hospitalName'] ?? '';
    final address = data['hospitalAddress'] ?? '';
    final contact = data['contactNumber'] ?? '';
    final urgency = data['urgencyLevel'] ?? 'Urgent';

    final text = '🚨 URGENT BLOOD NEEDED 🚨\n'
        '• Blood Group: $blood ($remaining of $units units remaining)\n'
        '• Component: $component\n'
        '• Urgency: $urgency\n'
        '• Hospital: $hospital\n'
        '• Location: $address\n'
        '• Contact: $contact\n\n'
        'Verified via RedCellNet Blood Network.';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request details copied to clipboard!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _contactRequester(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number provided.')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: phoneNumber));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number copied to clipboard: $phoneNumber'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  // --- Submit Offer Dialog with Multi-Unit Choice ---
  Future<void> _showOfferBloodDialog(Map<String, dynamic> requestData) async {
    final String? currentUserId = this.currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to offer help."),
          backgroundColor: AppColors.high,
        ),
      );
      return;
    }

    if (requestData['requesterUserId'] == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot offer help on your own request.")),
      );
      return;
    }

    try {
      final userDoc = await _profileService.getUserProfile(currentUserId);
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception("Your profile data is missing. Please update your profile.");
      }
      _currentUserProfileData = userDoc.data()!;
      final String? donorBloodType = _currentUserProfileData!['bloodType'];
      final bool isDonorAvailable = _currentUserProfileData!['isAvailableToDonate'] ?? false;
      final String? requiredBloodType = requestData['requiredBloodType'];
      final String donorVerification = _currentUserProfileData!['verificationStatus'] ?? 'unverified';
      final bool isVerified = donorVerification.toLowerCase() == 'verified';

      if (!isDonorAvailable) {
        throw Exception("Please turn ON 'Ready to Donate' on Home or Profile first.");
      }
      if (donorBloodType == null || requiredBloodType == null) {
        throw Exception("Missing blood type info for compatibility validation.");
      }
      if (!isBloodTypeCompatible(donorBloodType, requiredBloodType)) {
        throw Exception(
            "Your blood type ($donorBloodType) is not compatible with $requiredBloodType.");
      }

      final int remainingUnits = (requestData['remainingUnits'] ??
          (requestData['requiredUnits'] ?? requestData['unitsNeeded'] ?? 1)) as int;

      if (remainingUnits <= 0) {
        throw Exception("This request is already fully covered!");
      }

      int chosenUnits = 1;

      if (!mounted) return;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text("Offer Blood Donation",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You are volunteering to donate $donorBloodType for this patient at ${requestData['hospitalName'] ?? 'hospital'}.",
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Units You Can Donate:",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded,
                                color: AppColors.textSecondary),
                            onPressed: chosenUnits > 1
                                ? () => setDialogState(() => chosenUnits--)
                                : null,
                          ),
                          Column(
                            children: [
                              Text(
                                "$chosenUnits Unit${chosenUnits > 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                "Max available: $remainingUnits",
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                color: AppColors.primary),
                            onPressed: chosenUnits < remainingUnits
                                ? () => setDialogState(() => chosenUnits++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "⚠️ By confirming, you commit to arriving at the facility promptly if accepted.",
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text("Confirm Offer ($chosenUnits Unit${chosenUnits > 1 ? 's' : ''})"),
                  ),
                ],
              );
            },
          );
        },
      );

      if (proceed != true) return;

      setState(() => _isProcessingAction = true);

      await _requestService.submitOffer(
        requestId: widget.requestId,
        donorId: currentUserId,
        donorName: _currentUserProfileData!['name'] ?? 'Volunteer Donor',
        donorBloodType: donorBloodType,
        offeredUnits: chosenUnits,
        donorIsVerified: isVerified,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Offer for $chosenUnits unit(s) submitted! The requester has been notified."),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // --- Withdraw Offer Action ---
  Future<void> _withdrawOffer(String offerId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Withdraw Donation Offer?"),
        content: const Text(
            "Are you sure you want to withdraw your offer to donate? The patient may still be in need."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep Offer")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Withdraw Offer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      await _requestService.withdrawOffer(widget.requestId, offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Offer withdrawn successfully."),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.critical),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // --- Cancel Request Action (Requester) ---
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
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Cancel Blood Request"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Please let donors know why this blood request is being cancelled:",
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
                      if (val != null) setDState(() => selectedReason = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text("Keep Active")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text("Confirm Cancel"),
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
      await _requestService.cancelBloodRequest(widget.requestId, reason: selectedReason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Blood request cancelled."),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.critical),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // --- Accept Offer Action ---
  Future<void> _acceptOfferAction(
    String offerId,
    String donorId,
    String donorName,
    int offeredUnits,
    int remainingUnits,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Accept Donor Offer"),
        content: Text(
          "Accept offer from $donorName for $offeredUnits unit(s)?\n\n"
          "This will deduct $offeredUnits unit(s) from the required total ($remainingUnits remaining).",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Accept Offer"),
          ),
        ],
      ),
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
            content: Text("Accepted $donorName for $offeredUnits unit(s)!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // --- Reject Offer Action ---
  Future<void> _rejectOfferAction(String offerId) async {
    setState(() => _isProcessingAction = true);
    try {
      await _requestService.rejectOffer(widget.requestId, offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Offer declined."),
            backgroundColor: AppColors.high,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.critical),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // --- Delete Request ---
  Future<void> _deleteRequest() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Blood Request?'),
        content: const Text(
            'Are you sure you want to delete this blood request? This action cannot be undone.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessingAction = true);
      try {
        await _requestService.deleteBloodRequest(widget.requestId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Blood request deleted successfully."),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete error: $e"), backgroundColor: AppColors.critical),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessingAction = false);
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: iconColor ?? AppColors.textSecondary),
          const SizedBox(width: 12.0),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not Provided',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Embedded Mini OpenStreetMap Widget ---
  Widget _buildMiniOpenStreetMap(GeoPoint coords, String hospitalName) {
    final location = LatLng(coords.latitude, coords.longitude);

    return Container(
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: location,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.redcellnet.app',
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
                      child: const Icon(Icons.local_hospital_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppColors.softShadow,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'OpenStreetMap',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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

  // --- Offers Section (For Requester or Viewers) ---
  Widget _buildOffersSection(String currentRequestId, int remainingUnits, bool isRequester) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SectionHeader(
          title: isRequester ? 'Pending Offers' : 'Community Responses',
          subtitle: isRequester
              ? 'Review and accept donor offers until units are fulfilled'
              : 'Volunteers offering to help this patient',
          icon: Icons.volunteer_activism_rounded,
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requestService.getOffersStream(currentRequestId),
          builder: (context, offerSnapshot) {
            if (offerSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              );
            }

            if (offerSnapshot.hasError) {
              return Text(
                "Error loading offers: ${offerSnapshot.error}",
                style: const TextStyle(color: AppColors.critical),
              );
            }

            final docs = offerSnapshot.data?.docs ?? [];
            final pendingOffers = docs.where((d) => d.data()['status'] == 'pending').toList();

            if (pendingOffers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    isRequester
                        ? "No pending donation offers. We are alerting nearby donors!"
                        : "No offers yet. Be the first to help!",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingOffers.length,
              itemBuilder: (context, index) {
                final offerDoc = pendingOffers[index];
                final offerData = offerDoc.data();
                final String donorName = offerData['donorName'] ?? 'Volunteer Donor';
                final String donorBloodType = offerData['donorBloodType'] ?? 'N/A';
                final int offeredUnits = (offerData['offeredUnits'] ?? 1) as int;
                final bool donorIsVerified = offerData['donorIsVerified'] ?? false;
                final Timestamp? offerTime = offerData['offerTimestamp'] as Timestamp?;
                final String donorId = offerData['donorId'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: BloodGroupBadge(bloodType: donorBloodType, size: 44),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            donorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        VerificationBadge(
                          status: donorIsVerified ? 'verified' : 'unverified',
                          compact: true,
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          "Offering $offeredUnits Unit${offeredUnits > 1 ? 's' : ''} • ${_formatTimestamp(offerTime)}",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: isRequester
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: Text("Accept ($offeredUnits)"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _acceptOfferAction(
                                  offerDoc.id,
                                  donorId,
                                  donorName,
                                  offeredUnits,
                                  remainingUnits,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textMuted, size: 20),
                                tooltip: "Decline",
                                onPressed: () => _rejectOfferAction(offerDoc.id),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- Accepted Donors Section ---
  Widget _buildAcceptedDonorsSection(String requestId, bool isRequester) {
    return StreamBuilder<AppQuerySnapshot>(
      stream: _requestService.getOffersStream(requestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final acceptedDocs = snapshot.data!.docs
            .where((doc) => doc.data()['status'] == 'accepted')
            .toList();
        if (acceptedDocs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Confirmed Donors',
              subtitle: 'Heroes who have stepped up for this request',
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 8),
            ...acceptedDocs.map((doc) {
              final data = doc.data();
              final donorName = data['donorName'] ?? 'Volunteer Donor';
              final donorBloodType = data['donorBloodType'] ?? '';
              final offeredUnits = data['offeredUnits'] ?? 1;
              final donorId = data['donorId'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    BloodGroupBadge(bloodType: donorBloodType, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                donorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Donating $offeredUnits unit(s) • Status: Accepted",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isRequester)
                      FutureBuilder<ProfileSnapshot>(
                        future: _profileService.getUserProfile(donorId),
                        builder: (ctx, pSnap) {
                          final pData = pSnap.data?.data();
                          final phone = pData?['phoneNumber'] ?? pData?['phone_number'];
                          if (phone == null || phone.toString().isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.call_rounded, color: Color(0xFF166534)),
                            tooltip: "Call Donor",
                            onPressed: () => _contactRequester(phone.toString()),
                          );
                        },
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = this.currentUserId;

    return StreamBuilder<AppDocSnapshot>(
      stream: _requestService.getRequestStream(widget.requestId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
              message: 'This blood request may have been removed or fulfilled.',
              buttonText: 'Back to Requests',
              onAction: () => Navigator.pop(context),
            ),
          );
        }

        final requestData = snapshot.data!.data();
        final String patientInfo = requestData['patientIdentifier'] ?? 'N/A';
        final String bloodType = requestData['requiredBloodType'] ?? 'N/A';
        final String componentType = requestData['componentType'] ?? 'Whole Blood';

        final int requiredUnits =
            (requestData['requiredUnits'] ?? requestData['unitsNeeded'] ?? 1) as int;
        final int acceptedUnits = (requestData['acceptedUnits'] ?? 0) as int;
        final int remainingUnits = (requestData['remainingUnits'] ?? (requiredUnits - acceptedUnits)) as int;

        final String urgency = requestData['urgencyLevel'] ?? 'Medium';
        final String hospitalName = requestData['hospitalName'] ?? 'Unknown Hospital';
        final String hospitalAddress = requestData['hospitalAddress'] ?? 'No address provided';
        final String contactPerson = requestData['contactPerson'] ?? 'N/A';
        final String contactNumber = requestData['contactNumber'] ?? '';
        final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
        final Timestamp? expiryAt = requestData['expiryAt'] as Timestamp?;
        final String status = requestData['status'] ?? 'Open';
        final String? cancellationReason = requestData['cancellationReason'];

        final String? requesterUserId = requestData['requesterUserId'];
        final bool isRequester = (requesterUserId != null &&
            currentUserId != null &&
            requesterUserId == currentUserId);

        final dynamic hospitalCoords = requestData['hospitalCoords'];
        GeoPoint? geoPoint;
        if (hospitalCoords is GeoPoint) geoPoint = hospitalCoords;

        final String? userBloodType = _currentUserProfileData?['bloodType'];
        final bool isCompatible = userBloodType != null
            ? isBloodTypeCompatible(userBloodType, bloodType)
            : false;

        final bool isRequestActive = (status == 'Open' || status == 'Partially Fulfilled') && remainingUnits > 0;

        return StreamBuilder<AppQuerySnapshot>(
          stream: currentUserId != null
              ? _requestService.getOffersStream(widget.requestId).map((qs) =>
                  AppQuerySnapshot(qs.docs
                      .where((d) => d.data()['donorId'] == currentUserId)
                      .toList()))
              : const Stream.empty(),
          builder: (context, userOffersSnap) {
            String? myPendingOfferId;
            int myOfferedUnits = 1;
            bool hasAcceptedOffer = false;

            if (userOffersSnap.hasData && userOffersSnap.data!.docs.isNotEmpty) {
              for (var doc in userOffersSnap.data!.docs) {
                final d = doc.data();
                if (d['status'] == 'pending') {
                  myPendingOfferId = doc.id;
                  myOfferedUnits = d['offeredUnits'] ?? 1;
                } else if (d['status'] == 'accepted') {
                  hasAcceptedOffer = true;
                }
              }
            }

            return Scaffold(
              backgroundColor: AppColors.scaffoldBackground,
              appBar: AppBar(
                title: const Text('Request Details'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share Request',
                    onPressed: () => _shareRequest(requestData),
                  ),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (val) {
                      if (val == 'report') {
                        showReportDialog(
                          context,
                          targetType: 'request',
                          targetId: widget.requestId,
                        );
                      } else if (val == 'cancel') {
                        _cancelRequest();
                      } else if (val == 'delete') {
                        _deleteRequest();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.report_problem_outlined, color: AppColors.critical, size: 18),
                            SizedBox(width: 8),
                            Text('Report Request', style: TextStyle(color: AppColors.critical)),
                          ],
                        ),
                      ),
                      if (isRequester && isRequestActive)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: AppColors.high, size: 18),
                              SizedBox(width: 8),
                              Text('Cancel Request'),
                            ],
                          ),
                        ),
                      if (isRequester)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: AppColors.critical, size: 18),
                              SizedBox(width: 8),
                              Text('Delete Request', style: TextStyle(color: AppColors.critical)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Cancelled / Expired Notice Banner ---
                        if (status == 'Cancelled') ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.criticalLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppColors.critical, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Request Cancelled: ${cancellationReason ?? 'No longer needed'}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.critical,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // --- Hero Overview Card ---
                        Container(
                          padding: const EdgeInsets.all(18.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  BloodGroupBadge(bloodType: bloodType, size: 60, showGlow: true),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            UrgencyChip(urgency: urgency),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: status == 'Fulfilled'
                                                    ? AppColors.successLight
                                                    : (status == 'Partially Fulfilled'
                                                        ? AppColors.warningLight
                                                        : AppColors.surfaceMuted),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: status == 'Fulfilled'
                                                      ? AppColors.success
                                                      : (status == 'Partially Fulfilled'
                                                          ? AppColors.warningDark
                                                          : AppColors.textSecondary),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          componentType,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Multi-unit progress indicator
                              UnitsProgressIndicator(
                                requiredUnits: requiredUnits,
                                acceptedUnits: acceptedUnits,
                                remainingUnits: remainingUnits,
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: AppColors.divider, height: 1),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.personal_injury_outlined, 'Patient Note', patientInfo),
                              _buildDetailRow(Icons.schedule_rounded, 'Requested',
                                  _formatTimestamp(createdAt, detailed: true)),
                              if (expiryAt != null)
                                _buildDetailRow(Icons.hourglass_bottom_rounded, 'Expires',
                                    _formatTimestamp(expiryAt, detailed: true)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Compatibility Banner (For logged-in donor) ---
                        if (!isRequester && userBloodType != null) ...[
                          CompatibilityBanner(
                            donorBloodType: userBloodType,
                            recipientBloodType: bloodType,
                            isCompatible: isCompatible,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // --- Hospital Location & OpenStreetMap Card ---
                        Container(
                          padding: const EdgeInsets.all(18.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.local_hospital_rounded, color: AppColors.secondary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Hospital & Location',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.apartment_rounded, 'Hospital', hospitalName),
                              _buildDetailRow(Icons.location_on_outlined, 'Address', hospitalAddress),
                              if (geoPoint != null) ...[
                                const SizedBox(height: 14),
                                _buildMiniOpenStreetMap(geoPoint, hospitalName),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Contact Person Card ---
                        Container(
                          padding: const EdgeInsets.all(18.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.call_rounded, color: AppColors.success, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Contact Person & Attendant',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.person_outline_rounded, 'Contact', contactPerson),
                              _buildDetailRow(Icons.phone_outlined, 'Phone',
                                  contactNumber.isNotEmpty ? contactNumber : 'Not Set'),
                            ],
                          ),
                        ),

                        // --- Confirmed / Accepted Donors Section ---
                        if (acceptedUnits > 0)
                          _buildAcceptedDonorsSection(widget.requestId, isRequester),

                        // --- Pending Offers Section ---
                        if (isRequestActive)
                          _buildOffersSection(widget.requestId, remainingUnits, isRequester),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),

                  // --- Bottom Action Bar ---
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: const Border(top: BorderSide(color: AppColors.border)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            if (contactNumber.isNotEmpty)
                              Expanded(
                                flex: 4,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.call_rounded, size: 18),
                                  label: const Text('Call / Copy'),
                                  onPressed: () => _contactRequester(contactNumber),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            if (contactNumber.isNotEmpty) const SizedBox(width: 12),
                            if (!isRequester)
                              Expanded(
                                flex: 6,
                                child: hasAcceptedOffer
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: AppColors.successLight,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.success),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            "🎉 Offer Accepted! Proceed to Hospital",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      )
                                    : (myPendingOfferId != null
                                        ? ElevatedButton.icon(
                                            icon: const Icon(Icons.cancel_outlined, size: 18),
                                            label: Text("Withdraw ($myOfferedUnits unit${myOfferedUnits > 1 ? 's' : ''})"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.critical,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            onPressed: _isProcessingAction
                                                ? null
                                                : () => _withdrawOffer(myPendingOfferId!),
                                          )
                                        : (isRequestActive
                                            ? ElevatedButton.icon(
                                                icon: const Icon(Icons.volunteer_activism_rounded, size: 20),
                                                label: const Text(
                                                  'Offer Blood',
                                                  style: TextStyle(fontWeight: FontWeight.w800),
                                                ),
                                                onPressed: _isProcessingAction
                                                    ? null
                                                    : () => _showOfferBloodDialog(requestData),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                              )
                                            : Container(
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceMuted,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    status == 'Fulfilled'
                                                        ? 'Request Fulfilled'
                                                        : 'Request Closed',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ))),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Loading Overlay
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
      },
    );
  }
}
