// lib/features/blood_requests/presentation/pages/requests_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:share_plus/share_plus.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage>
    with SingleTickerProviderStateMixin {
  final RequestService _requestService = RequestService();
  final UserProfileService _profileService = UserProfileService();

  late TabController _tabController;
  String? _currentUserId;
  Position? _userPosition;

  late Stream<AppQuerySnapshot> _openRequestsStream;
  Stream<AppQuerySnapshot>? _allKnownRequestsStream;
  Stream<AppQuerySnapshot>? _myRequestsStream;
  Stream<AppQuerySnapshot>? _myOffersStream;

  String? _filterBloodType;
  String? _filterUrgency;
  String _myRequestsStatusFilter =
      'All'; // 'All', 'Active', 'Fulfilled', 'Closed'
  String _sortBy = 'newest'; // 'newest', 'urgency', 'distance'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _bloodTypes = [
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
  final List<String> _urgencyLevels = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _currentUserId = SupabaseAuthService().currentUserId;
    _initStreams();
    _initLocation();
  }

  void _initStreams() {
    _openRequestsStream = _requestService.getBloodRequestsStream();
    // Used for Saved tab so bookmarked fulfilled/expired requests still appear
    _allKnownRequestsStream =
        _requestService.getBloodRequestsStream(statusFilter: 'All');
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      _myRequestsStream = _requestService.getBloodRequestsStream(
        ownerUserId: _currentUserId,
      );
      _myOffersStream = _requestService.getUserOffersStream(_currentUserId!);
    } else {
      _myRequestsStream = null;
      _myOffersStream = null;
    }
  }

  Future<void> _initLocation({bool forcePrompt = false}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && forcePrompt) {
        permission = await Geolocator.requestPermission();
      } else if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 6),
        );
        if (mounted) setState(() => _userPosition = pos);
      }
    } catch (e) {
      debugPrint('RequestsPage location notice: $e');
    }
  }

  Future<void> _toggleBookmark(String requestId) async {
    HapticFeedback.lightImpact();
    final settings = AppSettingsService();
    final added = await settings.toggleBookmarkedRequest(requestId);
    final uid = _currentUserId;
    if (uid != null && uid.isNotEmpty) {
      unawaited(
        _profileService.updateUserProfile(uid, {
          'bookmarkedRequestIds':
              settings.bookmarkedRequestsNotifier.value.toList(),
        }).catchError((e) => debugPrint('Bookmark sync notice: $e')),
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(added ? 'Saved to bookmarks.' : 'Removed from bookmarks.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _shareRequestCard({
    required String bloodType,
    required String componentType,
    required int remainingUnits,
    required int requiredUnits,
    required String hospital,
    required String address,
    required String urgency,
  }) async {
    HapticFeedback.lightImpact();
    final text = 'URGENT BLOOD REQUEST ($urgency)\n'
        'Blood Needed: $bloodType ($componentType) — $remainingUnits of $requiredUnits unit(s)\n'
        'Hospital: $hospital${address.isNotEmpty ? ", $address" : ""}\n'
        'Please respond via RedCellNet if eligible and compatible.';
    try {
      await Share.share(text, subject: 'Urgent $bloodType Blood Request');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency alert copied to clipboard.')),
        );
      }
    }
  }

  double? _calculateDistanceKm(Map<String, dynamic> data) {
    if (_userPosition == null) return null;
    final coords = data['locationCoords'] ??
        data['location_coords'] ??
        data['hospitalCoords'];
    if (coords is Map) {
      final lat = coords['latitude'] ?? coords['lat'];
      final lng = coords['longitude'] ?? coords['lng'];
      if (lat is num && lng is num) {
        return Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              lat.toDouble(),
              lng.toDouble(),
            ) /
            1000.0;
      }
    }
    return null;
  }

  int _urgencyRank(String? level) {
    switch (level?.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  List<AppDocSnapshot> _sortRequests(List<AppDocSnapshot> list) {
    final sorted = List<AppDocSnapshot>.from(list);
    if (_sortBy == 'urgency') {
      sorted.sort((a, b) {
        final uA = _urgencyRank(a.data()['urgencyLevel']?.toString());
        final uB = _urgencyRank(b.data()['urgencyLevel']?.toString());
        return uB.compareTo(uA);
      });
    } else if (_sortBy == 'distance') {
      sorted.sort((a, b) {
        final dA = _calculateDistanceKm(a.data()) ?? 999999.0;
        final dB = _calculateDistanceKm(b.data()) ?? 999999.0;
        return dA.compareTo(dB);
      });
    } else {
      sorted.sort((a, b) {
        final tA =
            (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tB =
            (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tB.compareTo(tA);
      });
    }
    return sorted;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet() {
    String? tempBloodType = _filterBloodType;
    String? tempUrgency = _filterUrgency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
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
                        Text(
                          'Filter Blood Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Divider(color: AppColors.borderOf(context)),
                    const SizedBox(height: 12),
                    Text(
                      'Blood Group',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _bloodTypes.where((t) => t != 'All').map((type) {
                        final isSelected = tempBloodType == type;
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
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          onSelected: (selected) {
                            setModalState(() {
                              tempBloodType = selected ? type : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Urgency Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _urgencyLevels.map((lvl) {
                        final isSelected = tempUrgency == lvl;
                        final color = UrgencyChip.getUrgencyColor(lvl);
                        return FilterChip(
                          label: Text(lvl),
                          selected: isSelected,
                          selectedColor: color.withValues(alpha: 0.2),
                          checkmarkColor: color,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? color
                                : AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? color
                                  : AppColors.borderOf(context),
                            ),
                          ),
                          onSelected: (selected) {
                            setModalState(() {
                              tempUrgency = selected ? lvl : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _filterBloodType = null;
                                _filterUrgency = null;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filterBloodType = tempBloodType;
                                _filterUrgency = tempUrgency;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Apply Filter'),
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
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';
    final DateTime date = timestamp.toDate().toLocal();
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

  @override
  Widget build(BuildContext context) {
    final bool filtersActive =
        _filterBloodType != null || _filterUrgency != null;
    final isDark = AppColors.isDark(context);
    final settings = AppSettingsService();

    return ValueListenableBuilder<Set<String>>(
      valueListenable: settings.bookmarkedRequestsNotifier,
      builder: (context, bookmarkedIds, _) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldOf(context),
          appBar: AppBar(
            title: Text(settings.tr('Blood Requests')),
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      filtersActive
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      color: filtersActive
                          ? AppColors.primary
                          : AppColors.textPrimaryOf(context),
                    ),
                    tooltip: 'Filter Requests',
                    onPressed: _showFilterBottomSheet,
                  ),
                  if (filtersActive)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const NotificationBellAction(),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'All Open'),
                Tab(text: settings.tr('Nearby')),
                const Tab(text: 'Critical & High'),
                Tab(
                  text: bookmarkedIds.isEmpty
                      ? settings.tr('Saved')
                      : '${settings.tr('Saved')} (${bookmarkedIds.length})',
                ),
                Tab(text: settings.tr('My Requests')),
                const Tab(text: 'My Offers'),
              ],
            ),
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: AppColors.cardBg(context),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 14,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search hospital, city, patient ref, or blood group...',
                        hintStyle:
                            TextStyle(color: AppColors.textMutedOf(context)),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.mutedOf(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _bloodTypes.map((type) {
                          final isSelected =
                              (_filterBloodType == null && type == 'All') ||
                                  _filterBloodType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(
                                type == 'All' ? settings.tr('All') : type,
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.mutedOf(context),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimaryOf(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _filterBloodType =
                                      (type == 'All') ? null : type;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Sort by:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSortPill(
                          'Newest',
                          'newest',
                          Icons.access_time_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildSortPill(
                          'Urgency',
                          'urgency',
                          Icons.priority_high_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildSortPill(
                          'Distance',
                          'distance',
                          Icons.near_me_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: All Open
                    _buildRequestList(
                      stream: _openRequestsStream,
                      bookmarkedIds: bookmarkedIds,
                      listKey: const PageStorageKey('allRequestsTab'),
                      emptyTitle: 'No Matching Blood Requests',
                      emptyMessage:
                          'No open requests matched your search or filter criteria.',
                    ),
                    // Tab 2: Nearby (Strictly GPS-verified within 35 km)
                    _userPosition == null
                        ? EmptyStateView(
                            icon: Icons.location_searching_rounded,
                            title: 'Enable Location for Nearby Matching',
                            message:
                                'Grant GPS access to filter active emergency blood requests within 35 km of your location.',
                            buttonText: 'Detect My Location',
                            onAction: () => _initLocation(forcePrompt: true),
                          )
                        : _buildRequestList(
                            stream: _openRequestsStream,
                            bookmarkedIds: bookmarkedIds,
                            filterNearbyOnly: true,
                            listKey: const PageStorageKey('nearbyRequestsTab'),
                            emptyTitle: 'No Nearby Blood Requests',
                            emptyMessage:
                                'No active requests with pinned coordinates within 35 km. Check "All Open" for city-wide requests.',
                          ),
                    // Tab 3: Critical & High Only
                    _buildRequestList(
                      stream: _openRequestsStream,
                      bookmarkedIds: bookmarkedIds,
                      filterUrgentOnly: true,
                      listKey: const PageStorageKey('urgentRequestsTab'),
                      emptyTitle: 'No Critical Emergencies',
                      emptyMessage:
                          'Currently there are no critical or high-priority requests open.',
                    ),
                    // Tab 4: Saved / Bookmarks
                    _buildRequestList(
                      stream: _allKnownRequestsStream ?? _openRequestsStream,
                      bookmarkedIds: bookmarkedIds,
                      filterSavedOnly: true,
                      listKey: const PageStorageKey('savedRequestsTab'),
                      emptyTitle: 'No Saved Requests',
                      emptyMessage:
                          'Tap the bookmark icon on any blood request to track it quickly here.',
                    ),
                    // Tab 5: My Requests (Guarded + Status Sub-Filters)
                    _buildMyRequestsTab(bookmarkedIds),
                    // Tab 6: My Offers
                    _buildMyOffersList(),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'requests_page_create_fab',
            backgroundColor:
                isDark ? const Color(0xFFE11D48) : AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            highlightElevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateRequestPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            label: Text(
              settings.tr('Request Blood'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyRequestsTab(Set<String> bookmarkedIds) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return const EmptyStateView(
        icon: Icons.lock_outline_rounded,
        title: 'Sign In Required',
        message: 'Please sign in to view and manage your blood requests.',
      );
    }

    final statuses = ['All', 'Active', 'Fulfilled', 'Closed'];
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            border: Border(
              bottom: BorderSide(color: AppColors.borderOf(context)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((s) {
                final selected = _myRequestsStatusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    selectedColor: AppColors.secondary,
                    backgroundColor: AppColors.mutedOf(context),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimaryOf(context),
                    ),
                    onSelected: (_) {
                      setState(() => _myRequestsStatusFilter = s);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _buildRequestList(
            stream: _myRequestsStream ?? const Stream.empty(),
            bookmarkedIds: bookmarkedIds,
            ownerStatusSubFilter: _myRequestsStatusFilter,
            listKey: const PageStorageKey('myRequestsTab'),
            emptyTitle: 'No Matching Requests',
            emptyMessage: _myRequestsStatusFilter == 'All'
                ? 'You have not posted any blood requests yet.'
                : 'No "$_myRequestsStatusFilter" requests found in your history.',
          ),
        ),
      ],
    );
  }

  Widget _buildSortPill(String label, String value, IconData icon) {
    final bool isSelected = _sortBy == value;
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _sortBy = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primaryContainer)
              : AppColors.mutedOf(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList({
    required Stream<AppQuerySnapshot> stream,
    required Set<String> bookmarkedIds,
    required PageStorageKey listKey,
    required String emptyTitle,
    required String emptyMessage,
    bool filterUrgentOnly = false,
    bool filterNearbyOnly = false,
    bool filterSavedOnly = false,
    String? ownerStatusSubFilter,
  }) {
    return StreamBuilder<AppQuerySnapshot>(
      stream: stream,
      key: listKey,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: 4,
            itemBuilder: (_, __) => const RequestCardSkeleton(),
          );
        }

        List<AppDocSnapshot> requests = List.from(snapshot.data?.docs ?? []);

        if (filterSavedOnly) {
          requests =
              requests.where((doc) => bookmarkedIds.contains(doc.id)).toList();
        }

        if (ownerStatusSubFilter != null && ownerStatusSubFilter != 'All') {
          requests = requests.where((doc) {
            final st = (doc.data()['status'] ?? 'Open').toString();
            if (ownerStatusSubFilter == 'Active') {
              return st == 'Open' || st == 'Partially Fulfilled';
            }
            if (ownerStatusSubFilter == 'Fulfilled') {
              return st == 'Fulfilled';
            }
            if (ownerStatusSubFilter == 'Closed') {
              return st == 'Cancelled' || st == 'Expired';
            }
            return true;
          }).toList();
        }

        if (_filterBloodType != null && _filterBloodType != 'All') {
          requests = requests
              .where(
                  (doc) => doc.data()['requiredBloodType'] == _filterBloodType)
              .toList();
        }

        if (_filterUrgency != null && _filterUrgency != 'All') {
          requests = requests
              .where((doc) => doc.data()['urgencyLevel'] == _filterUrgency)
              .toList();
        }

        if (filterUrgentOnly) {
          requests = requests.where((doc) {
            final urgency = doc.data()['urgencyLevel'] ?? '';
            return urgency == 'Critical' || urgency == 'High';
          }).toList();
        }

        if (filterNearbyOnly) {
          requests = requests.where((doc) {
            final dist = _calculateDistanceKm(doc.data());
            return dist != null && dist <= 35.0;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          requests = requests.where((doc) {
            final data = doc.data();
            final hospital =
                (data['hospitalName'] ?? '').toString().toLowerCase();
            final address =
                (data['hospitalAddress'] ?? '').toString().toLowerCase();
            final city = (data['city'] ?? '').toString().toLowerCase();
            final blood =
                (data['requiredBloodType'] ?? '').toString().toLowerCase();
            final patient =
                (data['patientIdentifier'] ?? '').toString().toLowerCase();
            final directMatch = hospital.contains(_searchQuery) ||
                address.contains(_searchQuery) ||
                city.contains(_searchQuery) ||
                blood.contains(_searchQuery) ||
                patient.contains(_searchQuery);
            if (directMatch) return true;
            // Typo-tolerant trigram fuzzy matching
            return AppSettingsService.fuzzyMatchScore(hospital, _searchQuery) >=
                    0.30 ||
                AppSettingsService.fuzzyMatchScore(city, _searchQuery) >=
                    0.34 ||
                AppSettingsService.fuzzyMatchScore(address, _searchQuery) >=
                    0.32;
          }).toList();
        }

        requests = _sortRequests(requests);

        if (requests.isEmpty) {
          return EmptyStateView(
            icon: filterSavedOnly
                ? Icons.bookmark_border_rounded
                : Icons.bloodtype_outlined,
            title: emptyTitle,
            message: emptyMessage,
            buttonText: filterSavedOnly ? null : 'Post a Blood Request',
            onAction: filterSavedOnly
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateRequestPage(),
                      ),
                    ),
          );
        }

        final isDark = AppColors.isDark(context);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 88.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestDoc = requests[index];
            final requestData = requestDoc.data();
            final String bloodType =
                requestData['requiredBloodType']?.toString() ?? 'N/A';
            final String hospital =
                requestData['hospitalName']?.toString() ?? 'Unknown Hospital';
            final String address =
                requestData['hospitalAddress']?.toString() ?? '';
            final String city = requestData['city']?.toString() ?? '';
            final String urgency =
                requestData['urgencyLevel']?.toString() ?? 'Medium';
            final String status = requestData['status']?.toString() ?? 'Open';
            final String componentType =
                requestData['componentType']?.toString() ?? 'Whole Blood';

            final int requiredUnits = (requestData['requiredUnits'] ??
                requestData['unitsNeeded'] ??
                1) as int;
            final int acceptedUnits =
                (requestData['acceptedUnits'] ?? 0) as int;
            final int remainingUnits = (requestData['remainingUnits'] ??
                (requiredUnits - acceptedUnits)) as int;

            final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
            final String timeAgo = _formatTimestamp(createdAt);
            final double? distanceKm = _calculateDistanceKm(requestData);
            final bool isBookmarked = bookmarkedIds.contains(requestDoc.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
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
                boxShadow: isDark ? [] : AppColors.cardShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RequestDetailsPage(requestId: requestDoc.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'req_bg_${requestDoc.id}',
                              child: BloodGroupBadge(
                                bloodType: bloodType,
                                size: 52,
                                showGlow: true,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                                            if (distanceKm != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppColors.secondary
                                                          .withValues(
                                                              alpha: 0.2)
                                                      : AppColors
                                                          .secondaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.near_me_rounded,
                                                      size: 9,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF93C5FD)
                                                          : AppColors
                                                              .secondaryDark,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${distanceKm.toStringAsFixed(1)} km',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF93C5FD)
                                                            : AppColors
                                                                .secondaryDark,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (requestData[
                                                    'isVerifiedHospitalCase'] ==
                                                true)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF10B981)
                                                            .withValues(
                                                                alpha: 0.4),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .verified_user_rounded,
                                                      size: 10,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'Verified',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            Color(0xFF10B981),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (status != 'Open')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status == 'Fulfilled'
                                                      ? AppColors.success
                                                          .withValues(
                                                              alpha: 0.16)
                                                      : (status ==
                                                              'Partially Fulfilled'
                                                          ? AppColors.warning
                                                              .withValues(
                                                                  alpha: 0.18)
                                                          : AppColors.mutedOf(
                                                              context)),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  status ==
                                                          'Partially Fulfilled'
                                                      ? 'Partial'
                                                      : status,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: status == 'Fulfilled'
                                                        ? AppColors.success
                                                        : (status ==
                                                                'Partially Fulfilled'
                                                            ? AppColors
                                                                .warningDark
                                                            : AppColors
                                                                .textSecondaryOf(
                                                                    context)),
                                                  ),
                                                ),
                                              ),
                                            if (componentType != 'Whole Blood')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.mutedOf(
                                                      context),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  componentType,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors
                                                        .textSecondaryOf(
                                                            context),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          color: AppColors.textMutedOf(context),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hospital,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimaryOf(context),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        UnitsProgressIndicator(
                          requiredUnits: requiredUnits,
                          acceptedUnits: acceptedUnits,
                          remainingUnits: remainingUnits,
                          compact: true,
                        ),
                        const SizedBox(height: 10),
                        Divider(height: 1, color: AppColors.borderOf(context)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textMutedOf(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address.isNotEmpty
                                    ? address
                                    : (city.isNotEmpty
                                        ? city
                                        : 'Hospital location in details'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 19,
                                color: isBookmarked
                                    ? AppColors.primary
                                    : AppColors.textSecondaryOf(context),
                              ),
                              tooltip: isBookmarked
                                  ? 'Remove Bookmark'
                                  : 'Save Request',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _toggleBookmark(requestDoc.id),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.share_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Share Request',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _shareRequestCard(
                                bloodType: bloodType,
                                componentType: componentType,
                                remainingUnits: remainingUnits,
                                requiredUnits: requiredUnits,
                                hospital: hospital,
                                address: address,
                                urgency: urgency,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Details',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyOffersList() {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return const EmptyStateView(
        icon: Icons.lock_outline_rounded,
        title: 'Sign In Required',
        message: 'Please sign in to view and track your donation offers.',
      );
    }

    return StreamBuilder<AppQuerySnapshot>(
      stream: _myOffersStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: 4,
            itemBuilder: (_, __) => const RequestCardSkeleton(),
          );
        }

        final offers = snapshot.data?.docs ?? [];
        if (offers.isEmpty) {
          return const EmptyStateView(
            icon: Icons.volunteer_activism_outlined,
            title: 'No Donation Offers Yet',
            message:
                'When you volunteer to donate on a blood request, your pending, accepted, and verified donations appear here.',
          );
        }

        final isDark = AppColors.isDark(context);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 88.0),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offerDoc = offers[index];
            final data = offerDoc.data();
            final String status = data['status']?.toString() ?? 'pending';
            final bool donationVerified = data['donationVerified'] == true;
            final int offeredUnits = (data['offeredUnits'] ?? 1) as int;
            final String donorBloodType =
                data['donorBloodType']?.toString() ?? '';
            final Timestamp? time = data['offerTimestamp'] as Timestamp?;
            final String? parentRequestId = data['requestId']?.toString();
            final String hospitalName =
                data['hospitalName']?.toString() ?? 'Blood Request';

            Color statusBg;
            Color statusColor;
            String statusText;

            if (donationVerified) {
              statusBg = AppColors.success.withValues(alpha: 0.18);
              statusColor = AppColors.success;
              statusText = 'Verified Donation Completed';
            } else {
              switch (status.toLowerCase()) {
                case 'accepted':
                  statusBg = AppColors.success.withValues(alpha: 0.16);
                  statusColor = AppColors.success;
                  statusText = 'Accepted — Proceed to Hospital';
                  break;
                case 'declined':
                case 'rejected':
                  statusBg = AppColors.critical.withValues(alpha: 0.16);
                  statusColor = AppColors.critical;
                  statusText = 'Declined / Slot Closed';
                  break;
                case 'withdrawn':
                  statusBg = AppColors.mutedOf(context);
                  statusColor = AppColors.textMutedOf(context);
                  statusText = 'Withdrawn';
                  break;
                default:
                  statusBg = AppColors.warning.withValues(alpha: 0.18);
                  statusColor =
                      isDark ? const Color(0xFFFCD34D) : AppColors.warningDark;
                  statusText = 'Pending Requester Review';
                  break;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
                boxShadow: isDark ? [] : AppColors.cardShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: parentRequestId != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestDetailsPage(
                                requestId: parentRequestId,
                              ),
                            ),
                          )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BloodGroupBadge(bloodType: donorBloodType, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospitalName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Offered $offeredUnits Unit(s) • ${_formatTimestamp(time)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (parentRequestId != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.primary,
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
      },
    );
  }
}
