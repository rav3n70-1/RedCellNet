// lib/features/admin/presentation/pages/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/push_notification_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';
import 'package:red_cell_net_final/features/donation_centers/data/services/donation_center_service.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';
import 'package:red_cell_net_final/features/educational_content/data/services/content_service.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final DonationCenterService _centerService = DonationCenterService();
  final UserProfileService _profileService = UserProfileService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  final ContentService _contentService = ContentService();
  final RequestService _requestService = RequestService();

  // Cached Realtime Streams
  Stream<ProfileSnapshot>? _staffProfileStream;
  Stream<List<Map<String, dynamic>>>? _profilesStream;
  Stream<List<Map<String, dynamic>>>? _requestsStream;
  Stream<List<Map<String, dynamic>>>? _reportsStream;
  Stream<List<Map<String, dynamic>>>? _broadcastsStream;
  Stream<List<Map<String, dynamic>>>? _auditLogsStream;
  Stream<List<DonationCenter>>? _centersStream;
  Stream<List<ContentItem>>? _contentStream;

  // Navigation state
  int _selectedTabIndex = 0;
  int _dispatchSubTabIndex = 0; // 0: Hospital Appeals, 1: Safety Reports
  int _opsSubTabIndex = 0; // 0: Facilities, 1: Broadcasts, 2: Learn CMS, 3: Audit Logs

  // Search & Filter States
  String _userSearchQuery = '';
  String _userRoleFilter = 'all';

  // Broadcast Composer Controllers
  final _broadcastTitleCtrl = TextEditingController();
  final _broadcastMsgCtrl = TextEditingController();
  final _broadcastCityCtrl = TextEditingController();
  final _directUserIdCtrl = TextEditingController();
  String _broadcastTargetMode = 'broadcast'; // 'broadcast' | 'direct'
  String _selectedBroadcastBlood = 'ALL';
  String _selectedBroadcastType = 'shortage';
  String _selectedBroadcastDuration = '24h';
  bool _isBroadcasting = false;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final uid = _authService.currentUserId;
    if (uid != null && uid.isNotEmpty) {
      _staffProfileStream = _profileService.getUserProfileStream(uid);
    }
    if (SupabaseConfig.isInitialized) {
      final client = SupabaseConfig.client;
      _profilesStream = client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .asBroadcastStream();
      _requestsStream = client
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .asBroadcastStream();
      _reportsStream = client
          .from('reports')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .asBroadcastStream();
      _broadcastsStream = client
          .from('system_broadcasts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .asBroadcastStream();
      _auditLogsStream = client
          .from('admin_logs')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(100)
          .asBroadcastStream();
    }
    _centersStream = _centerService.getDonationCentersStream();
    _contentStream = _contentService.getContentStream();
  }

  DateTime? _computeBroadcastExpiry(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case '1h':
        return now.add(const Duration(hours: 1));
      case '6h':
        return now.add(const Duration(hours: 6));
      case '12h':
        return now.add(const Duration(hours: 12));
      case '24h':
        return now.add(const Duration(hours: 24));
      case '3d':
        return now.add(const Duration(days: 3));
      case '7d':
        return now.add(const Duration(days: 7));
      case 'indefinite':
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _broadcastTitleCtrl.dispose();
    _broadcastMsgCtrl.dispose();
    _broadcastCityCtrl.dispose();
    _directUserIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchToDonorView() async {
    await AppSettingsService().setStaffWorkspaceMode('donor');
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        title: Text(
          'End Staff Session',
          style: TextStyle(
              color: AppColors.textPrimaryOf(ctx), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of the Staff Command Console?',
          style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // --- Preview Private Verification Document ---
  Future<void> _previewVerificationDocument(String storagePath) async {
    final signedUrl =
        await _profileService.getVerificationDocumentSignedUrl(storagePath);
    if (!mounted) return;
    if (signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate signed URL for verification file.'),
          backgroundColor: AppColors.critical,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Submitted Lab Report Evidence',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimaryOf(ctx),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 440),
                  child: InteractiveViewer(
                    child: Image.network(
                      signedUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded,
                                size: 48, color: AppColors.primary),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => launchUrl(Uri.parse(signedUrl),
                                  mode: LaunchMode.externalApplication),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open External File'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Approve / Reject User Verification ---
  Future<void> _handleVerificationDecision(
      String userId, String userName, bool approve) async {
    String note = approve
        ? 'Verified against laboratory blood report'
        : 'Inconclusive or illegible lab report — please upload a clearer image.';
    if (!approve) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: note);
          return AlertDialog(
            backgroundColor: AppColors.cardBg(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: AppColors.borderSideOf(ctx),
            ),
            title: Text(
              'Reject Donor Verification',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(ctx),
                  fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Specify audit reason (shown to applicant so they can resubmit):',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryOf(ctx)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textPrimaryOf(ctx)),
                  decoration:
                      const InputDecoration(labelText: 'Rejection Reason'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.critical,
                    foregroundColor: Colors.white),
                onPressed: () {
                  note = ctrl.text.trim();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Confirm Rejection'),
              ),
            ],
          );
        },
      );
      if (proceed != true) return;
    }

    try {
      await _profileService.verifyDonor(
        targetUserId: userId,
        shouldApprove: approve,
        adminNotes: note,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? '$userName verified as Lifesaver Donor!'
                : 'Verification marked rejected with feedback.'),
            backgroundColor: approve ? AppColors.success : AppColors.critical,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Resolve Safety / Abuse Report ---
  Future<void> _handleResolveReport(String reportId, String action) async {
    final notesCtrl = TextEditingController(
      text: action == 'action_taken'
          ? 'Confirmed policy violation — enforcement action applied.'
          : 'Reviewed by moderation desk — no policy violation found.',
    );

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: AppColors.borderSideOf(ctx),
        ),
        title: Text(
          action == 'action_taken' ? 'Enforce & Close Report' : 'Dismiss Report',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(ctx)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action == 'action_taken'
                  ? 'Taking action automatically cancels reported fake requests or suspends abusive profiles and logs an audit entry.'
                  : 'Dismissing closes the report with your review note.',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondaryOf(ctx)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Moderation Audit Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'action_taken'
                  ? AppColors.critical
                  : AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                action == 'action_taken' ? 'Enforce Action' : 'Confirm Dismiss'),
          ),
        ],
      ),
    );

    if (proceed != true) return;
    try {
      await _profileService.resolveModerationReport(
        reportId: reportId,
        action: action,
        notes: notesCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'action_taken'
                ? 'Enforcement action applied & report resolved.'
                : 'Report dismissed.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Report action error: $e'),
              backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Manage User Role (Super Admin Only) ---
  Future<void> _handleRoleChange(
      String userId, String userName, String newRole) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        title: Text(
          'Change Role: $userName',
          style: TextStyle(
              color: AppColors.textPrimaryOf(ctx), fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Set $userName's role to '${newRole.toUpperCase()}'?",
          style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newRole == 'moderator'
                  ? AppColors.imperialGold
                  : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _profileService.manageUserRole(
          targetUserId: userId,
          newRole: newRole,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName role updated to $newRole.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error changing role: $e'),
                backgroundColor: AppColors.critical),
          );
        }
      }
    }
  }

  // --- Ban / Unban User ---
  Future<void> _handleBanUser(
      String userId, String userName, bool currentlyBanned) async {
    String banReason = 'Violation of community safety policies';
    if (!currentlyBanned) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: banReason);
          return AlertDialog(
            backgroundColor: AppColors.cardBg(ctx),
            title: Text(
              'Suspend Account: $userName',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(ctx),
                  fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Suspending this account immediately blocks request creation and donor offers.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryOf(ctx)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  style: TextStyle(color: AppColors.textPrimaryOf(ctx)),
                  decoration:
                      const InputDecoration(labelText: 'Suspension Reason'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  banReason = ctrl.text.trim();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Confirm Suspension'),
              ),
            ],
          );
        },
      );
      if (proceed != true) return;
    }

    try {
      await _profileService.setUserBanStatus(
        targetUserId: userId,
        shouldBan: !currentlyBanned,
        reason: banReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentlyBanned
                ? '$userName account suspended.'
                : '$userName account restored.'),
            backgroundColor:
                !currentlyBanned ? AppColors.critical : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating ban status: $e'),
              backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Verify Hospital Case ---
  Future<void> _handleVerifyHospitalCase(
      String requestId, String patientName, bool currentlyVerified) async {
    String staffNote = 'Verified by Hospital Liaison Desk';
    if (!currentlyVerified) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: staffNote);
          return AlertDialog(
            backgroundColor: AppColors.cardBg(ctx),
            title: Text(
              'Verify Hospital Case: $patientName',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(ctx),
                  fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Adds an official 'Verified Hospital Case' seal to this blood appeal.",
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryOf(ctx)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  style: TextStyle(color: AppColors.textPrimaryOf(ctx)),
                  decoration:
                      const InputDecoration(labelText: 'Staff Internal Note'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  staffNote = ctrl.text.trim();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Verify Case'),
              ),
            ],
          );
        },
      );
      if (proceed != true) return;
    }

    try {
      await _profileService.verifyHospitalCase(
        requestId: requestId,
        isVerified: !currentlyVerified,
        staffNote: staffNote,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentlyVerified
                ? 'Official Hospital Verification badge granted!'
                : 'Hospital verification removed.'),
            backgroundColor: !currentlyVerified
                ? AppColors.success
                : AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Dispatch Broadcast or Direct Notification ---
  Future<void> _dispatchEmergencyBroadcast() async {
    final title = _broadcastTitleCtrl.text.trim();
    final message = _broadcastMsgCtrl.text.trim();
    final city = _broadcastCityCtrl.text.trim();
    final directUid = _directUserIdCtrl.text.trim();
    final bloodType =
        _selectedBroadcastBlood == 'ALL' ? null : _selectedBroadcastBlood;

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both a title and message.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_broadcastTargetMode == 'direct' && directUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a target User UUID for direct message.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isBroadcasting = true);
    try {
      if (_broadcastTargetMode == 'direct') {
        await _profileService.sendDirectAdminNotification(
          targetUserId: directUid,
          title: title,
          message: message,
          type: _selectedBroadcastType,
        );
      } else {
        final expiry = _computeBroadcastExpiry(_selectedBroadcastDuration);
        await _profileService.createEmergencyBroadcast(
          title: title,
          message: message,
          broadcastType: _selectedBroadcastType,
          targetBloodType: bloodType,
          targetCity: city.isEmpty ? null : city,
          expiresAt: expiry,
        );
        await PushNotificationService().showEmergencyNotification(
          title: title,
          body: message,
          targetBloodType: bloodType,
        );
      }

      _broadcastTitleCtrl.clear();
      _broadcastMsgCtrl.clear();
      _broadcastCityCtrl.clear();
      _directUserIdCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_broadcastTargetMode == 'direct'
                ? 'Direct notification delivered to user!'
                : 'Emergency broadcast dispatched to matching donors!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to dispatch alert: $e'),
              backgroundColor: AppColors.critical),
        );
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  void _showEditBroadcastDialog(Map<String, dynamic> broadcast) {
    final id = broadcast['id']?.toString() ?? '';
    final titleCtrl = TextEditingController(text: broadcast['title'] ?? '');
    final msgCtrl = TextEditingController(text: broadcast['message'] ?? '');
    final cityCtrl =
        TextEditingController(text: broadcast['target_city'] ?? '');
    String blood = broadcast['target_blood_type'] ?? 'ALL';
    bool isActive = broadcast['is_active'] == true;
    String duration = 'keep';

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppColors.cardBg(context),
          title: Text(
            'Edit System Broadcast',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notification Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message Body'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: blood,
                        decoration:
                            const InputDecoration(labelText: 'Target Blood'),
                        items: [
                          'ALL',
                          'A+',
                          'A-',
                          'B+',
                          'B-',
                          'AB+',
                          'AB-',
                          'O+',
                          'O-'
                        ]
                            .map((bg) =>
                                DropdownMenuItem(value: bg, child: Text(bg)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => blood = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Target City'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: duration,
                  decoration: const InputDecoration(
                    labelText: 'Visible Duration',
                    prefixIcon: Icon(Icons.timer_outlined, size: 18),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'keep', child: Text('Keep Existing Expiry')),
                    DropdownMenuItem(
                        value: '1h', child: Text('+1 Hour from now')),
                    DropdownMenuItem(
                        value: '6h', child: Text('+6 Hours from now')),
                    DropdownMenuItem(
                        value: '24h', child: Text('+24 Hours from now')),
                    DropdownMenuItem(
                        value: '3d', child: Text('+3 Days from now')),
                    DropdownMenuItem(
                        value: '7d', child: Text('+7 Days from now')),
                    DropdownMenuItem(
                        value: 'indefinite',
                        child: Text('Permanent / No Expiry')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => duration = val);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active In-App Banner',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  value: isActive,
                  onChanged: (val) => setDlgState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dlgCtx);
                DateTime? newExpiry;
                if (duration != 'keep') {
                  newExpiry = _computeBroadcastExpiry(duration);
                } else if (broadcast['expires_at'] != null) {
                  newExpiry =
                      DateTime.tryParse(broadcast['expires_at'].toString());
                }
                try {
                  await _profileService.updateEmergencyBroadcast(
                    id: id,
                    title: titleCtrl.text.trim(),
                    message: msgCtrl.text.trim(),
                    targetBloodType: blood == 'ALL' ? null : blood,
                    targetCity: cityCtrl.text.trim().isEmpty
                        ? null
                        : cityCtrl.text.trim(),
                    isActive: isActive,
                    expiresAt: newExpiry,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update broadcast: $e'),
                        backgroundColor: AppColors.critical,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Export Data to CSV ---
  Future<void> _exportDataToCsv() async {
    try {
      final supabase = SupabaseConfig.client;
      final usersRes = await supabase.from('profiles').select();
      final List<dynamic> users = usersRes as List<dynamic>;

      final buffer = StringBuffer();
      buffer.writeln(
          'User_ID,Name,Blood_Type,Role,Verified_Donor,Donations,City,Email,Phone');

      for (final u in users) {
        final id = u['id'] ?? '';
        final name = (u['name'] ?? 'N/A').toString().replaceAll(',', ' ');
        final blood = u['blood_type'] ?? 'Unset';
        final role = u['role'] ?? 'user';
        final isVerified = u['is_verified_donor'] == true ? 'YES' : 'NO';
        final totalDonations = u['total_donations'] ?? 0;
        final city =
            (u['location_city'] ?? 'N/A').toString().replaceAll(',', ' ');
        final email = u['email'] ?? 'N/A';
        final phone = u['phone_number'] ?? 'N/A';

        buffer.writeln(
            '$id,"$name",$blood,$role,$isVerified,$totalDonations,"$city",$email,$phone');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Exported ${users.length} donor records to CSV on clipboard.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Add / Edit Facility Dialog ---
  void _showFacilityDialog({DonationCenter? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? 'Dhaka');
    final phoneCtrl = TextEditingController(text: existing?.contactInfo ?? '');
    final hoursCtrl = TextEditingController(
        text: existing?.operatingHours ?? 'Open 24 Hours / 7 Days');
    final latCtrl = TextEditingController(
        text: existing != null ? existing.latitude.toString() : '23.8103');
    final lngCtrl = TextEditingController(
        text: existing != null ? existing.longitude.toString() : '90.4125');
    String facilityType = existing?.facilityType ?? 'Blood Bank';
    String opStatus = existing?.operationalStatus ?? 'Open';
    bool isVerified = existing?.isVerified ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: AppColors.cardBg(dCtx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: AppColors.borderSideOf(dCtx),
          ),
          title: Text(
            existing != null ? 'Edit Facility' : 'Register Donation Facility',
            style: TextStyle(
                color: AppColors.textPrimaryOf(dCtx),
                fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Facility / Hospital Name *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: const [
                          'Blood Bank',
                          'Hospital Transfusion Dept',
                          'Red Crescent Center'
                        ].contains(facilityType)
                            ? facilityType
                            : 'Blood Bank',
                        decoration:
                            const InputDecoration(labelText: 'Facility Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Blood Bank', child: Text('Blood Bank')),
                          DropdownMenuItem(
                              value: 'Hospital Transfusion Dept',
                              child: Text('Hospital Dept')),
                          DropdownMenuItem(
                              value: 'Red Crescent Center',
                              child: Text('Red Crescent')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDState(() => facilityType = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: const [
                          'Open',
                          '24/7 Open',
                          'Limited Hours',
                          'Temporarily Closed'
                        ].contains(opStatus)
                            ? opStatus
                            : 'Open',
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'Open', child: Text('Open')),
                          DropdownMenuItem(
                              value: '24/7 Open', child: Text('24/7 Open')),
                          DropdownMenuItem(
                              value: 'Limited Hours',
                              child: Text('Limited Hours')),
                          DropdownMenuItem(
                              value: 'Temporarily Closed',
                              child: Text('Closed')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDState(() => opStatus = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Street Address *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Hotline Phone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hoursCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Operating Hours'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Latitude *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Longitude *'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified Official Facility',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  value: isVerified,
                  onChanged: (v) => setDState(() => isVerified = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final lat = double.tryParse(latCtrl.text.trim());
                final lng = double.tryParse(lngCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty ||
                    lat == null ||
                    lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please fill name and valid coordinates.')),
                  );
                  return;
                }
                Navigator.pop(dCtx);
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'latitude': lat,
                  'longitude': lng,
                  'operating_hours': hoursCtrl.text.trim(),
                  'contact_info': phoneCtrl.text.trim(),
                  'contact_number': phoneCtrl.text.trim(),
                  'facility_type': facilityType,
                  'operational_status': opStatus,
                  'is_verified': isVerified,
                };
                try {
                  if (existing != null) {
                    await _centerService.updateCenter(existing.id, payload);
                  } else {
                    await _centerService.addCenter(payload);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existing != null
                            ? 'Facility updated!'
                            : 'Facility registered!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to save facility: $e'),
                          backgroundColor: AppColors.critical),
                    );
                  }
                }
              },
              child: const Text('Save Facility'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Add / Edit Educational Guide Dialog ---
  void _showContentEditorDialog({ContentItem? existing}) {
    final titleEnCtrl = TextEditingController(text: existing?.titleEn ?? '');
    final titleBnCtrl = TextEditingController(text: existing?.titleBn ?? '');
    final bodyEnCtrl = TextEditingController(text: existing?.contentEn ?? '');
    final bodyBnCtrl = TextEditingController(text: existing?.contentBn ?? '');
    final sourceCtrl =
        TextEditingController(text: existing?.sourceAttribution ?? 'WHO & DGHS Clinical Transfusion Guidelines');
    String category = existing?.category ?? 'Eligibility';
    final readMinCtrl = TextEditingController(
        text: (existing?.readTimeMinutes ?? 3).toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: AppColors.cardBg(dCtx),
          title: Text(
              existing != null ? 'Edit Health Guide' : 'New Health Guide',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleEnCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Title (English) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleBnCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Title (বাংলা)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: const [
                          'Eligibility',
                          'Preparation',
                          'Health Benefits',
                          'Myths & Facts'
                        ].contains(category)
                            ? category
                            : 'Eligibility',
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Eligibility', child: Text('Eligibility')),
                          DropdownMenuItem(
                              value: 'Preparation', child: Text('Preparation')),
                          DropdownMenuItem(
                              value: 'Health Benefits',
                              child: Text('Health Benefits')),
                          DropdownMenuItem(
                              value: 'Myths & Facts',
                              child: Text('Myths & Facts')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDState(() => category = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: readMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Read Min'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyEnCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Article Body (English) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyBnCtrl,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Article Body (বাংলা)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sourceCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Medical Source Attribution'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleEnCtrl.text.trim().isEmpty ||
                    bodyEnCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dCtx);
                try {
                  await _contentService.saveContentItem(
                    id: existing?.id,
                    titleEn: titleEnCtrl.text.trim(),
                    titleBn: titleBnCtrl.text.trim().isEmpty
                        ? titleEnCtrl.text.trim()
                        : titleBnCtrl.text.trim(),
                    contentEn: bodyEnCtrl.text.trim(),
                    contentBn: bodyBnCtrl.text.trim().isEmpty
                        ? bodyEnCtrl.text.trim()
                        : bodyBnCtrl.text.trim(),
                    category: category,
                    readTimeMinutes:
                        int.tryParse(readMinCtrl.text.trim()) ?? 3,
                    sourceAttribution: sourceCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Educational article saved!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving guide: $e'),
                        backgroundColor: AppColors.critical,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Article'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return StreamBuilder<ProfileSnapshot>(
      stream: _staffProfileStream ?? const Stream.empty(),
      builder: (context, staffSnap) {
        if (staffSnap.connectionState == ConnectionState.waiting &&
            !staffSnap.hasData) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final staffData = staffSnap.data?.data();
        final String currentRole =
            (staffData?['role'] ?? 'user').toString().toLowerCase();
        final bool isBanned = staffData?['isBanned'] == true;
        final bool isStaff =
            !isBanned && (currentRole == 'admin' || currentRole == 'moderator');
        final bool isSuperAdmin = currentRole == 'admin';

        // Strict RBAC Enforcement Gate
        if (!isStaff) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            appBar: AppBar(title: const Text('Access Restricted')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_rounded,
                        size: 56, color: AppColors.critical),
                    const SizedBox(height: 14),
                    Text(
                      'Staff Authorization Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Only verified RedCellNet Administrators and Medical Moderators can access the Staff Command Console.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          _switchToDonorView();
                        }
                      },
                      child: const Text('Return to Donor App'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.scaffoldOf(context),
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Staff Command Console',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isSuperAdmin
                              ? AppColors.imperialGold
                              : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _switchToDonorView,
                icon: const Icon(Icons.volunteer_activism_outlined, size: 15),
                label: const Text('Donor View',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                icon:
                    const Icon(Icons.logout_rounded, color: AppColors.critical),
                tooltip: 'End Staff Session',
                onPressed: _logout,
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildOperationsConsole(),
              _buildDispatchAndReportsDesk(),
              _buildVerificationQueue(),
              _buildStaffUsersDirectory(isSuperAdmin: isSuperAdmin),
              _buildOperationsAndBroadcastsDesk(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              border: Border(
                  top: BorderSide(
                      color: AppColors.borderOf(context), width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                child: Row(
                  children: [
                    _buildStaffNavItem(0, Icons.space_dashboard_rounded,
                        Icons.space_dashboard_outlined, 'Console'),
                    _buildStaffNavItem(1, Icons.emergency_rounded,
                        Icons.emergency_outlined, 'Moderation'),
                    _buildStaffNavItem(2, Icons.verified_user_rounded,
                        Icons.verified_user_outlined, 'Verify'),
                    _buildStaffNavItem(3, Icons.badge_rounded,
                        Icons.badge_outlined, 'Directory'),
                    _buildStaffNavItem(4, Icons.cell_tower_rounded,
                        Icons.cell_tower_outlined, 'Ops'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffNavItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final bool isSelected = _selectedTabIndex == index;
    final isDark = AppColors.isDark(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : AppColors.primaryContainer)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryOf(context),
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFFF43F5E)
                          : AppColors.primaryDark)
                      : AppColors.textSecondaryOf(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Desk 0: Operations Console ---
  Widget _buildOperationsConsole() {
    final currentEmail =
        _authService.currentUserEmail ?? 'staff@redcellnet.org';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _profilesStream ?? const Stream.empty(),
      builder: (context, userSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _requestsStream ?? const Stream.empty(),
          builder: (context, reqSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reportsStream ?? const Stream.empty(),
              builder: (context, repSnap) {
                final users = userSnap.data ?? [];
                final totalUsers = users.length;
                final verifiedUsers = users
                    .where((d) =>
                        (d['verification_status'] ??
                            d['verificationStatus']) ==
                        'verified')
                    .length;
                final pendingVerifications = users
                    .where((d) =>
                        (d['verification_status'] ??
                            d['verificationStatus']) ==
                        'pending')
                    .length;

                final requests = reqSnap.data ?? [];
                final activeRequests = requests.where((d) {
                  final s = d['status'];
                  return s == 'Open' || s == 'Partially Fulfilled';
                }).toList();
                final criticalRequests = activeRequests.where((d) {
                  final urg = d['urgency_level'] ?? d['urgencyLevel'];
                  return urg == 'Critical' || urg == 'Urgent' || urg == 'High';
                }).toList();

                final openReports = (repSnap.data ?? [])
                    .where((r) => (r['status'] ?? 'open') == 'open')
                    .length;

                return ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: AppColors.primaryAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Live Operations Online',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.circle,
                                        color: Color(0xFF22C55E), size: 8),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Signed in: $currentEmail',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
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
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStaffKpiCard(
                            title: 'Total Donors',
                            count: '$totalUsers',
                            subtitle: '$verifiedUsers Verified Lifesavers',
                            icon: Icons.people_alt_rounded,
                            color: AppColors.primary,
                            onTap: () => setState(() => _selectedTabIndex = 3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStaffKpiCard(
                            title: 'Active Appeals',
                            count: '${activeRequests.length}',
                            subtitle: '${criticalRequests.length} Urgent/Critical',
                            icon: Icons.emergency_rounded,
                            color: AppColors.critical,
                            onTap: () => setState(() {
                              _selectedTabIndex = 1;
                              _dispatchSubTabIndex = 0;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStaffKpiCard(
                            title: 'Verifications',
                            count: '$pendingVerifications',
                            subtitle: pendingVerifications > 0
                                ? 'Awaiting Review'
                                : 'Queue Clear',
                            icon: Icons.verified_user_rounded,
                            color: pendingVerifications > 0
                                ? AppColors.warning
                                : AppColors.success,
                            onTap: () => setState(() => _selectedTabIndex = 2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStaffKpiCard(
                            title: 'Safety Reports',
                            count: '$openReports',
                            subtitle: openReports > 0
                                ? 'Needs Triage'
                                : 'Zero Open Flags',
                            icon: Icons.flag_rounded,
                            color: openReports > 0
                                ? AppColors.critical
                                : AppColors.secondary,
                            onTap: () => setState(() {
                              _selectedTabIndex = 1;
                              _dispatchSubTabIndex = 1;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Operational Quick Actions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            title: 'Broadcast',
                            icon: Icons.campaign_rounded,
                            color: AppColors.critical,
                            onTap: () => setState(() {
                              _selectedTabIndex = 4;
                              _opsSubTabIndex = 1;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickActionButton(
                            title: 'Add Facility',
                            icon: Icons.add_location_alt_rounded,
                            color: AppColors.secondary,
                            onTap: () => _showFacilityDialog(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickActionButton(
                            title: 'Export CSV',
                            icon: Icons.file_download_outlined,
                            color: AppColors.success,
                            onTap: _exportDataToCsv,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Priority Hospital Appeals (${criticalRequests.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedTabIndex = 1;
                            _dispatchSubTabIndex = 0;
                          }),
                          child: const Text('View All',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    if (criticalRequests.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.borderOf(context)),
                        ),
                        child: Center(
                          child: Text(
                            'No critical emergency appeals in queue.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      )
                    else
                      ...criticalRequests.take(4).map((req) {
                        final reqId = req['id']?.toString() ?? '';
                        final blood = req['required_blood_type'] ?? '?';
                        final hospital = req['hospital_name'] ?? 'Hospital';
                        final units = req['remaining_units'] ??
                            req['required_units'] ??
                            1;
                        final patient = req['patient_name'] ?? 'Patient';
                        final isVerified =
                            req['is_verified_hospital_case'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isVerified
                                  ? AppColors.success.withValues(alpha: 0.35)
                                  : AppColors.critical.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              BloodGroupBadge(
                                  bloodType: blood.toString(), size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$units Unit(s) needed • $patient',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.textPrimaryOf(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      hospital.toString(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            AppColors.textSecondaryOf(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isVerified
                                      ? AppColors.success
                                      : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  elevation: 0,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RequestDetailsPage(requestId: reqId),
                                  ),
                                ),
                                child: Text(
                                  isVerified ? 'Verified' : 'Inspect',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Desk 1: Hospital Appeals & Safety Reports ---
  Widget _buildDispatchAndReportsDesk() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Hospital Appeals')),
                  selected: _dispatchSubTabIndex == 0,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _dispatchSubTabIndex == 0
                        ? Colors.white
                        : AppColors.textPrimaryOf(context),
                  ),
                  onSelected: (_) => setState(() => _dispatchSubTabIndex = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Safety Reports')),
                  selected: _dispatchSubTabIndex == 1,
                  selectedColor: AppColors.critical,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _dispatchSubTabIndex == 1
                        ? Colors.white
                        : AppColors.textPrimaryOf(context),
                  ),
                  onSelected: (_) => setState(() => _dispatchSubTabIndex = 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _dispatchSubTabIndex == 0
              ? _buildModerationQueue()
              : _buildReportsModerationList(),
        ),
      ],
    );
  }

  Widget _buildReportsModerationList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _reportsStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return const EmptyStateView(
            icon: Icons.verified_outlined,
            title: 'Zero Moderation Reports',
            message: 'Community reports on suspicious requests or users appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final r = reports[index];
            final id = r['id']?.toString() ?? '';
            final type = (r['reported_type'] ?? 'request').toString();
            final targetId = (r['target_id'] ?? '').toString();
            final reason = (r['reason'] ?? 'No reason provided').toString();
            final status = (r['status'] ?? 'open').toString();
            final notes = r['moderator_notes']?.toString();
            final isOpen = status == 'open';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOpen
                      ? AppColors.critical.withValues(alpha: 0.45)
                      : AppColors.borderOf(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? AppColors.critical.withValues(alpha: 0.14)
                              : AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${type.toUpperCase()} • ${status.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: isOpen
                                ? AppColors.critical
                                : AppColors.success,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (type == 'request' && targetId.length >= 30)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestDetailsPage(requestId: targetId),
                            ),
                          ),
                          child: const Text('Inspect Target',
                              style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Staff Resolution: $notes',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                  if (isOpen) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleResolveReport(id, 'dismiss'),
                            child: const Text('Dismiss'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.critical,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                _handleResolveReport(id, 'action_taken'),
                            child: const Text('Take Enforcement Action'),
                          ),
                        ),
                      ],
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

  // --- Desk 2: Donor Verification Queue ---
  Widget _buildVerificationQueue() {
    final isDark = AppColors.isDark(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _profilesStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingUsers = (snapshot.data ?? [])
            .where((u) =>
                (u['verification_status'] ?? u['verificationStatus']) ==
                'pending')
            .toList();

        if (pendingUsers.isEmpty) {
          return const EmptyStateView(
            icon: Icons.verified_user_outlined,
            title: 'No Pending Verifications',
            message:
                'All donor medical verification applications have been reviewed.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingUsers.length,
          itemBuilder: (context, index) {
            final data = pendingUsers[index];
            final String userId = data['id']?.toString() ?? '';
            final name = (data['name'] ?? 'Donor Candidate').toString();
            final claimedBlood =
                (data['blood_type'] ?? data['bloodType'] ?? 'Unset').toString();
            final extractedBlood =
                (data['extracted_blood_type'] ?? '').toString();
            final email = (data['email'] ?? '').toString();
            final phone =
                (data['phone_number'] ?? data['phoneNumber'] ?? 'No phone')
                    .toString();
            final lab = (data['verification_lab'] ?? '').toString();
            final certRef = (data['verification_cert'] ?? '').toString();
            final notes = (data['verification_notes'] ?? '').toString();
            final docPath = (data['verification_doc_url'] ?? '').toString();
            final bool hasMismatch = extractedBlood.isNotEmpty &&
                claimedBlood != 'Unset' &&
                extractedBlood != claimedBlood;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: hasMismatch
                        ? AppColors.critical
                        : AppColors.warning.withValues(alpha: 0.45)),
                boxShadow: isDark ? null : AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodGroupBadge(
                        bloodType: claimedBlood == 'Unset' ? '?' : claimedBlood,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            Text(
                              '$email • $phone',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMutedOf(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnostic Lab: ${lab.isNotEmpty ? lab : "Not provided"}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (certRef.isNotEmpty)
                          Text('Reference #: $certRef',
                              style: const TextStyle(fontSize: 11.5)),
                        if (extractedBlood.isNotEmpty)
                          Text(
                            'OCR Extracted Blood Group: $extractedBlood ${hasMismatch ? "(MISMATCH WITH CLAIMED $claimedBlood!)" : "(Matches Claimed)"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: hasMismatch
                                  ? AppColors.critical
                                  : AppColors.success,
                            ),
                          ),
                        if (notes.isNotEmpty)
                          Text('Applicant Note: $notes',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryOf(context))),
                        if (docPath.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _previewVerificationDocument(docPath),
                            icon: const Icon(Icons.visibility_rounded, size: 15),
                            label: const Text('View Private Lab Report',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          const Text(
                            'No lab report image uploaded',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.warning),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.critical,
                              side:
                                  const BorderSide(color: AppColors.critical)),
                          onPressed: () =>
                              _handleVerificationDecision(userId, name, false),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white),
                          onPressed: () =>
                              _handleVerificationDecision(userId, name, true),
                          child: const Text('Approve & Verify'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Requests Moderation List ---
  Widget _buildModerationQueue() {
    final isDark = AppColors.isDark(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _requestsStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRequests = snapshot.data ?? [];
        if (allRequests.isEmpty) {
          return const EmptyStateView(
            icon: Icons.shield_outlined,
            title: 'No Requests to Moderate',
            message: 'All community blood appeals are monitored in real time.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allRequests.length,
          itemBuilder: (context, index) {
            final data = allRequests[index];
            final reqId = data['id']?.toString() ?? '';
            final patient = (data['patient_name'] ?? 'Patient').toString();
            final hospital = (data['hospital_name'] ?? 'Hospital').toString();
            final blood = (data['required_blood_type'] ?? '?').toString();
            final urgency = (data['urgency_level'] ?? 'Normal').toString();
            final status = (data['status'] ?? 'Open').toString();
            final remaining =
                data['remaining_units'] ?? data['required_units'] ?? 1;
            final requiredTotal = data['required_units'] ?? 1;
            final isVerifiedCase = data['is_verified_hospital_case'] == true;
            final contact = (data['contact_phone'] ?? 'N/A').toString();
            final isActive =
                status == 'Open' || status == 'Partially Fulfilled';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isVerifiedCase
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.borderOf(context),
                  width: isVerifiedCase ? 1.5 : 1.0,
                ),
                boxShadow: isDark ? null : AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodGroupBadge(bloodType: blood, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$hospital • $remaining/$requiredTotal unit(s) left',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PulseUrgencyBadge(urgency: urgency, compact: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVerifiedCase
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.surfaceMutedOf(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isVerifiedCase
                              ? 'Hospital Verified Case'
                              : 'Unverified Case',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isVerifiedCase
                                ? AppColors.success
                                : AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                      Text(
                        'Status: $status • Contact: $contact',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          child: const Text('Inspect'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RequestDetailsPage(requestId: reqId),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVerifiedCase
                                ? AppColors.high
                                : AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _handleVerifyHospitalCase(
                              reqId, patient, isVerifiedCase),
                          child: Text(
                            isVerifiedCase ? 'Revoke Seal' : 'Verify Case',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Cancel Fraudulent/Closed Request',
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.critical),
                          onPressed: () async {
                            await _requestService.cancelBloodRequest(
                              reqId,
                              reason: 'Closed by moderation staff',
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Desk 3: Staff & Users Directory ---
  Widget _buildStaffUsersDirectory({required bool isSuperAdmin}) {
    final isDark = AppColors.isDark(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone, or blood group...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _userSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () =>
                              setState(() => _userSearchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (val) =>
                    setState(() => _userSearchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _roleFilterChip('all', 'All Accounts'),
                    const SizedBox(width: 6),
                    _roleFilterChip('moderator', 'Moderators'),
                    const SizedBox(width: 6),
                    _roleFilterChip('admin', 'Admins'),
                    const SizedBox(width: 6),
                    _roleFilterChip('banned', 'Suspended'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _profilesStream ?? const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data ?? [];

              if (_userSearchQuery.isNotEmpty) {
                users = users.where((u) {
                  final name = (u['name'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  final blood =
                      (u['blood_type'] ?? '').toString().toLowerCase();
                  final phone =
                      (u['phone_number'] ?? '').toString().toLowerCase();
                  return name.contains(_userSearchQuery) ||
                      email.contains(_userSearchQuery) ||
                      blood.contains(_userSearchQuery) ||
                      phone.contains(_userSearchQuery);
                }).toList();
              }

              if (_userRoleFilter == 'moderator') {
                users = users
                    .where((u) =>
                        (u['role']?.toString().toLowerCase()) == 'moderator')
                    .toList();
              } else if (_userRoleFilter == 'admin') {
                users = users
                    .where(
                        (u) => (u['role']?.toString().toLowerCase()) == 'admin')
                    .toList();
              } else if (_userRoleFilter == 'banned') {
                users = users.where((u) => u['is_banned'] == true).toList();
              }

              if (users.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.person_search_rounded,
                  title: 'No Matching Users',
                  message: 'Try adjusting your search query or filter chip.',
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  final userId = u['id']?.toString() ?? '';
                  final name = (u['name'] ?? 'Community Member').toString();
                  final email = (u['email'] ?? 'No email').toString();
                  final role = (u['role'] ?? 'user').toString().toLowerCase();
                  final isBanned = u['is_banned'] == true;
                  final blood = (u['blood_type'] ?? '?').toString();
                  final isVerified = u['is_verified_donor'] == true;
                  final bool canBanTarget = isSuperAdmin || role != 'admin';

                  Color roleBadgeColor = AppColors.textSecondary;
                  if (role == 'admin') roleBadgeColor = AppColors.primary;
                  if (role == 'moderator') {
                    roleBadgeColor = AppColors.imperialGold;
                  }
                  if (isBanned) roleBadgeColor = AppColors.critical;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isBanned
                            ? AppColors.critical.withValues(alpha: 0.4)
                            : AppColors.borderOf(context),
                      ),
                      boxShadow: isDark ? null : AppColors.softShadow,
                    ),
                    child: ListTile(
                      leading: BloodGroupBadge(
                          bloodType: blood.isEmpty ? '?' : blood, size: 40),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                color: AppColors.success, size: 16),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isBanned ? 'SUSPENDED' : role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: roleBadgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (action) {
                          if (action == 'copy_id') {
                            Clipboard.setData(ClipboardData(text: userId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('User ID copied to clipboard')),
                            );
                          } else if (action == 'promote_mod') {
                            _handleRoleChange(userId, name, 'moderator');
                          } else if (action == 'demote_user') {
                            _handleRoleChange(userId, name, 'user');
                          } else if (action == 'promote_admin') {
                            _handleRoleChange(userId, name, 'admin');
                          } else if (action == 'toggle_ban') {
                            _handleBanUser(userId, name, isBanned);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'copy_id',
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Copy User UUID'),
                              ],
                            ),
                          ),
                          if (isSuperAdmin && role != 'moderator')
                            const PopupMenuItem(
                              value: 'promote_mod',
                              child: Row(
                                children: [
                                  Icon(Icons.shield_rounded,
                                      color: AppColors.imperialGold, size: 18),
                                  SizedBox(width: 8),
                                  Text('Promote to Moderator'),
                                ],
                              ),
                            ),
                          if (isSuperAdmin && role != 'user')
                            const PopupMenuItem(
                              value: 'demote_user',
                              child: Row(
                                children: [
                                  Icon(Icons.person_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Set as Regular Donor'),
                                ],
                              ),
                            ),
                          if (isSuperAdmin && role != 'admin')
                            const PopupMenuItem(
                              value: 'promote_admin',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded,
                                      color: AppColors.primary, size: 18),
                                  SizedBox(width: 8),
                                  Text('Promote to Admin'),
                                ],
                              ),
                            ),
                          if (canBanTarget) ...[
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'toggle_ban',
                              child: Row(
                                children: [
                                  Icon(
                                    isBanned
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.block_rounded,
                                    color: isBanned
                                        ? AppColors.success
                                        : AppColors.critical,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isBanned
                                        ? 'Restore Account'
                                        : 'Suspend User',
                                    style: TextStyle(
                                      color: isBanned
                                          ? AppColors.success
                                          : AppColors.critical,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roleFilterChip(String value, String label) {
    final isSelected = _userRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _userRoleFilter = value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardBg(context),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textPrimaryOf(context),
      ),
    );
  }

  // --- Desk 4: Facilities, Broadcasts, Learn CMS, & Audit Logs ---
  Widget _buildOperationsAndBroadcastsDesk() {
    final subTabs = ['Facilities', 'Broadcasts', 'Learn CMS', 'Audit Logs'];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: List.generate(subTabs.length, (i) {
              final selected = _opsSubTabIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(subTabs[i]),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.cardBg(context),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.textPrimaryOf(context),
                  ),
                  onSelected: (_) => setState(() => _opsSubTabIndex = i),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _opsSubTabIndex,
            children: [
              _buildFacilitiesAndExportManager(),
              _buildBroadcastCenter(),
              _buildLearnCmsManager(),
              _buildAuditLogsViewer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBroadcastCenter() {
    final isDark = AppColors.isDark(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primaryAccent.withValues(alpha: 0.3)),
              boxShadow: isDark ? null : AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Alert & Direct Dispatcher',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Segment Broadcast')),
                        selected: _broadcastTargetMode == 'broadcast',
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _broadcastTargetMode == 'broadcast'
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                        ),
                        onSelected: (_) =>
                            setState(() => _broadcastTargetMode = 'broadcast'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Single User')),
                        selected: _broadcastTargetMode == 'direct',
                        selectedColor: AppColors.secondary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _broadcastTargetMode == 'direct'
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                        ),
                        onSelected: (_) =>
                            setState(() => _broadcastTargetMode = 'direct'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_broadcastTargetMode == 'direct') ...[
                  TextField(
                    controller: _directUserIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Target User UUID *',
                      hintText: 'Paste from Directory -> Copy User UUID',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _broadcastTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alert Headline *',
                    hintText: 'e.g. Critical O- Shortage at Central Blood Bank',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _broadcastMsgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message Details *',
                    hintText:
                        'Eligible donors please coordinate via RedCellNet.',
                  ),
                ),
                const SizedBox(height: 12),
                if (_broadcastTargetMode == 'broadcast') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBroadcastBlood,
                          decoration: const InputDecoration(
                              labelText: 'Target Blood Group'),
                          items: const [
                            DropdownMenuItem(
                                value: 'ALL', child: Text('All Donors')),
                            DropdownMenuItem(value: 'O-', child: Text('O-')),
                            DropdownMenuItem(value: 'O+', child: Text('O+')),
                            DropdownMenuItem(value: 'A-', child: Text('A-')),
                            DropdownMenuItem(value: 'A+', child: Text('A+')),
                            DropdownMenuItem(value: 'B-', child: Text('B-')),
                            DropdownMenuItem(value: 'B+', child: Text('B+')),
                            DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                            DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBroadcastBlood = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _broadcastCityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City Filter',
                            hintText: 'Optional (e.g. Dhaka)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBroadcastType,
                          decoration:
                              const InputDecoration(labelText: 'Bulletin Type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'shortage', child: Text('Shortage')),
                            DropdownMenuItem(
                                value: 'urgent_campaign',
                                child: Text('Campaign')),
                            DropdownMenuItem(
                                value: 'system_notice', child: Text('System')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBroadcastType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBroadcastDuration,
                          decoration:
                              const InputDecoration(labelText: 'Duration'),
                          items: const [
                            DropdownMenuItem(value: '1h', child: Text('1 Hour')),
                            DropdownMenuItem(
                                value: '6h', child: Text('6 Hours')),
                            DropdownMenuItem(
                                value: '24h', child: Text('24 Hours')),
                            DropdownMenuItem(value: '3d', child: Text('3 Days')),
                            DropdownMenuItem(value: '7d', child: Text('7 Days')),
                            DropdownMenuItem(
                                value: 'indefinite',
                                child: Text('No Expiry')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBroadcastDuration = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                GradientActionButton(
                  label: _broadcastTargetMode == 'direct'
                      ? 'Send Direct Notification'
                      : 'Dispatch Emergency Push Alert',
                  icon: Icons.send_rounded,
                  gradient: AppColors.emergencyGradient,
                  isLoading: _isBroadcasting,
                  onPressed: _dispatchEmergencyBroadcast,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent System Broadcasts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _broadcastsStream ?? const Stream.empty(),
            builder: (context, snapshot) {
              final broadcasts = snapshot.data ?? [];
              if (broadcasts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Center(
                    child: Text(
                      'No previous emergency alerts recorded.',
                      style:
                          TextStyle(color: AppColors.textSecondaryOf(context)),
                    ),
                  ),
                );
              }

              return Column(
                children: broadcasts.map((b) {
                  final id = b['id']?.toString() ?? '';
                  final title = (b['title'] ?? 'Emergency Notice').toString();
                  final msg = (b['message'] ?? '').toString();
                  final target =
                      (b['target_blood_type'] ?? 'All Blood Groups').toString();
                  final city =
                      (b['target_city'] ?? 'All Locations').toString();
                  final bool isActive = b['is_active'] == true;
                  final expDate = b['expires_at'] != null
                      ? DateTime.tryParse(b['expires_at'].toString())
                      : null;
                  final bool isExpired =
                      expDate != null && DateTime.now().isAfter(expDate);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                target,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(msg,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context))),
                        const SizedBox(height: 6),
                        Text(
                          'City: $city • ${isExpired ? "Expired" : (isActive ? "Active Banner" : "Inactive")}',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMutedOf(context)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showEditBroadcastDialog(b),
                            ),
                            IconButton(
                              icon: Icon(
                                isActive
                                    ? Icons.toggle_on_rounded
                                    : Icons.toggle_off_rounded,
                                size: 24,
                                color: isActive
                                    ? AppColors.success
                                    : AppColors.textMutedOf(context),
                              ),
                              onPressed: () async {
                                await _profileService.updateEmergencyBroadcast(
                                  id: id,
                                  title: title,
                                  message: msg,
                                  targetBloodType: b['target_blood_type'],
                                  targetCity: b['target_city'],
                                  isActive: !isActive,
                                  expiresAt: expDate,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.critical),
                              onPressed: () async {
                                await _profileService
                                    .deleteEmergencyBroadcast(id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesAndExportManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('Export CSV',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: _exportDataToCsv,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Add Facility',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showFacilityDialog(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<DonationCenter>>(
            stream: _centersStream ?? const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final centers = snapshot.data ?? [];
              if (centers.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.local_hospital_outlined,
                  title: 'No Facilities Recorded',
                  message:
                      'Tap "+ Add Facility" to register certified blood banks.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: centers.length,
                itemBuilder: (context, index) {
                  final c = centers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital_rounded,
                              color: AppColors.secondary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                  ),
                                  if (c.isVerified)
                                    const Icon(Icons.verified_rounded,
                                        size: 15, color: AppColors.success),
                                ],
                              ),
                              Text(
                                '${c.facilityType} • ${c.operationalStatus}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                c.address,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryOf(context)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _showFacilityDialog(existing: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.critical, size: 19),
                          onPressed: () async {
                            await _centerService.deleteCenter(c.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLearnCmsManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.post_add_rounded, size: 18),
              label: const Text('Publish Bilingual Health Guide'),
              onPressed: () => _showContentEditorDialog(),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ContentItem>>(
            stream: _contentStream ?? const Stream.empty(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.menu_book_rounded,
                  title: 'No Educational Guides',
                  message: 'Create bilingual health guides for community donors.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.titleEn,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              Text(
                                '${item.category} • ${item.readTimeMinutes} min read',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () =>
                              _showContentEditorDialog(existing: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 19, color: AppColors.critical),
                          onPressed: () async {
                            await _contentService.deleteContentItem(item.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogsViewer() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _auditLogsStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const EmptyStateView(
            icon: Icons.fact_check_outlined,
            title: 'No Audit Entries Yet',
            message:
                'Every verification, role change, suspension, report resolution, and broadcast is logged here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final action = (log['action_type'] ?? 'staff_action').toString();
            final targetType = (log['target_type'] ?? '').toString();
            final actor = (log['actor_name'] ?? 'Staff').toString();
            final role = (log['actor_role'] ?? 'staff').toString();
            final created = log['created_at'] != null
                ? DateTime.tryParse(log['created_at'].toString())
                : null;
            final timeStr = created != null
                ? DateFormat('MMM d, h:mm a').format(created.toLocal())
                : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_edu_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${action.replaceAll('_', ' ').toUpperCase()} ($targetType)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        Text(
                          'By $actor (${role.toUpperCase()}) • $timeStr',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
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

  Widget _buildStaffKpiCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: isDark ? null : AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.textSecondaryOf(context)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryOf(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
