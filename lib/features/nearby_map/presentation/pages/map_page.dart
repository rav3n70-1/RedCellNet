// lib/features/nearby_map/presentation/pages/map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';
import 'package:red_cell_net_final/features/donation_centers/data/services/donation_center_service.dart';

const LatLng kDefaultCenter = LatLng(23.8103, 90.4125); // Default Dhaka, fallback
const double kDefaultZoom = 13.5;

enum MapFilterType { all, emergencies, donationCenters }
enum MapTileStyle { standard, cleanLight }

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RequestService _requestService = RequestService();
  final DonationCenterService _donationCenterService = DonationCenterService();

  LatLng _currentMapCenter = kDefaultCenter;
  LatLng? _userLocation;
  bool _isLoading = true;
  bool _permissionGranted = false;
  String? _errorMessage;

  // View Mode: Map or List
  bool _isListView = false;

  // Filters & State
  MapFilterType _filterType = MapFilterType.all;
  MapTileStyle _tileStyle = MapTileStyle.standard;
  String? _bloodTypeFilter;
  double? _maxRadiusKm; // null = All, 2, 5, 10, 25
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selected item preview
  Map<String, dynamic>? _selectedEmergency;
  String? _selectedEmergencyId;
  DonationCenter? _selectedCenter;

  final List<String> _bloodTypes = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<double?> _radiusOptions = [null, 2.0, 5.0, 10.0, 25.0];

  @override
  void initState() {
    super.initState();
    _checkPermissionAndGetLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    PermissionStatus status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    LatLng center = kDefaultCenter;
    bool permissionOk = false;
    String? errorMsg;

    if (status.isGranted) {
      permissionOk = true;
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
        center = LatLng(position.latitude, position.longitude);
        _userLocation = center;
      } on LocationServiceDisabledException {
        errorMsg = "Location services disabled on device.";
        permissionOk = false;
      } on TimeoutException {
        errorMsg = "Location fetch timed out. Using default center.";
      } catch (e) {
        errorMsg = "Could not fetch current location.";
      }
    } else {
      permissionOk = false;
      errorMsg = status.isPermanentlyDenied
          ? "Location permission permanently denied. Enable in settings."
          : "Location permission denied.";
    }

    if (mounted) {
      setState(() {
        _currentMapCenter = center;
        _permissionGranted = permissionOk;
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      _animatedMove(center, kDefaultZoom);
    }
  }

  void _animatedMove(LatLng destLocation, double destZoom) {
    try {
      _mapController.move(destLocation, destZoom);
    } catch (e) {
      debugPrint("Map move exception: $e");
    }
  }

  void _recenterOnUser() {
    if (_userLocation != null) {
      _animatedMove(_userLocation!, 15.0);
    } else {
      _checkPermissionAndGetLocation();
    }
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _animatedMove(_mapController.camera.center, (currentZoom + 1).clamp(3.0, 18.0));
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _animatedMove(_mapController.camera.center, (currentZoom - 1).clamp(3.0, 18.0));
    } catch (_) {}
  }

  String get _tileUrl {
    switch (_tileStyle) {
      case MapTileStyle.cleanLight:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
      case MapTileStyle.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  double _computeDistanceKm(LatLng target) {
    if (_userLocation == null) return double.infinity;
    return Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          target.latitude,
          target.longitude,
        ) /
        1000.0;
  }

  String _formatDistance(LatLng target) {
    if (_userLocation == null) return '';
    final km = _computeDistanceKm(target);
    if (km < 1.0) {
      return '${(km * 1000).toInt()} m away';
    }
    return '${km.toStringAsFixed(1)} km away';
  }

  Future<void> _launchNavigation(double lat, double lng, String label) async {
    final Uri uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch map intent';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open external map: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  LatLng? _extractCoords(dynamic coords) {
    if (coords == null) return null;
    if (coords is LatLng) return coords;
    if (coords is GeoPoint) return LatLng(coords.latitude, coords.longitude);
    if (coords is Map) {
      final lat = coords['latitude'] ?? coords['lat'];
      final lng = coords['longitude'] ?? coords['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: StreamBuilder<AppQuerySnapshot>(
        stream: _requestService.getBloodRequestsStream(
          bloodTypeFilter: _bloodTypeFilter,
        ),
        builder: (context, requestSnapshot) {
          return StreamBuilder<List<DonationCenter>>(
            stream: _donationCenterService.getDonationCentersStream(),
            builder: (context, centerSnapshot) {
              final requests = requestSnapshot.data?.docs ?? [];
              final centers = centerSnapshot.data ?? [];

              // Filter Requests by radius and query
              final filteredRequests = requests.where((doc) {
                final data = doc.data();
                final coords = data['hospitalCoords'] ?? data['locationCoords'];
                final latLng = _extractCoords(coords);
                if (latLng != null && _maxRadiusKm != null && _userLocation != null) {
                  final dist = _computeDistanceKm(latLng);
                  if (dist > _maxRadiusKm!) return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final hospital = (data['hospitalName'] ?? '').toString().toLowerCase();
                  final address = (data['hospitalAddress'] ?? '').toString().toLowerCase();
                  final blood = (data['requiredBloodType'] ?? '').toString().toLowerCase();
                  if (!hospital.contains(_searchQuery) &&
                      !address.contains(_searchQuery) &&
                      !blood.contains(_searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              // Filter Centers by radius and query
              final filteredCenters = centers.where((center) {
                if (_maxRadiusKm != null && _userLocation != null) {
                  final dist = _computeDistanceKm(center.coordinates);
                  if (dist > _maxRadiusKm!) return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final name = center.name.toLowerCase();
                  final addr = center.address.toLowerCase();
                  if (!name.contains(_searchQuery) && !addr.contains(_searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              final markers = _buildMarkers(filteredRequests, filteredCenters);

              return Stack(
                children: [
                  // --- Body: Map View or List View ---
                  if (_isListView)
                    _buildListView(filteredRequests, filteredCenters)
                  else
                    _buildFlutterMap(markers),

                  // --- Header: Search Bar, View Toggle, Filter Tabs & Radius Chips ---
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBarRow(),
                        const SizedBox(height: 8),
                        _buildFilterTabs(filteredRequests.length, filteredCenters.length),
                        const SizedBox(height: 6),
                        _buildRadiusChips(),
                      ],
                    ),
                  ),

                  // --- Map Controls (Only in Map View) ---
                  if (!_isListView)
                    Positioned(
                      right: 14,
                      bottom: (_selectedEmergency != null || _selectedCenter != null) ? 230 : 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapControlBtn(
                            icon: Icons.layers_outlined,
                            tooltip: 'Switch Map Style',
                            onTap: () {
                              setState(() {
                                _tileStyle = _tileStyle == MapTileStyle.standard
                                    ? MapTileStyle.cleanLight
                                    : MapTileStyle.standard;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildMapControlBtn(
                            icon: Icons.add_rounded,
                            tooltip: 'Zoom In',
                            onTap: _zoomIn,
                          ),
                          const SizedBox(height: 8),
                          _buildMapControlBtn(
                            icon: Icons.remove_rounded,
                            tooltip: 'Zoom Out',
                            onTap: _zoomOut,
                          ),
                          const SizedBox(height: 8),
                          _buildMapControlBtn(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Center on Me',
                            iconColor: AppColors.primary,
                            onTap: _recenterOnUser,
                          ),
                        ],
                      ),
                    ),

                  // --- Bottom Floating Preview Sheet for Selected Pin (Map View only) ---
                  if (!_isListView && _selectedEmergency != null)
                    Positioned(
                      bottom: 16,
                      left: 14,
                      right: 14,
                      child: _buildEmergencyPreviewCard(_selectedEmergency!, _selectedEmergencyId!),
                    )
                  else if (!_isListView && _selectedCenter != null)
                    Positioned(
                      bottom: 16,
                      left: 14,
                      right: 14,
                      child: _buildCenterPreviewCard(_selectedCenter!),
                    ),

                  // --- Loading Overlay ---
                  if (_isLoading)
                    Container(
                      color: Colors.white.withValues(alpha: 0.75),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Locating nearby facilities...',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                  // --- Location Permission Banner ---
                  if (!_isLoading && !_permissionGranted && _errorMessage != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 160,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_off_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => openAppSettings(),
                              child: const Text('Enable',
                                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFlutterMap(List<Marker> markers) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentMapCenter,
        initialZoom: kDefaultZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        onTap: (_, __) {
          if (_selectedEmergency != null || _selectedCenter != null) {
            setState(() {
              _selectedEmergency = null;
              _selectedEmergencyId = null;
              _selectedCenter = null;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl,
          userAgentPackageName: 'org.redcellnet.app',
        ),
        MarkerLayer(
          markers: [
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ...markers,
          ],
        ),
      ],
    );
  }

  List<Marker> _buildMarkers(
    List<AppDocSnapshot> requestDocs,
    List<DonationCenter> centers,
  ) {
    List<Marker> list = [];

    if (_filterType == MapFilterType.all || _filterType == MapFilterType.emergencies) {
      for (var doc in requestDocs) {
        final data = doc.data();
        final dynamic coordsData = data['hospitalCoords'] ?? data['locationCoords'];
        final latLng = _extractCoords(coordsData);

        if (latLng != null) {
          final String bloodType = data['requiredBloodType'] ?? 'N/A';
          final String urgency = data['urgencyLevel'] ?? 'High';
          final bool isSelected = _selectedEmergencyId == doc.id;

          list.add(
            Marker(
              point: latLng,
              width: 54,
              height: 54,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmergency = data;
                    _selectedEmergencyId = doc.id;
                    _selectedCenter = null;
                  });
                  _animatedMove(latLng, 15.0);
                },
                child: AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildEmergencyPinWidget(bloodType, urgency, isSelected),
                ),
              ),
            ),
          );
        }
      }
    }

    if (_filterType == MapFilterType.all || _filterType == MapFilterType.donationCenters) {
      for (var center in centers) {
        final latLng = center.coordinates;
        final bool isSelected = _selectedCenter?.id == center.id;

        list.add(
          Marker(
            point: latLng,
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCenter = center;
                  _selectedEmergency = null;
                  _selectedEmergencyId = null;
                });
                _animatedMove(latLng, 15.0);
              },
              child: AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: _buildCenterPinWidget(center.name, isSelected),
              ),
            ),
          ),
        );
      }
    }

    return list;
  }

  Widget _buildEmergencyPinWidget(String bloodType, String urgency, bool isSelected) {
    final Color pinColor = urgency == 'Critical' ? AppColors.critical : AppColors.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              bloodType,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: urgency == 'Critical' ? Colors.amber : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: pinColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterPinWidget(String name, bool isSelected) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.secondaryDark : AppColors.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSearchBarRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'Search hospital, center, blood group...',
                hintStyle: const TextStyle(fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Map / List Toggle Button
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isListView = false),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isListView ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      size: 16,
                      color: !_isListView ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isListView = true),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isListView ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 16,
                      color: _isListView ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int emergenciesCount, int centersCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All (${emergenciesCount + centersCount})',
            isSelected: _filterType == MapFilterType.all,
            onSelected: () => setState(() => _filterType = MapFilterType.all),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Emergencies ($emergenciesCount)',
            icon: Icons.emergency_rounded,
            badgeColor: AppColors.critical,
            isSelected: _filterType == MapFilterType.emergencies,
            onSelected: () => setState(() => _filterType = MapFilterType.emergencies),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Centers ($centersCount)',
            icon: Icons.local_hospital_rounded,
            badgeColor: AppColors.secondary,
            isSelected: _filterType == MapFilterType.donationCenters,
            onSelected: () => setState(() => _filterType = MapFilterType.donationCenters),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _bloodTypeFilter != null && _bloodTypeFilter != 'All'
                    ? AppColors.primary
                    : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _bloodTypeFilter ?? 'All',
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                items: _bloodTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type == 'All' ? 'Group: Any' : 'Group: $type'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _bloodTypeFilter = val == 'All' ? null : val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Radius Distance Filter Chips (All, 2 km, 5 km, 10 km, 25 km) ---
  Widget _buildRadiusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _radiusOptions.map((radius) {
          final isSelected = _maxRadiusKm == radius;
          final label = radius == null ? 'Distance: All' : 'Within ${radius.toInt()} km';

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              onSelected: (selected) {
                setState(() => _maxRadiusKm = selected ? radius : null);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
    Color? badgeColor,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : (badgeColor ?? AppColors.primary)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, size: 22, color: iconColor ?? AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  // --- List View Mode (Sorted by Proximity) ---
  Widget _buildListView(
    List<AppDocSnapshot> requestDocs,
    List<DonationCenter> centers,
  ) {
    // Proximity item wrapper
    final List<Map<String, dynamic>> allItems = [];

    if (_filterType == MapFilterType.all || _filterType == MapFilterType.emergencies) {
      for (var doc in requestDocs) {
        final data = doc.data();
        final dynamic coords = data['hospitalCoords'] ?? data['locationCoords'];
        final LatLng? loc = _extractCoords(coords);
        allItems.add({
          'type': 'emergency',
          'id': doc.id,
          'data': data,
          'location': loc,
          'distance': loc != null ? _computeDistanceKm(loc) : double.infinity,
        });
      }
    }

    if (_filterType == MapFilterType.all || _filterType == MapFilterType.donationCenters) {
      for (var center in centers) {
        allItems.add({
          'type': 'center',
          'id': center.id,
          'center': center,
          'location': center.coordinates,
          'distance': _computeDistanceKm(center.coordinates),
        });
      }
    }

    // Sort by proximity
    allItems.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 130, 16, 24),
      children: [
        // Privacy Notice Banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: AppColors.secondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Privacy protected: Showing hospital facilities and public blood banks only.',
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryDark, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        if (allItems.isEmpty)
          const EmptyStateView(
            icon: Icons.location_off_rounded,
            title: 'No Facilities in this Range',
            message: 'Try increasing the distance radius or resetting your search filters.',
          ),

        ...allItems.map((item) {
          if (item['type'] == 'emergency') {
            final data = item['data'] as Map<String, dynamic>;
            final id = item['id'] as String;
            final blood = data['requiredBloodType'] ?? '';
            final urgency = data['urgencyLevel'] ?? 'Critical';
            final hospital = data['hospitalName'] ?? 'Hospital';
            final address = data['hospitalAddress'] ?? '';
            final units = data['unitsNeeded'] ?? 1;
            final LatLng? loc = item['location'];
            final distStr = loc != null ? _formatDistance(loc) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodGroupBadge(bloodType: blood, size: 44, showGlow: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UrgencyChip(urgency: urgency, compact: true),
                                const SizedBox(width: 6),
                                Text(
                                  '$units Unit(s)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                                const Spacer(),
                                if (distStr.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      distStr,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hospital,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (loc != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.directions_rounded, size: 16),
                            label: const Text('Directions'),
                            onPressed: () => _launchNavigation(loc.latitude, loc.longitude, hospital),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                          ),
                        ),
                      if (loc != null) const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('View Request'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RequestDetailsPage(requestId: id)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            final center = item['center'] as DonationCenter;
            final distStr = _formatDistance(center.coordinates);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.secondaryLight, width: 1.5),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.local_hospital_rounded, color: AppColors.secondary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('BLOOD BANK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success)),
                                ),
                                const Spacer(),
                                if (distStr.isNotEmpty)
                                  Text(distStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(center.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(center.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (center.operatingHours != null) ...[
                    const SizedBox(height: 4),
                    Text('Hours: ${center.operatingHours}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: const Text('Navigate to Center'),
                      onPressed: () => _launchNavigation(center.coordinates.latitude, center.coordinates.longitude, center.name),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
              ),
            );
          }
        }),
      ],
    );
  }

  // --- Bottom Floating Preview Sheet for Emergencies (Map View) ---
  Widget _buildEmergencyPreviewCard(Map<String, dynamic> data, String requestId) {
    final bloodType = data['requiredBloodType'] ?? 'N/A';
    final hospital = data['hospitalName'] ?? 'Hospital';
    final address = data['hospitalAddress'] ?? '';
    final urgency = data['urgencyLevel'] ?? 'Critical';
    final units = data['unitsNeeded'] ?? 1;

    final coords = data['hospitalCoords'] ?? data['locationCoords'];
    final LatLng? loc = _extractCoords(coords);
    final distanceStr = loc != null ? _formatDistance(loc) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: urgency == 'Critical' ? AppColors.critical : AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BloodGroupBadge(bloodType: bloodType, size: 48, showGlow: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UrgencyChip(urgency: urgency, compact: true),
                        const SizedBox(width: 6),
                        Text(
                          '$units Unit(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hospital,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedEmergency = null;
                    _selectedEmergencyId = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (distanceStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    distanceStr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (loc != null)
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text('Directions'),
                    onPressed: () => _launchNavigation(loc.latitude, loc.longitude, hospital),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (loc != null) const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequestDetailsPage(requestId: requestId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View Request & Help'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Bottom Floating Preview Sheet for Donation Centers (Map View) ---
  Widget _buildCenterPreviewCard(DonationCenter center) {
    final distanceStr = _formatDistance(center.coordinates);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.secondaryLight, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                              SizedBox(width: 3),
                              Text(
                                'VERIFIED CENTER',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (distanceStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            distanceStr,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      center.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  setState(() => _selectedCenter = null);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  center.address,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (center.operatingHours != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Hours: ${center.operatingHours}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchNavigation(center.coordinates.latitude, center.coordinates.longitude, center.name),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.directions_rounded, size: 16),
              label: const Text('Directions to Blood Bank'),
            ),
          ),
        ],
      ),
    );
  }
}
