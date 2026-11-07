// lib/features/home/presentation/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/push_notification_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/requests_page.dart';
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_list_page.dart';
import 'package:red_cell_net_final/features/nearby_map/presentation/pages/map_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/profile_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};

  void _onItemTapped(int index) {
    if (_selectedIndex == index && _visitedTabs.contains(index)) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  Widget _buildTabAt(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return HomeContent(onNavigate: _onItemTapped);
      case 1:
        return const RequestsPage();
      case 2:
        return const MapPage();
      case 3:
        return const ProfilePage();
      case 4:
        return const EducationalContentListPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final settings = AppSettingsService();

    return ValueListenableBuilder<String>(
      valueListenable: settings.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: List<Widget>.generate(5, _buildTabAt),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              border: Border(
                top: BorderSide(color: AppColors.borderOf(context), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
                    _buildNavItem(
                      0,
                      Icons.home_rounded,
                      Icons.home_outlined,
                      settings.tr('Home'),
                    ),
                    _buildNavItem(
                      1,
                      Icons.bloodtype_rounded,
                      Icons.bloodtype_outlined,
                      settings.tr('Requests'),
                    ),
                    _buildNavItem(
                      2,
                      Icons.map_rounded,
                      Icons.map_outlined,
                      settings.tr('Nearby'),
                    ),
                    _buildNavItem(
                      3,
                      Icons.person_rounded,
                      Icons.person_outline_rounded,
                      settings.tr('Profile'),
                    ),
                    _buildNavItem(
                      4,
                      Icons.school_rounded,
                      Icons.school_outlined,
                      settings.tr('Learn'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final bool isSelected = _selectedIndex == index;
    final isDark = AppColors.isDark(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
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
                  fontSize: 10.5,
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
}

// --- HomeContent Widget ---
class HomeContent extends StatefulWidget {
  final Function(int) onNavigate;
  const HomeContent({super.key, required this.onNavigate});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final UserProfileService _profileService = UserProfileService();
  final RequestService _requestService = RequestService();

  Stream<ProfileSnapshot>? _profileStream;
  Stream<AppQuerySnapshot>? _urgentRequestsStream;
  Stream<List<Map<String, dynamic>>>? _broadcastStream;

  String? _selectedBloodFilter;
  bool _isTogglingAvailability = false;
  final Set<String> _dismissedBroadcastIds = {};
  StreamSubscription<ProfileSnapshot>? _pushProfileSub;
  bool _syncedBookmarksFromProfile = false;

  String? _cachedUserBloodType;
  String? _cachedUserCity;

  final List<String> _bloodGroups = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadDismissedBroadcasts();
    _initStreams();
    unawaited(_requestService.checkAndExpireRequests());
  }

  Future<void> _loadDismissedBroadcasts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('dismissed_broadcast_ids') ?? [];
      if (mounted && saved.isNotEmpty) {
        setState(() {
          _dismissedBroadcastIds.addAll(saved);
        });
      }
    } catch (e) {
      debugPrint('Error loading dismissed broadcasts: $e');
    }
  }

  Future<void> _dismissBroadcast(String broadcastId) async {
    setState(() {
      _dismissedBroadcastIds.add(broadcastId);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'dismissed_broadcast_ids',
        _dismissedBroadcastIds.toList(),
      );
    } catch (e) {
      debugPrint('Error saving dismissed broadcasts: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert banner dismissed.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isBroadcastActive(Map<String, dynamic> r) {
    if (r['is_active'] == false) return false;
    final expStr = r['expires_at'];
    if (expStr != null && expStr.toString().isNotEmpty) {
      final exp = DateTime.tryParse(expStr.toString());
      if (exp != null && DateTime.now().toUtc().isAfter(exp.toUtc())) {
        return false;
      }
    }
    return true;
  }

  bool _matchesUserAudience(Map<String, dynamic> b) {
    if (!_isBroadcastActive(b)) return false;

    final String targetBlood =
        (b['target_blood_type'] ?? '').toString().trim().toUpperCase();
    if (targetBlood.isNotEmpty && targetBlood != 'ALL') {
      final userBlood =
          BloodCompatibility.normalizeBloodGroup(_cachedUserBloodType);
      if (userBlood != null) {
        final compatible = userBlood == targetBlood ||
            BloodCompatibility.isCompatible(
              donorBloodType: userBlood,
              recipientBloodType: targetBlood,
            );
        if (!compatible) return false;
      }
    }

    final String targetCity =
        (b['target_city'] ?? '').toString().trim().toLowerCase();
    if (targetCity.isNotEmpty && targetCity != 'all') {
      final String userCity = (_cachedUserCity ?? '').trim().toLowerCase();
      if (userCity.isNotEmpty &&
          !userCity.contains(targetCity) &&
          !targetCity.contains(userCity)) {
        return false;
      }
    }

    return true;
  }

  String _formatRemainingTime(String expiresAtStr) {
    final exp = DateTime.tryParse(expiresAtStr);
    if (exp == null) return '';
    final diff = exp.toLocal().difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) {
      return 'Ends in ${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      return 'Ends in ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return 'Ends in ${diff.inMinutes}m';
    }
  }

  @override
  void dispose() {
    _pushProfileSub?.cancel();
    super.dispose();
  }

  void _initStreams() {
    final uid = SupabaseAuthService().currentUserId;
    if (uid != null && uid.isNotEmpty) {
      _profileStream = _profileService.getUserProfileStream(uid);

      _pushProfileSub?.cancel();
      _pushProfileSub = _profileStream?.listen((snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        final String? blood =
            (data['bloodType'] ?? data['blood_type'])?.toString();
        final String? city =
            (data['locationCity'] ?? data['location_city'])?.toString();
        final DateTime? pausedUntil = AppTimestamp.tryFromValue(
          data['notificationsPausedUntil'] ??
              data['notifications_paused_until'],
        )?.toDate();
        final Map<String, dynamic>? notifPrefs =
            data['notificationPreferences'] is Map
                ? Map<String, dynamic>.from(
                    data['notificationPreferences'] as Map,
                  )
                : (data['notification_preferences'] is Map
                    ? Map<String, dynamic>.from(
                        data['notification_preferences'] as Map,
                      )
                    : null);

        if (!_syncedBookmarksFromProfile) {
          final rawBookmarks =
              data['bookmarkedRequestIds'] ?? data['bookmarked_request_ids'];
          if (rawBookmarks is List && rawBookmarks.isNotEmpty) {
            AppSettingsService().syncBookmarkedRequests(
              rawBookmarks.map((e) => e.toString()),
            );
            _syncedBookmarksFromProfile = true;
          }
        }

        if (mounted &&
            (_cachedUserBloodType != blood || _cachedUserCity != city)) {
          setState(() {
            _cachedUserBloodType = blood;
            _cachedUserCity = city;
          });
        } else {
          _cachedUserBloodType = blood;
          _cachedUserCity = city;
        }

        PushNotificationService().startRealtimeAlertListeners(
          currentUserId: uid,
          userBloodType: blood,
          userCity: city,
          notificationsPausedUntil: pausedUntil,
          notificationPreferences: notifPrefs,
        );
      });
    } else {
      _profileStream = const Stream.empty();
    }
    _urgentRequestsStream = _requestService.getUrgentRequestsStream(limit: 6);
    _broadcastStream = _createBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> _createBroadcastStream() async* {
    if (!SupabaseConfig.isInitialized) return;

    try {
      final initial = await supabase
          .from('system_broadcasts')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(10);
      final list = List<Map<String, dynamic>>.from(initial as List);
      yield list.where(_isBroadcastActive).toList();
    } catch (e) {
      debugPrint('Initial broadcast REST notice: $e');
    }

    try {
      final stream = supabase
          .from('system_broadcasts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(10);

      await for (final rows in stream) {
        yield rows.where(_isBroadcastActive).toList();
      }
    } catch (e) {
      debugPrint('Realtime broadcast stream notice: $e');
    }
  }

  String _getTimeGreeting() {
    final isBn = AppSettingsService().isBengali;
    final hour = DateTime.now().hour;
    if (hour < 12) return isBn ? 'শুভ সকাল' : 'Good Morning';
    if (hour < 17) return isBn ? 'শুভ অপরাহ্ন' : 'Good Afternoon';
    return isBn ? 'শুভ সন্ধ্যা' : 'Good Evening';
  }

  Future<void> _toggleAvailability(
    String uid,
    bool currentStatus, {
    required DonorEligibilityResult eligibility,
  }) async {
    if (_isTogglingAvailability) return;

    if (!currentStatus && !eligibility.isEligible) {
      final nextFmt = eligibility.nextEligibleDate != null
          ? DateFormat.yMMMd().format(eligibility.nextEligibleDate!.toLocal())
          : 'after recovery';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Medical safety cooldown active (${eligibility.daysRemaining} day(s) left). Eligible again on $nextFmt.',
          ),
          backgroundColor: AppColors.warningDark,
        ),
      );
      return;
    }

    setState(() => _isTogglingAvailability = true);
    final bool newStatus = !currentStatus;
    try {
      await _profileService.updateUserProfile(uid, {
        'isAvailableToDonate': newStatus,
        'availabilityStatus': newStatus ? 'available' : 'unavailable',
        if (newStatus) 'availableFrom': null,
        if (newStatus) 'availableUntil': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Ready to donate! You are visible for compatible urgent requests.'
                  : 'You are now marked as off-duty.',
            ),
            backgroundColor:
                newStatus ? AppColors.success : AppColors.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  Future<void> _applyAvailabilitySchedule(
    String uid,
    Map<String, dynamic> updates,
    String confirmationMessage,
  ) async {
    if (_isTogglingAvailability) return;
    setState(() => _isTogglingAvailability = true);
    try {
      await _profileService.updateUserProfile(uid, updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(confirmationMessage),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save schedule: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  void _showAvailabilityScheduleSheet({
    required String uid,
    required bool isAvailable,
    required String availabilityStatus,
    required DonorEligibilityResult eligibility,
    DateTime? availableFrom,
    DateTime? availableUntil,
    DateTime? notificationsPausedUntil,
  }) {
    final bool alertsPaused = notificationsPausedUntil != null &&
        notificationsPausedUntil.isAfter(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final isDark = AppColors.isDark(sheetContext);
        final settings = AppSettingsService();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        settings.tr('Schedule Availability'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(sheetContext),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                Text(
                  'Configure your donor availability window and alert preferences.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondaryOf(sheetContext),
                  ),
                ),
                const SizedBox(height: 14),
                if (!eligibility.isEligible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF78350F).withValues(alpha: 0.35)
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.health_and_safety_rounded,
                          color: AppColors.warningDark,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${eligibility.statusMessage}. Whole-blood recovery interval cannot be overridden early.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : AppColors.warningDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: eligibility.isEligible,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  title: Text(
                    settings.tr('Available Now'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: eligibility.isEligible
                          ? AppColors.textPrimaryOf(sheetContext)
                          : AppColors.textMutedOf(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    eligibility.isEligible
                        ? 'Receive compatible urgent blood requests immediately'
                        : 'Locked until 90-day recovery window completes',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(sheetContext),
                    ),
                  ),
                  trailing: isAvailable && eligibility.isEligible
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        )
                      : null,
                  onTap: !eligibility.isEligible
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          await _applyAvailabilitySchedule(
                            uid,
                            {
                              'isAvailableToDonate': true,
                              'availabilityStatus': 'available',
                              'availableFrom': null,
                              'availableUntil': null,
                            },
                            'Status updated: Available to donate now.',
                          );
                        },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.snooze_rounded,
                      color: AppColors.warningDark,
                    ),
                  ),
                  title: Text(
                    settings.tr('Snooze 24 Hours'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    'Temporarily pause donor matching for 24 hours',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(sheetContext),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final until =
                        DateTime.now().toUtc().add(const Duration(hours: 24));
                    await _applyAvailabilitySchedule(
                      uid,
                      {
                        'isAvailableToDonate': false,
                        'availabilityStatus': 'temporarily_unavailable',
                        'availableUntil': until.toIso8601String(),
                      },
                      'Snoozed donor availability for 24 hours.',
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.timelapse_rounded,
                      color: AppColors.warningDark,
                    ),
                  ),
                  title: Text(
                    settings.tr('Snooze 72 Hours'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    'Temporarily pause donor matching for 3 days (travel / exams)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(sheetContext),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final until =
                        DateTime.now().toUtc().add(const Duration(hours: 72));
                    await _applyAvailabilitySchedule(
                      uid,
                      {
                        'isAvailableToDonate': false,
                        'availabilityStatus': 'temporarily_unavailable',
                        'availableUntil': until.toIso8601String(),
                      },
                      'Snoozed donor availability for 72 hours.',
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: eligibility.isEligible,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.secondary.withValues(alpha: 0.2)
                          : AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                  title: Text(
                    'Scheduled Availability Window',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: eligibility.isEligible
                          ? AppColors.textPrimaryOf(sheetContext)
                          : AppColors.textMutedOf(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    availabilityStatus == 'scheduled' &&
                            availableFrom != null &&
                            availableUntil != null
                        ? 'Active window: ${DateFormat.MMMd().format(availableFrom.toLocal())} – ${DateFormat.MMMd().format(availableUntil.toLocal())}'
                        : 'Select specific dates when you are available to donate',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(sheetContext),
                    ),
                  ),
                  onTap: !eligibility.isEligible
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year, now.month, now.day),
                            lastDate: now.add(const Duration(days: 180)),
                            initialDateRange: availableFrom != null &&
                                    availableUntil != null &&
                                    availableUntil.isAfter(now)
                                ? DateTimeRange(
                                    start: availableFrom.toLocal(),
                                    end: availableUntil.toLocal(),
                                  )
                                : DateTimeRange(
                                    start: now,
                                    end: now.add(const Duration(days: 7)),
                                  ),
                          );
                          if (picked == null) return;
                          final startUtc = picked.start.toUtc();
                          final endUtc = DateTime(
                            picked.end.year,
                            picked.end.month,
                            picked.end.day,
                            23,
                            59,
                          ).toUtc();
                          final bool activeRightNow =
                              !DateTime.now().toUtc().isBefore(startUtc) &&
                                  !DateTime.now().toUtc().isAfter(endUtc);
                          await _applyAvailabilitySchedule(
                            uid,
                            {
                              'isAvailableToDonate': activeRightNow,
                              'availabilityStatus': 'scheduled',
                              'availableFrom': startUtc.toIso8601String(),
                              'availableUntil': endUtc.toIso8601String(),
                            },
                            'Availability scheduled (${DateFormat.MMMd().format(picked.start)} – ${DateFormat.MMMd().format(picked.end)}).',
                          );
                        },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mutedOf(sheetContext),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      alertsPaused
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_paused_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    alertsPaused
                        ? 'Resume Push Alerts Now'
                        : settings.tr('Pause Alerts 24h'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    alertsPaused
                        ? 'Paused until ${DateFormat.jm().format(notificationsPausedUntil.toLocal())}'
                        : 'Mute push notifications for 24 hours without deleting preferences',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(sheetContext),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final nextPause = alertsPaused
                        ? null
                        : DateTime.now()
                            .toUtc()
                            .add(const Duration(hours: 24))
                            .toIso8601String();
                    await _applyAvailabilitySchedule(
                      uid,
                      {'notificationsPausedUntil': nextPause},
                      alertsPaused
                          ? 'Push alerts resumed.'
                          : 'Push alerts muted for 24 hours.',
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mutedOf(sheetContext),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bedtime_rounded,
                      color: AppColors.textMutedOf(sheetContext),
                    ),
                  ),
                  title: Text(
                    'Off-Duty (Inactive)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    'Turn off donor matching until you re-enable it',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(sheetContext),
                    ),
                  ),
                  trailing: !isAvailable && availabilityStatus == 'unavailable'
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.textSecondaryOf(sheetContext),
                        )
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _applyAvailabilitySchedule(
                      uid,
                      {
                        'isAvailableToDonate': false,
                        'availabilityStatus': 'unavailable',
                        'availableFrom': null,
                        'availableUntil': null,
                      },
                      'Marked as off-duty.',
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          BloodCompatibility.preliminaryTriageDisclaimer,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(sheetContext),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompatibilityBottomSheet(String defaultType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _BloodCompatibilityExplorerSheet(initialBloodType: defaultType);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = SupabaseAuthService().currentUserId;
    final isDark = AppColors.isDark(context);
    final settings = AppSettingsService();

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _requestService.checkAndExpireRequests();
            if (mounted) {
              setState(() {
                _initStreams();
              });
            }
          },
          color: AppColors.primary,
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // --- Live Admin & System Broadcast Alert Banner ---
              if (_broadcastStream != null)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _broadcastStream,
                  builder: (context, bSnap) {
                    if (!bSnap.hasData || bSnap.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final activeBroadcasts = bSnap.data!
                        .where((b) =>
                            !_dismissedBroadcastIds
                                .contains(b['id']?.toString()) &&
                            _matchesUserAudience(b))
                        .toList();
                    if (activeBroadcasts.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final broadcast = activeBroadcasts.first;
                    final broadcastId = broadcast['id']?.toString() ?? '';
                    final title =
                        broadcast['title'] ?? 'Emergency Notification';
                    final message = broadcast['message'] ?? '';
                    final targetBlood = broadcast['target_blood_type'];
                    final targetCity = broadcast['target_city'];
                    final expiresAt = broadcast['expires_at'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF881337), Color(0xFF4C0519)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFB7185).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE11D48).withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (targetBlood != null &&
                                            targetBlood.toString().isNotEmpty &&
                                            targetBlood != 'ALL') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              targetBlood.toString(),
                                              style: const TextStyle(
                                                color: Color(0xFF881337),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      message.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                tooltip: 'Dismiss Alert',
                                onPressed: () => _dismissBroadcast(broadcastId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (targetCity != null &&
                                  targetCity.toString().isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.white70,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        targetCity.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (expiresAt != null &&
                                  expiresAt.toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        color: Colors.amberAccent,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatRemainingTime(
                                          expiresAt.toString(),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF881337),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Respond',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onPressed: () => widget.onNavigate(1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // --- Header Bar, Availability & Clinical Stats ---
              StreamBuilder<ProfileSnapshot>(
                stream: _profileStream ?? const Stream.empty(),
                builder: (context, snapshot) {
                  String name = '';
                  String bloodType = '';
                  bool rawAvailable = false;
                  String availabilityStatus = 'unavailable';
                  int totalDonations = 0;
                  String role = 'user';
                  int cooldownDays = 90;
                  DateTime? lastDonationDt;
                  DateTime? nextEligibleDt;
                  DateTime? availableFromDt;
                  DateTime? availableUntilDt;
                  DateTime? notificationsPausedUntilDt;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data();
                    name = (data?['name'] ?? '').toString();
                    bloodType =
                        (data?['bloodType'] ?? data?['blood_type'] ?? '')
                            .toString();
                    rawAvailable = data?['isAvailableToDonate'] == true;
                    availabilityStatus =
                        (data?['availabilityStatus'] ?? 'unavailable')
                            .toString();
                    totalDonations = (data?['totalDonations'] is num)
                        ? (data!['totalDonations'] as num).toInt()
                        : 0;
                    role = (data?['role'] ?? 'user').toString().toLowerCase();
                    cooldownDays = (data?['cooldownDays'] is num)
                        ? (data!['cooldownDays'] as num).toInt()
                        : 90;
                    lastDonationDt = AppTimestamp.tryFromValue(
                      data?['lastDonationDate'] ?? data?['last_donation_date'],
                    )?.toDate();
                    nextEligibleDt = AppTimestamp.tryFromValue(
                      data?['nextEligibleDate'] ?? data?['next_eligible_date'],
                    )?.toDate();
                    availableFromDt = AppTimestamp.tryFromValue(
                      data?['availableFrom'] ?? data?['available_from'],
                    )?.toDate();
                    availableUntilDt = AppTimestamp.tryFromValue(
                      data?['availableUntil'] ?? data?['available_until'],
                    )?.toDate();
                    notificationsPausedUntilDt = AppTimestamp.tryFromValue(
                      data?['notificationsPausedUntil'] ??
                          data?['notifications_paused_until'],
                    )?.toDate();
                  }

                  final eligibility = BloodCompatibility.checkEligibility(
                    lastDonationDate: lastDonationDt,
                    nextEligibleDate: nextEligibleDt,
                    cooldownDays: cooldownDays,
                  );

                  final bool isSnoozed =
                      availabilityStatus == 'temporarily_unavailable' &&
                          availableUntilDt != null &&
                          availableUntilDt.isAfter(DateTime.now());

                  final bool isAvailable =
                      rawAvailable && eligibility.isEligible && !isSnoozed;

                  final currentUserEmail =
                      SupabaseAuthService().currentUserEmail;
                  final currentUserName =
                      SupabaseAuthService().currentUser?.userMetadata?['name'];

                  final displayName = name.isNotEmpty
                      ? name
                      : (currentUserName != null &&
                              currentUserName.toString().isNotEmpty)
                          ? currentUserName.toString()
                          : (currentUserEmail?.split('@').first ?? 'Donor');

                  final bool isStaff = role == 'admin' || role == 'moderator';

                  String statusHeadline;
                  String statusSubline;
                  if (!eligibility.isEligible) {
                    statusHeadline = settings.tr('Recovery Cooldown Active');
                    statusSubline = eligibility.statusMessage;
                  } else if (isSnoozed) {
                    statusHeadline = 'Snoozed Temporarily';
                    statusSubline =
                        'Until ${DateFormat.MMMd().add_jm().format(availableUntilDt.toLocal())}';
                  } else if (isAvailable) {
                    statusHeadline = settings.tr('Available to Donate');
                    statusSubline = 'Tap to schedule or pause alerts';
                  } else {
                    statusHeadline = settings.tr('Currently Unavailable');
                    statusSubline = 'Turn on when you are ready to donate';
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _getTimeGreeting(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondaryOf(
                                              context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isStaff) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => settings
                                            .setStaffWorkspaceMode('admin'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .admin_panel_settings_rounded,
                                                size: 12,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                settings.tr('Admin Console'),
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimaryOf(context),
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  color: isDark
                                      ? Colors.amber
                                      : AppColors.textPrimaryOf(context),
                                  size: 22,
                                ),
                                tooltip: isDark
                                    ? 'Switch to Light Mode'
                                    : 'Switch to Dark Mode',
                                onPressed: () => settings.toggleTheme(),
                              ),
                              const NotificationBellAction(),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => widget.onNavigate(3),
                                child: bloodType.isNotEmpty
                                    ? BloodGroupBadge(
                                        bloodType: bloodType,
                                        size: 44,
                                        showGlow: true,
                                      )
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.2)
                                              : AppColors.primaryContainer,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? AppColors.primary
                                                : AppColors.primaryLight,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Availability Status & Schedule Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? (isDark
                                  ? const Color(0xFF064E3B)
                                      .withValues(alpha: 0.55)
                                  : const Color(0xFFF0FDF4))
                              : (!eligibility.isEligible
                                  ? (isDark
                                      ? const Color(0xFF78350F)
                                          .withValues(alpha: 0.28)
                                      : AppColors.warningLight
                                          .withValues(alpha: 0.6))
                                  : AppColors.cardBg(context)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAvailable
                                ? AppColors.success.withValues(alpha: 0.5)
                                : (!eligibility.isEligible
                                    ? AppColors.warning.withValues(alpha: 0.45)
                                    : AppColors.borderOf(context)),
                          ),
                          boxShadow: isDark ? [] : AppColors.softShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: currentUserId == null
                                    ? null
                                    : () => _showAvailabilityScheduleSheet(
                                          uid: currentUserId,
                                          isAvailable: isAvailable,
                                          availabilityStatus:
                                              availabilityStatus,
                                          eligibility: eligibility,
                                          availableFrom: availableFromDt,
                                          availableUntil: availableUntilDt,
                                          notificationsPausedUntil:
                                              notificationsPausedUntilDt,
                                        ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? (isDark
                                                ? AppColors.success
                                                    .withValues(alpha: 0.25)
                                                : AppColors.successLight)
                                            : (!eligibility.isEligible
                                                ? AppColors.warning
                                                    .withValues(alpha: 0.2)
                                                : AppColors.mutedOf(context)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isAvailable
                                            ? Icons.volunteer_activism_rounded
                                            : (!eligibility.isEligible
                                                ? Icons
                                                    .health_and_safety_rounded
                                                : Icons.bedtime_rounded),
                                        size: 18,
                                        color: isAvailable
                                            ? AppColors.success
                                            : (!eligibility.isEligible
                                                ? AppColors.warningDark
                                                : AppColors.textMutedOf(
                                                    context)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  statusHeadline,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: isAvailable
                                                        ? (isDark
                                                            ? const Color(
                                                                0xFF6EE7B7)
                                                            : const Color(
                                                                0xFF166534))
                                                        : AppColors
                                                            .textPrimaryOf(
                                                                context),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 12,
                                                color: isAvailable
                                                    ? (isDark
                                                        ? const Color(
                                                            0xFF6EE7B7)
                                                        : const Color(
                                                            0xFF166534))
                                                    : AppColors.textMutedOf(
                                                        context),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            statusSubline,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isAvailable
                                                  ? (isDark
                                                      ? const Color(0xFFA7F3D0)
                                                      : const Color(0xFF15803D))
                                                  : AppColors.textSecondaryOf(
                                                      context),
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
                            ),
                            const SizedBox(width: 4),
                            EligibilityCountdownRing(
                              daysRemaining: eligibility.daysRemaining,
                              bloodType: bloodType,
                              nextEligibleDate: eligibility.nextEligibleDate,
                              size: 42,
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 20),
                              color: isAvailable
                                  ? AppColors.success
                                  : AppColors.textSecondaryOf(context),
                              tooltip: 'Availability Schedule Options',
                              onPressed: currentUserId == null
                                  ? null
                                  : () => _showAvailabilityScheduleSheet(
                                        uid: currentUserId,
                                        isAvailable: isAvailable,
                                        availabilityStatus: availabilityStatus,
                                        eligibility: eligibility,
                                        availableFrom: availableFromDt,
                                        availableUntil: availableUntilDt,
                                        notificationsPausedUntil:
                                            notificationsPausedUntilDt,
                                      ),
                            ),
                            Switch(
                              value: isAvailable,
                              activeThumbColor: AppColors.success,
                              activeTrackColor: AppColors.successLight,
                              onChanged: currentUserId == null
                                  ? null
                                  : (_) => _toggleAvailability(
                                        currentUserId,
                                        isAvailable,
                                        eligibility: eligibility,
                                      ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Clinical Readiness & Donor Impact Row (Dark-Mode Safe)
                      Row(
                        children: [
                          Expanded(
                            child: StatMetricCard(
                              title: 'Donations',
                              value: '$totalDonations',
                              icon: Icons.water_drop_rounded,
                              iconColor: AppColors.primary,
                              bgColor: isDark
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : AppColors.primaryContainer,
                              onTap: () => widget.onNavigate(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatMetricCard(
                              title: 'Eligibility',
                              value: eligibility.isEligible
                                  ? 'Ready'
                                  : '${eligibility.daysRemaining}d',
                              icon: eligibility.isEligible
                                  ? Icons.verified_user_rounded
                                  : Icons.hourglass_top_rounded,
                              iconColor: eligibility.isEligible
                                  ? AppColors.success
                                  : AppColors.warningDark,
                              bgColor: eligibility.isEligible
                                  ? (isDark
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : AppColors.successLight)
                                  : (isDark
                                      ? AppColors.warning.withValues(alpha: 0.2)
                                      : AppColors.warningLight),
                              onTap: () => showDonorSelfTriageSheet(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatMetricCard(
                              title: settings.tr('Compatibility'),
                              value: bloodType.isNotEmpty ? bloodType : 'Guide',
                              icon: Icons.sync_alt_rounded,
                              iconColor: AppColors.secondary,
                              bgColor: isDark
                                  ? AppColors.secondary.withValues(alpha: 0.2)
                                  : AppColors.secondaryLight,
                              onTap: () =>
                                  _showCompatibilityBottomSheet(bloodType),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // --- Urgent Emergency Action Card (Create Blood Request) ---
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.glowPrimary,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateRequestPage(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.emergency_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        settings.tr('Post Blood Request'),
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'SOS',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Notify nearby compatible donors for verified hospital needs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Quick Blood Group Filter Chips ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Blood Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  if (_selectedBloodFilter != null &&
                      _selectedBloodFilter != 'All')
                    GestureDetector(
                      onTap: () => setState(() => _selectedBloodFilter = null),
                      child: const Text(
                        'Clear filter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if ((_cachedUserBloodType ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.verified_user_rounded,
                            size: 15,
                            color: _selectedBloodFilter == 'COMPATIBLE'
                                ? Colors.white
                                : AppColors.vitalEmerald,
                          ),
                          label: Text(settings.tr('Compatible with Me')),
                          selected: _selectedBloodFilter == 'COMPATIBLE',
                          selectedColor: AppColors.vitalEmerald,
                          backgroundColor: AppColors.cardBg(context),
                          labelStyle: TextStyle(
                            color: _selectedBloodFilter == 'COMPATIBLE'
                                ? Colors.white
                                : AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _selectedBloodFilter == 'COMPATIBLE'
                                  ? AppColors.vitalEmerald
                                  : AppColors.vitalEmerald.withValues(alpha: 0.4),
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedBloodFilter =
                                  _selectedBloodFilter == 'COMPATIBLE'
                                      ? null
                                      : 'COMPATIBLE';
                            });
                          },
                        ),
                      ),
                    ..._bloodGroups.map((group) {
                      final isSelected =
                          (_selectedBloodFilter == null && group == 'All') ||
                              _selectedBloodFilter == group;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label:
                              Text(group == 'All' ? settings.tr('All') : group),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.cardBg(context),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.borderOf(context),
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedBloodFilter =
                                  group == 'All' ? null : group;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Urgent Emergencies Feed ---
              SectionHeader(
                title: settings.tr('Emergency Feed'),
                subtitle: _selectedBloodFilter != null
                    ? 'Showing requests for $_selectedBloodFilter'
                    : 'Patients needing immediate assistance',
                actionLabel: settings.tr('See All'),
                icon: Icons.local_fire_department_rounded,
                onAction: () => widget.onNavigate(1),
              ),
              const SizedBox(height: 8),
              _buildUrgentRequestsSection(context),
              const SizedBox(height: 24),

              // --- Quick Services Grid ---
              const SectionHeader(
                title: 'Clinical Tools & Directory',
                subtitle: 'Verified centers, WHO self-triage & compatibility',
                icon: Icons.grid_view_rounded,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.map_rounded,
                      iconColor: AppColors.secondary,
                      bgColor: isDark
                          ? AppColors.secondary.withValues(alpha: 0.18)
                          : AppColors.secondaryLight,
                      title: 'Blood Centers Map',
                      subtitle: 'Hospitals & availability zones',
                      onTap: () => widget.onNavigate(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.checklist_rounded,
                      iconColor: const Color(0xFF10B981),
                      bgColor: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                          : const Color(0xFFECFDF5),
                      title: settings.tr('60s Self-Triage'),
                      subtitle: 'WHO donor readiness check',
                      onTap: () => showDonorSelfTriageSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.sync_alt_rounded,
                      iconColor: AppColors.primary,
                      bgColor: isDark
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.primaryContainer,
                      title: settings.tr('Compatibility'),
                      subtitle: 'RBC, Platelets & Plasma',
                      onTap: () => _showCompatibilityBottomSheet(
                        _cachedUserBloodType ?? '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.school_rounded,
                      iconColor: const Color(0xFF059669),
                      bgColor: isDark
                          ? const Color(0xFF059669).withValues(alpha: 0.18)
                          : const Color(0xFFD1FAE5),
                      title: settings.tr('Learn'),
                      subtitle: 'Medical guides & preparation',
                      onTap: () => widget.onNavigate(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.emoji_events_rounded,
                      iconColor: AppColors.imperialGold,
                      bgColor: isDark
                          ? AppColors.imperialGold.withValues(alpha: 0.18)
                          : AppColors.goldLight,
                      title: settings.tr('Top Heroes'),
                      subtitle: 'City & national lifesavers',
                      onTap: () => showCommunityLeaderboardSheet(
                        context,
                        userCity: _cachedUserCity,
                        referralCode: AppSettingsService.generateReferralCode(
                          userId: currentUserId,
                          bloodGroup: _cachedUserBloodType,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.event_available_rounded,
                      iconColor: AppColors.accent,
                      bgColor: isDark
                          ? AppColors.accent.withValues(alpha: 0.18)
                          : AppColors.accentLight,
                      title: settings.tr('Blood Camps'),
                      subtitle: 'Drives & .ics calendar sync',
                      onTap: () => showBloodCampCalendarSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildServiceTile(
                icon: Icons.monitor_heart_rounded,
                iconColor: AppColors.secondary,
                bgColor: isDark
                    ? AppColors.secondary.withValues(alpha: 0.18)
                    : AppColors.secondaryLight,
                title: settings.tr('Health Journal'),
                subtitle:
                    'Personal Hemoglobin (g/dL), BP, iron recovery log & PDF export',
                onTap: () => showHealthJournalSheet(
                  context,
                  bloodType: _cachedUserBloodType,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildUrgentRequestsSection(BuildContext context) {
    return StreamBuilder<AppQuerySnapshot>(
      stream: _urgentRequestsStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Column(
            children: [
              RequestCardSkeleton(),
              RequestCardSkeleton(),
            ],
          );
        }

        final rawRequests = snapshot.data?.docs ?? [];
        if (rawRequests.isNotEmpty) {
          AppSettingsService().cacheEmergencyRequests(
            rawRequests.map((d) => d.data()).toList(),
          );
        }
        final requests = rawRequests.where((doc) {
          if (_selectedBloodFilter != null && _selectedBloodFilter != 'All') {
            final data = doc.data();
            final reqBg = (data['requiredBloodType'] ??
                    data['required_blood_type'] ??
                    '')
                .toString();
            if (_selectedBloodFilter == 'COMPATIBLE') {
              final donorBg = (_cachedUserBloodType ?? '').trim();
              if (donorBg.isEmpty) return true;
              return BloodCompatibility.isCompatible(
                donorBloodType: donorBg,
                recipientBloodType: reqBg,
              );
            }
            return reqBg == _selectedBloodFilter;
          }
          return true;
        }).toList();

        if (requests.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 38,
                  color: AppColors.success.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedBloodFilter != null
                      ? 'No active requests for $_selectedBloodFilter'
                      : 'No critical emergencies right now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All active emergency blood requests are currently covered.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: requests.map((doc) {
            final data = doc.data();
            final bloodType = data['requiredBloodType']?.toString() ?? '?';
            final hospital = data['hospitalName']?.toString() ?? 'Hospital';
            final address = data['hospitalAddress']?.toString() ?? '';
            final requiredUnits =
                (data['requiredUnits'] ?? data['unitsNeeded'] ?? 1) as int;
            final acceptedUnits = (data['acceptedUnits'] ?? 0) as int;
            final remainingUnits = (data['remainingUnits'] ??
                (requiredUnits - acceptedUnits)) as int;
            final urgency = data['urgencyLevel']?.toString() ?? 'Critical';
            final createdAt = data['createdAt'];
            DateTime? createdDt;
            if (createdAt is Timestamp) {
              createdDt = createdAt.toDate();
            } else if (createdAt is DateTime) {
              createdDt = createdAt;
            } else if (createdAt is String) {
              createdDt = DateTime.tryParse(createdAt);
            }

            String timeAgo = '';
            if (createdDt != null) {
              final diff = DateTime.now().difference(createdDt.toLocal());
              if (diff.inMinutes < 1) {
                timeAgo = 'Just now';
              } else if (diff.inMinutes < 60) {
                timeAgo = '${diff.inMinutes}m ago';
              } else if (diff.inHours < 24) {
                timeAgo = '${diff.inHours}h ago';
              } else {
                timeAgo = '${diff.inDays}d ago';
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(18),
                border: Border(
                  left: BorderSide(
                    color: AppColors.urgencyColor(urgency),
                    width: 4.5,
                  ),
                  top: BorderSide(color: AppColors.borderOf(context)),
                  right: BorderSide(color: AppColors.borderOf(context)),
                  bottom: BorderSide(color: AppColors.borderOf(context)),
                ),
                boxShadow:
                    AppColors.isDark(context) ? [] : AppColors.cardShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RequestDetailsPage(requestId: doc.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'req_bg_${doc.id}',
                          child: BloodGroupBadge(
                            bloodType: bloodType,
                            size: 50,
                            showGlow: true,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        UrgencyChip(
                                          urgency: urgency,
                                          compact: true,
                                        ),
                                        if (data['isVerifiedHospitalCase'] ==
                                            true)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.verified_user_rounded,
                                                  size: 10,
                                                  color: Color(0xFF10B981),
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Verified',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Text(
                                          '$remainingUnits unit(s)',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondaryOf(
                                                context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (timeAgo.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMutedOf(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                hospital,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Share Rich Emergency Card (WhatsApp / SMS)',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.share_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            final msg = AppSettingsService()
                                .formatEmergencyShareMessage({
                              ...data,
                              'id': doc.id,
                              'blood_type': bloodType,
                              'hospital_name': hospital,
                              'urgency': urgency,
                              'units': requiredUnits,
                              'units_fulfilled': acceptedUnits,
                            });
                            Share.share(msg);
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.isDark(context)
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// --- Component-Aware Blood Compatibility Explorer Sheet ---
class _BloodCompatibilityExplorerSheet extends StatefulWidget {
  final String initialBloodType;
  const _BloodCompatibilityExplorerSheet({required this.initialBloodType});

  @override
  State<_BloodCompatibilityExplorerSheet> createState() =>
      _BloodCompatibilityExplorerSheetState();
}

class _BloodCompatibilityExplorerSheetState
    extends State<_BloodCompatibilityExplorerSheet> {
  late String _selectedType;
  String _selectedComponent = 'Whole Blood';

  @override
  void initState() {
    super.initState();
    final normalized =
        BloodCompatibility.normalizeBloodGroup(widget.initialBloodType);
    _selectedType = normalized ?? 'O+';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final donateList = BloodCompatibility.canDonateTo(
      _selectedType,
      componentType: _selectedComponent,
    );
    final receiveList = BloodCompatibility.canReceiveFrom(
      _selectedType,
      componentType: _selectedComponent,
    );

    String? specialNote;
    if (_selectedComponent == 'Plasma' &&
        (_selectedType == 'AB+' || _selectedType == 'AB-')) {
      specialNote =
          'Universal Plasma Donor: AB plasma lacks anti-A and anti-B antibodies.';
    } else if (_selectedComponent != 'Plasma' &&
        _selectedComponent != 'Platelets' &&
        _selectedType == 'O-') {
      specialNote =
          'Universal Red Cell Donor: O- red cells can be transfused in critical emergencies.';
    } else if (_selectedComponent != 'Plasma' &&
        _selectedComponent != 'Platelets' &&
        _selectedType == 'AB+') {
      specialNote =
          'Universal Red Cell Recipient: AB+ patients can receive RBCs from all ABO/Rh groups.';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sync_alt_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Component Compatibility Guide',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Component Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: BloodCompatibility.supportedComponents.map((comp) {
                  final selected = _selectedComponent == comp;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(comp),
                      selected: selected,
                      selectedColor: AppColors.secondary,
                      backgroundColor: AppColors.mutedOf(context),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      onSelected: (v) {
                        if (v) setState(() => _selectedComponent = comp);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Blood Group Selection Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BloodCompatibility.validBloodGroups.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.mutedOf(context),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (specialNote != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF78350F).withValues(alpha: 0.35)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        specialNote,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Can Donate To
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.volunteer_activism_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_selectedType Can Donate $_selectedComponent To:',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: donateList.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Can Receive From
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.call_received_rounded,
                        color: AppColors.secondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_selectedType Can Receive $_selectedComponent From:',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: receiveList.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mutedOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.medical_information_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      BloodCompatibility.medicalCrossMatchDisclaimer,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
