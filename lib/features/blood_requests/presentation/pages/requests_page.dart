// lib/features/blood_requests/presentation/pages/requests_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> with SingleTickerProviderStateMixin {
  final RequestService _requestService = RequestService();
  late TabController _tabController;
  String? _currentUserId;

  String? _filterBloodType;
  String? _filterUrgency;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _bloodTypes = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _urgencyLevels = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = SupabaseAuthService().currentUserId;
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Blood Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),

                  // Blood Type Chips
                  const Text(
                    'Blood Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bloodTypes.where((t) => t != 'All').map((type) {
                      final isSelected = tempBloodType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.transparent,
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

                  // Urgency Level Chips
                  const Text(
                    'Urgency Level',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                        selectedColor: color.withValues(alpha: 0.18),
                        checkmarkColor: color,
                        labelStyle: TextStyle(
                          color: isSelected ? color : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? color : AppColors.border,
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

                  // Actions: Reset & Apply
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempBloodType = null;
                              tempUrgency = null;
                            });
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply Filter'),
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
    final bool filtersActive = _filterBloodType != null || _filterUrgency != null;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Blood Requests'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  filtersActive ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                  color: filtersActive ? AppColors.primary : AppColors.textPrimary,
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
          tabs: const [
            Tab(text: 'All Open'),
            Tab(text: 'Critical & High'),
            Tab(text: 'My Requests'),
            Tab(text: 'My Offers'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Quick Blood Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search hospital, location, or blood type...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal Blood Group Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _bloodTypes.map((type) {
                      final isSelected = (_filterBloodType == null && type == 'All') ||
                          _filterBloodType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceMuted,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _filterBloodType = (type == 'All') ? null : type;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Main Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: All Open
                _buildRequestList(
                  stream: _requestService.getBloodRequestsStream(
                    bloodTypeFilter: _filterBloodType,
                    urgencyLevelFilter: _filterUrgency,
                  ),
                  listKey: const PageStorageKey('allRequestsTab'),
                  emptyTitle: 'No Matching Blood Requests',
                  emptyMessage: 'No open requests matched your search or filter parameters.',
                ),
                // Tab 2: Critical & High Only
                _buildRequestList(
                  stream: _requestService.getBloodRequestsStream(
                    bloodTypeFilter: _filterBloodType,
                  ),
                  filterUrgentOnly: true,
                  listKey: const PageStorageKey('urgentRequestsTab'),
                  emptyTitle: 'No Critical Emergencies',
                  emptyMessage: 'Currently there are no urgent or critical requests open.',
                ),
                // Tab 3: My Requests
                _buildRequestList(
                  stream: _requestService.getBloodRequestsStream(
                    ownerUserId: _currentUserId,
                  ),
                  listKey: const PageStorageKey('myRequestsTab'),
                  emptyTitle: 'No Requests Created',
                  emptyMessage: 'You haven\'t posted any blood requests yet. Tap "+ New Request" to create one.',
                ),
                // Tab 4: My Offers
                _buildMyOffersList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateRequestPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request'),
      ),
    );
  }

  Widget _buildRequestList({
    required Stream<AppQuerySnapshot> stream,
    required PageStorageKey listKey,
    required String emptyTitle,
    required String emptyMessage,
    bool filterUrgentOnly = false,
  }) {
    return StreamBuilder<AppQuerySnapshot>(
      stream: stream,
      key: listKey,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.critical),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading requests: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        var requests = snapshot.data?.docs ?? [];

        // Apply Urgent Filter if requested
        if (filterUrgentOnly) {
          requests = requests.where((doc) {
            final urgency = (doc.data()['urgencyLevel'] ?? '').toString();
            return urgency == 'Critical' || urgency == 'High';
          }).toList();
        }

        // Apply Search Query filter
        if (_searchQuery.isNotEmpty) {
          requests = requests.where((doc) {
            final data = doc.data();
            final hospital = (data['hospitalName'] ?? '').toString().toLowerCase();
            final address = (data['hospitalAddress'] ?? '').toString().toLowerCase();
            final blood = (data['requiredBloodType'] ?? '').toString().toLowerCase();
            final patient = (data['patientIdentifier'] ?? '').toString().toLowerCase();
            return hospital.contains(_searchQuery) ||
                address.contains(_searchQuery) ||
                blood.contains(_searchQuery) ||
                patient.contains(_searchQuery);
          }).toList();
        }

        if (requests.isEmpty) {
          return EmptyStateView(
            icon: Icons.bloodtype_outlined,
            title: emptyTitle,
            message: emptyMessage,
            buttonText: 'Post a Blood Request',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateRequestPage()),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 88.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestDoc = requests[index];
            final requestData = requestDoc.data();
            final String bloodType = requestData['requiredBloodType'] ?? 'N/A';
            final String hospital = requestData['hospitalName'] ?? 'Unknown Hospital';
            final String address = requestData['hospitalAddress'] ?? '';
            final String urgency = requestData['urgencyLevel'] ?? 'Medium';
            final String status = requestData['status'] ?? 'Open';
            final String componentType = requestData['componentType'] ?? 'Whole Blood';

            final int requiredUnits =
                (requestData['requiredUnits'] ?? requestData['unitsNeeded'] ?? 1) as int;
            final int acceptedUnits = (requestData['acceptedUnits'] ?? 0) as int;
            final int remainingUnits = (requestData['remainingUnits'] ?? (requiredUnits - acceptedUnits)) as int;

            final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
            final String timeAgo = _formatTimestamp(createdAt);

            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
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
                      builder: (context) => RequestDetailsPage(requestId: requestDoc.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Blood group, Urgency chip, Status, Time
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BloodGroupBadge(bloodType: bloodType, size: 52, showGlow: true),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      UrgencyChip(urgency: urgency, compact: true),
                                      const SizedBox(width: 8),
                                      if (status == 'Partially Fulfilled') ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                                      if (componentType != 'Whole Blood') ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            componentType,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        timeAgo,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hospital,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
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

                        // Multi-unit progress indicator bar
                        UnitsProgressIndicator(
                          requiredUnits: requiredUnits,
                          acceptedUnits: acceptedUnits,
                          remainingUnits: remainingUnits,
                          compact: true,
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: 10),

                        // Bottom Row: Hospital Address & View Details Action Pill
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address.isNotEmpty ? address : 'Hospital location specified in details',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
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
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10, color: AppColors.primary),
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

  // --- Tab 4: My Offers Tracker ---
  Widget _buildMyOffersList() {
    if (_currentUserId == null) {
      return const EmptyStateView(
        icon: Icons.lock_outline_rounded,
        title: 'Sign In Required',
        message: 'Please sign in to view and track your donation offers.',
      );
    }

    return StreamBuilder<AppQuerySnapshot>(
      stream: _requestService.getUserOffersStream(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Notice: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final offers = snapshot.data?.docs ?? [];

        if (offers.isEmpty) {
          return const EmptyStateView(
            icon: Icons.volunteer_activism_outlined,
            title: 'No Donation Offers Yet',
            message: 'When you offer blood to patients in need, your pending and accepted offers will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 88.0),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offerDoc = offers[index];
            final data = offerDoc.data();
            final String status = data['status'] ?? 'pending';
            final int offeredUnits = data['offeredUnits'] ?? 1;
            final String donorBloodType = data['donorBloodType'] ?? '';
            final Timestamp? time = data['offerTimestamp'] as Timestamp?;
            final String? parentRequestId = data['requestId']?.toString();

            Color statusBg;
            Color statusColor;
            String statusText;

            switch (status.toLowerCase()) {
              case 'accepted':
                statusBg = AppColors.successLight;
                statusColor = AppColors.success;
                statusText = 'Accepted 🎉';
                break;
              case 'rejected':
              case 'rejected_auto':
                statusBg = AppColors.criticalLight;
                statusColor = AppColors.critical;
                statusText = 'Declined';
                break;
              case 'withdrawn':
                statusBg = AppColors.surfaceMuted;
                statusColor = AppColors.textMuted;
                statusText = 'Withdrawn';
                break;
              default:
                statusBg = AppColors.warningLight;
                statusColor = AppColors.warningDark;
                statusText = 'Pending Decision';
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                              Text(
                                "Offered $offeredUnits Unit(s)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Submitted ${_formatTimestamp(time)}",
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (parentRequestId != null)
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                            label: const Text("View Request"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RequestDetailsPage(requestId: parentRequestId),
                                ),
                              );
                            },
                          )
                        else
                          const SizedBox.shrink(),
                        if (status.toLowerCase() == 'pending' && parentRequestId != null)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.critical,
                              side: const BorderSide(color: AppColors.critical),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Withdraw Offer?"),
                                  content: const Text("Are you sure you want to withdraw this donation offer?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep")),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text("Withdraw"),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _requestService.withdrawOffer(parentRequestId, offerDoc.id);
                              }
                            },
                            child: const Text("Withdraw", style: TextStyle(fontSize: 12)),
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
}
