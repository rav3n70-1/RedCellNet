// lib/features/home/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/requests_page.dart';
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_list_page.dart';
import 'package:red_cell_net_final/features/nearby_map/presentation/pages/map_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeContent(onNavigate: _onItemTapped),
      const RequestsPage(),
      const MapPage(),
      const ProfilePage(),
      const EducationalContentListPage(),
    ];
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _buildNavItem(1, Icons.bloodtype_rounded, Icons.bloodtype_outlined, 'Requests'),
                _buildNavItem(2, Icons.map_rounded, Icons.map_outlined, 'Map'),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
                _buildNavItem(4, Icons.school_rounded, Icons.school_outlined, 'Learn'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ],
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

  String? _selectedBloodFilter;
  bool _isTogglingAvailability = false;

  final List<String> _bloodGroups = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  Future<void> _toggleAvailability(String uid, bool currentStatus) async {
    if (_isTogglingAvailability) return;
    setState(() => _isTogglingAvailability = true);

    final bool newStatus = !currentStatus;
    try {
      await _profileService.updateUserProfile(uid, {'isAvailableToDonate': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Ready to donate! You are visible for urgent requests.'
                  : 'You are now marked as off-duty.',
            ),
            backgroundColor: newStatus ? AppColors.success : AppColors.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.critical),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  void _showCompatibilityBottomSheet(String defaultType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // --- Header Bar with User Greeting, Blood Badge & Quick Availability Switch ---
              StreamBuilder<ProfileSnapshot>(
                stream: currentUserId != null
                    ? _profileService.getUserProfileStream(currentUserId)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  String name = '';
                  String bloodType = '';
                  bool isAvailable = false;
                  int points = 0;
                  int totalDonations = 0;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data();
                    name = data?['name'] ?? '';
                    bloodType = data?['bloodType'] ?? '';
                    isAvailable = data?['isAvailableToDonate'] ?? false;
                    points = data?['points'] ?? 0;
                    totalDonations = data?['totalDonations'] ?? 0;
                  }

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

                  return Column(
                    children: [
                      // Greeting & Profile Avatar Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTimeGreeting(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Notification bell & Blood Group Avatar
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const NotificationBellAction(),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => widget.onNavigate(3),
                                child: bloodType.isNotEmpty
                                    ? BloodGroupBadge(bloodType: bloodType, size: 44, showGlow: true)
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.primaryLight),
                                        ),
                                        child: const Icon(Icons.person_rounded,
                                            color: AppColors.primary, size: 24),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Availability Status & Quick Toggle Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAvailable
                                ? AppColors.success.withValues(alpha: 0.4)
                                : AppColors.border,
                          ),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? AppColors.successLight
                                        : AppColors.surfaceMuted,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isAvailable ? Icons.volunteer_activism_rounded : Icons.bedtime_rounded,
                                    size: 18,
                                    color: isAvailable ? AppColors.success : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAvailable ? 'Ready for Donation' : 'Currently Off-Duty',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isAvailable ? const Color(0xFF166534) : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      isAvailable
                                          ? 'You will receive urgent hospital requests'
                                          : 'Turn on when you are available to donate',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAvailable ? const Color(0xFF15803D) : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: isAvailable,
                              activeThumbColor: AppColors.success,
                              onChanged: currentUserId == null
                                  ? null
                                  : (_) => _toggleAvailability(
                                      currentUserId, isAvailable),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Stats Row: Life Points & Donations
                      Row(
                        children: [
                          Expanded(
                            child: StatMetricCard(
                              title: 'Life Points',
                              value: '$points',
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFD97706),
                              bgColor: const Color(0xFFFEF3C7),
                              onTap: () => widget.onNavigate(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatMetricCard(
                              title: 'Lives Impacted',
                              value: '${totalDonations * 3}',
                              icon: Icons.favorite_rounded,
                              iconColor: AppColors.primary,
                              bgColor: AppColors.primaryContainer,
                              onTap: () => widget.onNavigate(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatMetricCard(
                              title: 'Compatibility',
                              value: bloodType.isNotEmpty ? bloodType : 'Guide',
                              icon: Icons.sync_alt_rounded,
                              iconColor: AppColors.secondary,
                              bgColor: AppColors.secondaryLight,
                              onTap: () => _showCompatibilityBottomSheet(bloodType),
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
                      MaterialPageRoute(builder: (context) => const CreateRequestPage()),
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
                                    const Text(
                                      'Need Blood Urgently?',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
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
                                  'Post an emergency alert to nearby verified donors',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
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
                  const Text(
                    'Filter by Blood Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_selectedBloodFilter != null && _selectedBloodFilter != 'All')
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
                  children: _bloodGroups.map((group) {
                    final isSelected = (_selectedBloodFilter == null && group == 'All') ||
                        _selectedBloodFilter == group;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(group),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedBloodFilter = group == 'All' ? null : group;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // --- Urgent Emergencies Feed ---
              SectionHeader(
                title: 'Urgent Emergencies',
                subtitle: _selectedBloodFilter != null
                    ? 'Showing requests for $_selectedBloodFilter'
                    : 'Patients needing immediate assistance',
                actionLabel: 'View All',
                icon: Icons.local_fire_department_rounded,
                onAction: () => widget.onNavigate(1),
              ),
              const SizedBox(height: 8),
              _buildUrgentRequestsSection(context),
              const SizedBox(height: 24),

              // --- Quick Services Grid (OpenStreetMap, Guide, etc.) ---
              const SectionHeader(
                title: 'Explore Services',
                subtitle: 'Find centers, interact with OpenStreetMap & learn',
                icon: Icons.grid_view_rounded,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.map_rounded,
                      iconColor: AppColors.secondary,
                      bgColor: AppColors.secondaryLight,
                      title: 'OpenStreetMap',
                      subtitle: 'Find nearby centers & drives',
                      onTap: () => widget.onNavigate(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildServiceTile(
                      icon: Icons.school_rounded,
                      iconColor: const Color(0xFF059669),
                      bgColor: const Color(0xFFD1FAE5),
                      title: 'Learn & Aware',
                      subtitle: 'Articles (+Life Points)',
                      onTap: () => widget.onNavigate(4),
                    ),
                  ),
                ],
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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

  // --- Urgent Requests List Builder ---
  Widget _buildUrgentRequestsSection(BuildContext context) {
    return StreamBuilder<AppQuerySnapshot>(
      stream: _requestService.getUrgentRequestsStream(limit: 6),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const CircularProgressIndicator(strokeWidth: 2.2),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                "Could not load requests: ${snapshot.error}",
                style: const TextStyle(color: AppColors.critical, fontSize: 13),
              ),
            ),
          );
        }

        final rawRequests = snapshot.data?.docs ?? [];
        final requests = rawRequests.where((doc) {
          if (_selectedBloodFilter != null && _selectedBloodFilter != 'All') {
            return doc.data()['requiredBloodType'] == _selectedBloodFilter;
          }
          return true;
        }).toList();

        if (requests.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 38, color: AppColors.success.withValues(alpha: 0.8)),
                const SizedBox(height: 10),
                Text(
                  _selectedBloodFilter != null
                      ? 'No active requests for $_selectedBloodFilter'
                      : 'No critical emergencies right now',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Great news! All active blood requests are currently covered.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: requests.map((doc) {
            final data = doc.data();
            final bloodType = data['requiredBloodType'] ?? '?';
            final hospital = data['hospitalName'] ?? 'Hospital';
            final address = data['hospitalAddress'] ?? '';
            final status = data['status'] ?? 'Open';
            final requiredUnits = (data['requiredUnits'] ?? data['unitsNeeded'] ?? 1) as int;
            final acceptedUnits = (data['acceptedUnits'] ?? 0) as int;
            final remainingUnits = (data['remainingUnits'] ?? (requiredUnits - acceptedUnits)) as int;
            final urgency = data['urgencyLevel'] ?? 'Critical';
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
              final diff = DateTime.now().difference(createdDt);
              if (diff.inMinutes < 60) {
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: status == 'Partially Fulfilled'
                      ? AppColors.warning.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestDetailsPage(requestId: doc.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Blood Type Badge with glow
                            BloodGroupBadge(bloodType: bloodType, size: 50, showGlow: true),
                            const SizedBox(width: 14),

                            // Request Information
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      UrgencyChip(urgency: urgency, compact: true),
                                      const SizedBox(width: 6),
                                      if (status == 'Partially Fulfilled') ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.warningLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Partial',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.warningDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        '$remainingUnits unit(s) needed',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (timeAgo.isNotEmpty) ...[
                                        const Spacer(),
                                        Text(
                                          timeAgo,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    hospital,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      address,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Action button
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Help',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (requiredUnits > 1) ...[
                          const SizedBox(height: 10),
                          UnitsProgressIndicator(
                            requiredUnits: requiredUnits,
                            acceptedUnits: acceptedUnits,
                            remainingUnits: remainingUnits,
                            compact: true,
                          ),
                        ],
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

// --- Blood Compatibility Explorer Bottom Sheet ---
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

  final List<String> _types = ['O-', 'O+', 'B-', 'B+', 'A-', 'A+', 'AB-', 'AB+'];

  // Compatibility data
  static const Map<String, List<String>> _canDonateTo = {
    'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'], // Universal donor
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A-', 'A+', 'AB-', 'AB+'],
    'A+': ['A+', 'AB+'],
    'B-': ['B-', 'B+', 'AB-', 'AB+'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB-', 'AB+'],
    'AB+': ['AB+'], // Universal recipient for receiving, gives only to AB+
  };

  static const Map<String, List<String>> _canReceiveFrom = {
    'O-': ['O-'],
    'O+': ['O-', 'O+'],
    'A-': ['O-', 'A-'],
    'A+': ['O-', 'O+', 'A-', 'A+'],
    'B-': ['O-', 'B-'],
    'B+': ['O-', 'O+', 'B-', 'B+'],
    'AB-': ['O-', 'A-', 'B-', 'AB-'],
    'AB+': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'], // Universal recipient
  };

  @override
  void initState() {
    super.initState();
    _selectedType = _types.contains(widget.initialBloodType)
        ? widget.initialBloodType
        : 'O+';
  }

  @override
  Widget build(BuildContext context) {
    final donateList = _canDonateTo[_selectedType] ?? [];
    final receiveList = _canReceiveFrom[_selectedType] ?? [];
    final isUniversalDonor = _selectedType == 'O-';
    final isUniversalRecipient = _selectedType == 'AB+';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_alt_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Blood Compatibility Matrix',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select any blood group to see who they can give to and receive from:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Blood Type Selector Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((type) {
              final isSelected = type == _selectedType;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedType = type);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Special Badge
          if (isUniversalDonor)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Universal Red Cell Donor: O- can be given to anyone in emergencies!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isUniversalRecipient)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0284C7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFF0284C7), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Universal Recipient: AB+ can safely receive blood from all blood types!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$_selectedType Can Donate Blood To:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
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
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call_received_rounded, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$_selectedType Can Receive Blood From:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
