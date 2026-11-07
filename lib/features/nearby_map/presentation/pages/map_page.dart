// lib/features/nearby_map/presentation/pages/map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/supabase_profile_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';
import 'package:red_cell_net_final/features/donation_centers/data/services/donation_center_service.dart';
import 'package:url_launcher/url_launcher.dart';

const LatLng kDefaultCenter = LatLng(23.8103, 90.4125); // Dhaka default center
const double kDefaultZoom = 13.5;

enum MapFilterType { all, emergencies, donationCenters }
enum MapTileStyle { auto, cleanVoyager, darkMatter, openStreetMap }

class _MapPinEntry {
  final LatLng point;
  final AppDocSnapshot? requestDoc;
  final DonationCenter? center;

  const _MapPinEntry.emergency({
    required this.point,
    required AppDocSnapshot doc,
  })  : requestDoc = doc,
        center = null;

  const _MapPinEntry.facility({
    required this.point,
    required DonationCenter facility,
  })  : center = facility,
        requestDoc = null;

  bool get isEmergency => requestDoc != null;
}

class _MapPinCluster {
  final LatLng anchor;
  final List<_MapPinEntry> entries;

  _MapPinCluster({required this.anchor, required this.entries});
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RequestService _requestService = RequestService();
  final DonationCenterService _donationCenterService = DonationCenterService();
  final SupabaseProfileService _profileService = SupabaseProfileService();

  late Stream<AppQuerySnapshot> _requestsStream;
  late Stream<List<DonationCenter>> _centersStream;

  final LatLng _currentMapCenter = kDefaultCenter;
  LatLng? _userLocation;
  String? _statusBanner;

  // View Mode: Map or List
  bool _isListView = false;

  // Privacy-safe donor availability clusters (~2km coarse zones, zero PII)
  bool _showDonorZones = true;
  List<Map<String, dynamic>> _donorClusters = const [];

  // Filters & State
  MapFilterType _filterType = MapFilterType.all;
  MapTileStyle _tileStyle = MapTileStyle.auto;
  String? _bloodTypeFilter;
  double? _maxRadiusKm; // null = All, 2, 5, 10, 25
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selected item preview
  Map<String, dynamic>? _selectedEmergency;
  String? _selectedEmergencyId;
  DonationCenter? _selectedCenter;

  final List<String> _bloodTypes = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];
  final List<double?> _radiusOptions = [null, 2.0, 5.0, 10.0, 25.0];

  @override
  void initState() {
    super.initState();
    _requestsStream = _requestService.getBloodRequestsStream(
      bloodTypeFilter: _bloodTypeFilter,
    );
    _centersStream = _donationCenterService.getDonationCentersStream();
    _initUserLocation();
    _loadDonorClusters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDonorClusters() async {
    final anchor = _userLocation ?? _currentMapCenter;
    final clusters = await _profileService.getAvailableDonorClusters(
      lat: anchor.latitude,
      lng: anchor.longitude,
      radiusKm: _maxRadiusKm ?? 25.0,
      bloodType: _bloodTypeFilter,
    );
    if (mounted) {
      setState(() {
        _donorClusters = clusters;
      });
    }
  }

  Future<void> _initUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _statusBanner =
                'Location access disabled. Showing general city map — tap Retry to enable GPS.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      final center = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _userLocation = center;
          _statusBanner = null;
        });
        _animatedMove(center, 14.0);
        _loadDonorClusters();
      }
    } catch (e) {
      debugPrint('Auto GPS detection note: $e');
    }
  }

  void _animatedMove(LatLng destLocation, double destZoom) {
    try {
      _mapController.move(destLocation, destZoom);
    } catch (e) {
      debugPrint('Map move note: $e');
    }
  }

  void _recenterOnUser() {
    if (_userLocation != null) {
      _animatedMove(_userLocation!, 15.0);
    } else {
      _initUserLocation();
    }
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _animatedMove(
        _mapController.camera.center,
        (currentZoom + 1).clamp(3.0, 18.0),
      );
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _animatedMove(
        _mapController.camera.center,
        (currentZoom - 1).clamp(3.0, 18.0),
      );
    } catch (_) {}
  }

  String _getTileUrl(BuildContext context) {
    final isDark = AppColors.isDark(context);
    switch (_tileStyle) {
      case MapTileStyle.darkMatter:
        return 'https://a.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png';
      case MapTileStyle.cleanVoyager:
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case MapTileStyle.openStreetMap:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapTileStyle.auto:
        return isDark
            ? 'https://a.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'
            : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    }
  }

  double _computeDistanceKm(LatLng target) {
    final origin = _userLocation ?? _currentMapCenter;
    return Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          target.latitude,
          target.longitude,
        ) /
        1000.0;
  }

  String _formatDistance(LatLng target) {
    if (_userLocation == null) return '';
    final km = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          target.latitude,
          target.longitude,
        ) /
        1000.0;
    if (km < 1.0) {
      return '${(km * 1000).toInt()} m away';
    }
    return '${km.toStringAsFixed(1)} km away';
  }

  Future<void> _launchNavigation(double lat, double lng, String label) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
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
    if (coords is LatLng) {
      if (coords.latitude == 0.0 && coords.longitude == 0.0) return null;
      return coords;
    }
    if (coords is GeoPoint) {
      if (coords.latitude == 0.0 && coords.longitude == 0.0) return null;
      return LatLng(coords.latitude, coords.longitude);
    }
    if (coords is Map) {
      final lat = coords['latitude'] ?? coords['lat'];
      final lng = coords['longitude'] ?? coords['lng'];
      if (lat != null && lng != null) {
        final dLat = double.tryParse(lat.toString());
        final dLng = double.tryParse(lng.toString());
        if (dLat != null && dLng != null && (dLat != 0.0 || dLng != 0.0)) {
          return LatLng(dLat, dLng);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: StreamBuilder<AppQuerySnapshot>(
        stream: _requestsStream,
        builder: (context, requestSnapshot) {
          return StreamBuilder<List<DonationCenter>>(
            stream: _centersStream,
            builder: (context, centerSnapshot) {
              final requests = requestSnapshot.data?.docs ?? [];
              final centers = centerSnapshot.data ?? [];

              // Filter Requests by radius and query
              final filteredRequests = requests.where((doc) {
                final data = doc.data();
                final coords = data['hospitalCoords'] ??
                    data['locationCoords'] ??
                    data['location_coords'] ??
                    data['hospital_coords'];
                final latLng = _extractCoords(coords);
                if (_maxRadiusKm != null) {
                  if (latLng == null) return false;
                  final dist = _computeDistanceKm(latLng);
                  if (dist > _maxRadiusKm!) return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final hospital =
                      (data['hospitalName'] ?? '').toString().toLowerCase();
                  final address =
                      (data['hospitalAddress'] ?? '').toString().toLowerCase();
                  final city = (data['city'] ?? '').toString().toLowerCase();
                  final blood =
                      (data['requiredBloodType'] ?? '').toString().toLowerCase();
                  if (!hospital.contains(_searchQuery) &&
                      !address.contains(_searchQuery) &&
                      !city.contains(_searchQuery) &&
                      !blood.contains(_searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              // Filter Centers by radius, blood group stock (if selected), and query
              final filteredCenters = centers.where((center) {
                if (_maxRadiusKm != null) {
                  if (!center.hasValidCoordinates) return false;
                  final dist = _computeDistanceKm(center.coordinates);
                  if (dist > _maxRadiusKm!) return false;
                }
                if (_bloodTypeFilter != null && _bloodTypeFilter != 'All') {
                  final inv = center.bloodInventory;
                  if (inv != null && inv.isNotEmpty) {
                    final qty = int.tryParse(
                            (inv[_bloodTypeFilter] ?? '0').toString()) ??
                        0;
                    if (qty <= 0) return false;
                  }
                }
                if (_searchQuery.isNotEmpty) {
                  final name = center.name.toLowerCase();
                  final addr = center.address.toLowerCase();
                  final city = (center.city ?? '').toLowerCase();
                  final type = center.facilityType.toLowerCase();
                  if (!name.contains(_searchQuery) &&
                      !addr.contains(_searchQuery) &&
                      !city.contains(_searchQuery) &&
                      !type.contains(_searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              final markers =
                  _buildClusteredMarkers(filteredRequests, filteredCenters);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _isListView
                        ? _buildListView(filteredRequests, filteredCenters)
                        : _buildFlutterMap(markers),
                  ),

                  // Header Controls
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBarRow(),
                        const SizedBox(height: 8),
                        _buildFilterTabs(
                            filteredRequests.length, filteredCenters.length),
                        const SizedBox(height: 6),
                        _buildRadiusChips(),
                      ],
                    ),
                  ),

                  // Map Control Floating Buttons
                  if (!_isListView)
                    Positioned(
                      right: 14,
                      bottom:
                          (_selectedEmergency != null || _selectedCenter != null)
                              ? 248
                              : 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapControlBtn(
                            icon: Icons.layers_outlined,
                            tooltip:
                                'Cycle Map Style (Auto / Voyager / Dark / OSM)',
                            onTap: () {
                              setState(() {
                                if (_tileStyle == MapTileStyle.auto) {
                                  _tileStyle = MapTileStyle.cleanVoyager;
                                } else if (_tileStyle ==
                                    MapTileStyle.cleanVoyager) {
                                  _tileStyle = MapTileStyle.darkMatter;
                                } else if (_tileStyle ==
                                    MapTileStyle.darkMatter) {
                                  _tileStyle = MapTileStyle.openStreetMap;
                                } else {
                                  _tileStyle = MapTileStyle.auto;
                                }
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

                  // Selected Item Bottom Sheet Preview
                  if (!_isListView && _selectedEmergency != null)
                    Positioned(
                      bottom: 16,
                      left: 14,
                      right: 14,
                      child: _buildEmergencyPreviewCard(
                          _selectedEmergency!, _selectedEmergencyId!),
                    )
                  else if (!_isListView && _selectedCenter != null)
                    Positioned(
                      bottom: 16,
                      left: 14,
                      right: 14,
                      child: _buildCenterPreviewCard(_selectedCenter!),
                    ),

                  // Non-blocking GPS Banner
                  if (_statusBanner != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 162,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_off_rounded,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusBanner!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: _initUserLocation,
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
    final List<CircleMarker> zoneCircles = [];
    final List<Marker> zoneBadgeMarkers = [];

    if (_showDonorZones) {
      for (final cluster in _donorClusters) {
        final lat = double.tryParse((cluster['coarse_lat'] ?? '').toString());
        final lng = double.tryParse((cluster['coarse_lng'] ?? '').toString());
        final count =
            int.tryParse((cluster['donor_count'] ?? '0').toString()) ?? 0;
        final verifiedCount =
            int.tryParse((cluster['verified_count'] ?? '0').toString()) ?? 0;
        final areaLabel = (cluster['area_label'] ?? 'Local Area').toString();

        if (lat != null &&
            lng != null &&
            (lat != 0.0 || lng != 0.0) &&
            count > 0) {
          final centerPoint = LatLng(lat, lng);
          zoneCircles.add(
            CircleMarker(
              point: centerPoint,
              radius: 1350, // ~1.35 km coarse anonymized availability zone
              useRadiusInMeter: true,
              color: AppColors.success.withValues(alpha: 0.11),
              borderColor: AppColors.success.withValues(alpha: 0.36),
              borderStrokeWidth: 1.5,
            ),
          );
          zoneBadgeMarkers.add(
            Marker(
              point: centerPoint,
              width: 118,
              height: 30,
              child: GestureDetector(
                onTap: () => _showDonorZonePrivacySheet(
                  areaLabel: areaLabel,
                  donorCount: count,
                  verifiedCount: verifiedCount,
                  bloodTypes: cluster['blood_types'],
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_moon_rounded,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '~$count Ready',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentMapCenter,
        initialZoom: kDefaultZoom,
        minZoom: 3.0,
        maxZoom: 19.0,
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
          urlTemplate: _getTileUrl(context),
          userAgentPackageName: 'com.example.red_cell_net',
          maxZoom: 19,
        ),
        if (zoneCircles.isNotEmpty) CircleLayer(circles: zoneCircles),
        if (zoneBadgeMarkers.isNotEmpty) MarkerLayer(markers: zoneBadgeMarkers),
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
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.4),
                            blurRadius: 6,
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
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap & CARTO'),
          alignment: Alignment.bottomLeft,
        ),
      ],
    );
  }

  List<Marker> _buildClusteredMarkers(
    List<AppDocSnapshot> requests,
    List<DonationCenter> centers,
  ) {
    final List<_MapPinEntry> rawEntries = [];

    if (_filterType == MapFilterType.all ||
        _filterType == MapFilterType.emergencies) {
      for (final req in requests) {
        final data = req.data();
        final coords = data['hospitalCoords'] ??
            data['locationCoords'] ??
            data['location_coords'] ??
            data['hospital_coords'];
        final latLng = _extractCoords(coords);
        if (latLng != null) {
          rawEntries.add(_MapPinEntry.emergency(point: latLng, doc: req));
        }
      }
    }

    if (_filterType == MapFilterType.all ||
        _filterType == MapFilterType.donationCenters) {
      for (final center in centers) {
        if (center.hasValidCoordinates) {
          rawEntries.add(
            _MapPinEntry.facility(
                point: center.coordinates, facility: center),
          );
        }
      }
    }

    // Group pins within ~60 meters to prevent overlapping co-located hospital pins
    final List<_MapPinCluster> clusters = [];
    for (final entry in rawEntries) {
      _MapPinCluster? matched;
      for (final cluster in clusters) {
        final distMeters = Geolocator.distanceBetween(
          cluster.anchor.latitude,
          cluster.anchor.longitude,
          entry.point.latitude,
          entry.point.longitude,
        );
        if (distMeters <= 60.0) {
          matched = cluster;
          break;
        }
      }
      if (matched != null) {
        matched.entries.add(entry);
      } else {
        clusters.add(_MapPinCluster(anchor: entry.point, entries: [entry]));
      }
    }

    final List<Marker> markers = [];
    for (final cluster in clusters) {
      if (cluster.entries.length == 1) {
        final item = cluster.entries.first;
        if (item.isEmergency) {
          final req = item.requestDoc!;
          final data = req.data();
          final String bloodType = data['requiredBloodType'] ?? '?';
          final String urgency = data['urgencyLevel'] ?? 'Critical';
          final bool isSelected = _selectedEmergencyId == req.id;

          markers.add(
            Marker(
              point: item.point,
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmergency = data;
                    _selectedEmergencyId = req.id;
                    _selectedCenter = null;
                  });
                  _animatedMove(item.point, 15.0);
                },
                child: AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildEmergencyPinWidget(bloodType, urgency, isSelected),
                ),
              ),
            ),
          );
        } else {
          final center = item.center!;
          final bool isSelected = _selectedCenter?.id == center.id;
          markers.add(
            Marker(
              point: item.point,
              width: 48,
              height: 48,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCenter = center;
                    _selectedEmergency = null;
                    _selectedEmergencyId = null;
                  });
                  _animatedMove(item.point, 15.0);
                },
                child: AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildCenterPinWidget(center, isSelected),
                ),
              ),
            ),
          );
        }
      } else {
        final hasEmergency = cluster.entries.any((e) => e.isEmergency);
        final count = cluster.entries.length;
        markers.add(
          Marker(
            point: cluster.anchor,
            width: 54,
            height: 54,
            child: GestureDetector(
              onTap: () => _showClusterPickerSheet(cluster),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: hasEmergency
                          ? AppColors.critical
                          : AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: (hasEmergency
                                  ? AppColors.critical
                                  : AppColors.secondary)
                              .withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        hasEmergency
                            ? Icons.emergency_rounded
                            : Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
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
    }

    return markers;
  }

  void _showClusterPickerSheet(_MapPinCluster cluster) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderOf(ctx),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${cluster.entries.length} Items at This Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(ctx),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select an emergency request or blood center below:',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cluster.entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final entry = cluster.entries[idx];
                      if (entry.isEmergency) {
                        final req = entry.requestDoc!;
                        final data = req.data();
                        final blood =
                            (data['requiredBloodType'] ?? '?').toString();
                        final hospital =
                            (data['hospitalName'] ?? 'Hospital').toString();
                        final urgency =
                            (data['urgencyLevel'] ?? 'Critical').toString();
                        final remaining =
                            data['remainingUnits'] ?? data['requiredUnits'] ?? 1;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.borderOf(ctx)),
                          ),
                          leading: BloodGroupBadge(bloodType: blood, size: 40),
                          title: Text(
                            hospital,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimaryOf(ctx),
                            ),
                          ),
                          subtitle: Text(
                            '$urgency • $remaining unit(s) needed',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedEmergency = data;
                              _selectedEmergencyId = req.id;
                              _selectedCenter = null;
                            });
                            _animatedMove(entry.point, 15.5);
                          },
                        );
                      } else {
                        final center = entry.center!;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.borderOf(ctx)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.secondary.withValues(alpha: 0.14),
                            child: const Icon(Icons.local_hospital_rounded,
                                color: AppColors.secondary, size: 20),
                          ),
                          title: Text(
                            center.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimaryOf(ctx),
                            ),
                          ),
                          subtitle: Text(
                            '${center.facilityType} • ${center.operationalStatus}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCenter = center;
                              _selectedEmergency = null;
                              _selectedEmergencyId = null;
                            });
                            _animatedMove(entry.point, 15.5);
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDonorZonePrivacySheet({
    required String areaLabel,
    required int donorCount,
    required int verifiedCount,
    dynamic bloodTypes,
  }) {
    final List<String> groups = bloodTypes is List
        ? bloodTypes.map((e) => e.toString()).toList()
        : const <String>[];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_moon_rounded,
                        color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$areaLabel Availability Zone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(ctx),
                          ),
                        ),
                        Text(
                          '~$donorCount eligible donor(s) ready ($verifiedCount lab-verified)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: groups
                      .map(
                        (g) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mutedOf(ctx),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderOf(ctx)),
                ),
                child: Text(
                  'Privacy Protected: Exact donor home coordinates and phone numbers are never shown on public maps. Post a verified blood request to automatically alert compatible donors in this ~2 km zone.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyPinWidget(
      String bloodType, String urgency, bool isSelected) {
    final Color pinColor =
        urgency == 'Critical' ? AppColors.critical : AppColors.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
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

  Widget _buildCenterPinWidget(DonationCenter center, bool isSelected) {
    final isClosed =
        center.operationalStatus.toLowerCase().contains('closed');
    final baseColor = isClosed ? AppColors.textMuted : AppColors.secondary;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.secondaryDark : baseColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSearchBarRow() {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
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
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: AppSettingsService().tr('search_map_hint') ==
                        'search_map_hint'
                    ? 'Search hospital, center, city, blood group...'
                    : AppSettingsService().tr('search_map_hint'),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMutedOf(context),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            size: 16,
                            color: AppColors.textSecondaryOf(context)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.mutedOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isListView = false),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          !_isListView ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      size: 16,
                      color: !_isListView
                          ? Colors.white
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isListView = true),
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(10)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _isListView ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 16,
                      color: _isListView
                          ? Colors.white
                          : AppColors.textSecondaryOf(context),
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
    final totalReadyDonors = _donorClusters.fold<int>(
      0,
      (sum, c) =>
          sum + (int.tryParse((c['donor_count'] ?? '0').toString()) ?? 0),
    );

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
            onSelected: () =>
                setState(() => _filterType = MapFilterType.emergencies),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Centers ($centersCount)',
            icon: Icons.local_hospital_rounded,
            badgeColor: AppColors.secondary,
            isSelected: _filterType == MapFilterType.donationCenters,
            onSelected: () =>
                setState(() => _filterType = MapFilterType.donationCenters),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Donor Zones ($totalReadyDonors)',
            icon: Icons.shield_moon_rounded,
            badgeColor: AppColors.success,
            isSelected: _showDonorZones,
            onSelected: () =>
                setState(() => _showDonorZones = !_showDonorZones),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _bloodTypeFilter != null && _bloodTypeFilter != 'All'
                    ? AppColors.primary
                    : AppColors.borderOf(context),
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
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: AppColors.primary),
                isDense: true,
                dropdownColor: AppColors.cardBg(context),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
                items: _bloodTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type == 'All' ? 'Group: Any' : 'Group: $type'),
                  );
                }).toList(),
                onChanged: (val) {
                  final next = val == 'All' ? null : val;
                  setState(() {
                    _bloodTypeFilter = next;
                    _requestsStream = _requestService.getBloodRequestsStream(
                      bloodTypeFilter: _bloodTypeFilter,
                    );
                  });
                  _loadDonorClusters();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _radiusOptions.map((radius) {
          final isSelected = _maxRadiusKm == radius;
          final label = radius == null
              ? 'Distance: All'
              : 'Within ${radius.toInt()} km';

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.cardBg(context),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color:
                    isSelected ? Colors.white : AppColors.textPrimaryOf(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.borderOf(context),
                ),
              ),
              onSelected: (selected) {
                setState(() => _maxRadiusKm = selected ? radius : null);
                _loadDonorClusters();
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
    final activeBg = badgeColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? activeBg : AppColors.borderOf(context)),
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
              Icon(icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (badgeColor ?? AppColors.primary)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? Colors.white : AppColors.textPrimaryOf(context),
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
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Icon(icon,
                  size: 22,
                  color: iconColor ?? AppColors.textPrimaryOf(context)),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusBadgeColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('closed')) return AppColors.critical;
    if (lower.contains('limited')) return AppColors.warning;
    return AppColors.success;
  }

  // --- List View Mode ---
  Widget _buildListView(
    List<AppDocSnapshot> requestDocs,
    List<DonationCenter> centers,
  ) {
    final List<Widget> items = [];

    if (_filterType == MapFilterType.all ||
        _filterType == MapFilterType.emergencies) {
      for (final req in requestDocs) {
        final data = req.data();
        final hospital = data['hospitalName'] ?? 'Hospital';
        final address = data['hospitalAddress'] ?? '';
        final blood = data['requiredBloodType'] ?? '';
        final urgency = data['urgencyLevel'] ?? 'Critical';
        final coords = _extractCoords(
            data['hospitalCoords'] ?? data['locationCoords']);

        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
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
                          const Spacer(),
                          if (coords != null && _userLocation != null)
                            Text(
                              _formatDistance(coords),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hospital,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        address,
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
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppColors.primary),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            RequestDetailsPage(requestId: req.id)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (_filterType == MapFilterType.all ||
        _filterType == MapFilterType.donationCenters) {
      for (final center in centers) {
        final statusColor = _statusBadgeColor(center.operationalStatus);
        items.add(
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showCenterDetailsSheet(center),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderOf(context)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_hospital_rounded,
                        color: AppColors.secondary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                center.facilityType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                center.operationalStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_userLocation != null &&
                                center.hasValidCoordinates)
                              Text(
                                _formatDistance(center.coordinates),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                center.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (center.isVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified_rounded,
                                    size: 16, color: AppColors.success),
                              ),
                          ],
                        ),
                        Text(
                          center.address,
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
                  IconButton(
                    icon: const Icon(Icons.directions_rounded,
                        size: 20, color: AppColors.secondary),
                    onPressed: center.hasValidCoordinates
                        ? () => _launchNavigation(
                            center.latitude, center.longitude, center.name)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 154, 16, 24),
      children: items.isEmpty
          ? [
              const EmptyStateView(
                icon: Icons.map_outlined,
                title: 'No Matching Facilities',
                message:
                    'No blood requests or centers match your active filters or radius.',
              ),
            ]
          : items,
    );
  }

  // --- Bottom Floating Preview Sheet for Selected Emergency Pin ---
  Widget _buildEmergencyPreviewCard(
      Map<String, dynamic> data, String requestId) {
    final hospital = data['hospitalName'] ?? 'Hospital';
    final address = data['hospitalAddress'] ?? '';
    final blood = data['requiredBloodType'] ?? '?';
    final component = data['componentType'] ?? 'Whole Blood';
    final urgency = data['urgencyLevel'] ?? 'Critical';
    final remaining = data['remainingUnits'] ?? (data['requiredUnits'] ?? 1);
    final coords =
        _extractCoords(data['hospitalCoords'] ?? data['locationCoords']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BloodGroupBadge(bloodType: blood, size: 48, showGlow: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UrgencyChip(urgency: urgency, compact: true),
                        const SizedBox(width: 6),
                        if (data['isVerifiedHospitalCase'] == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    size: 10, color: Color(0xFF10B981)),
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
                          const SizedBox(width: 6),
                        ],
                        if (coords != null && _userLocation != null)
                          Text(
                            _formatDistance(coords),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hospital,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$component • $address',
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
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() {
                  _selectedEmergency = null;
                  _selectedEmergencyId = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text('Navigate'),
                  onPressed: coords != null
                      ? () => _launchNavigation(
                          coords.latitude, coords.longitude, hospital)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.volunteer_activism_rounded, size: 16),
                  label: Text('Help ($remaining units)'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            RequestDetailsPage(requestId: requestId)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Bottom Floating Preview Sheet for Selected Donation Center Pin ---
  Widget _buildCenterPreviewCard(DonationCenter center) {
    final statusColor = _statusBadgeColor(center.operationalStatus);
    final inv = center.bloodInventory ?? const <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: AppColors.secondary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            center.facilityType,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            center.operationalStatus,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_userLocation != null && center.hasValidCoordinates)
                          Text(
                            _formatDistance(center.coordinates),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            center.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textPrimaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (center.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified_rounded,
                                size: 16, color: AppColors.success),
                          ),
                      ],
                    ),
                    Text(
                      center.operatingHours != null &&
                              center.operatingHours!.trim().isNotEmpty
                          ? '${center.operatingHours} • ${center.address}'
                          : center.address,
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
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _selectedCenter = null),
              ),
            ],
          ),
          if (inv.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: inv.entries.map((entry) {
                  final units = int.tryParse(entry.value.toString()) ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: units > 0
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.mutedOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: units > 0
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.borderOf(context),
                      ),
                    ),
                    child: Text(
                      '${entry.key}: $units',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: units > 0
                            ? AppColors.primary
                            : AppColors.textMutedOf(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call_rounded, size: 15),
                  label: const Text('Call'),
                  onPressed: center.contactInfo != null &&
                          center.contactInfo!.isNotEmpty
                      ? () => launchUrl(Uri.parse('tel:${center.contactInfo}'))
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline_rounded, size: 15),
                  label: const Text('Details'),
                  onPressed: () => _showCenterDetailsSheet(center),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions_rounded, size: 15),
                  label: const Text('Go'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary),
                  onPressed: center.hasValidCoordinates
                      ? () => _launchNavigation(
                          center.latitude, center.longitude, center.name)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCenterDetailsSheet(DonationCenter center) {
    final statusColor = _statusBadgeColor(center.operationalStatus);
    final inv = center.bloodInventory ?? const <String, dynamic>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      center.facilityType,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      center.operationalStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (center.isVerified)
                    const Row(
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 16, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Verified Facility',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                center.name,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimaryOf(ctx),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textSecondaryOf(ctx)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      center.city != null && center.city!.isNotEmpty
                          ? '${center.address}, ${center.city}'
                          : center.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryOf(ctx),
                      ),
                    ),
                  ),
                ],
              ),
              if (center.operatingHours != null &&
                  center.operatingHours!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 16, color: AppColors.textSecondaryOf(ctx)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        center.operatingHours!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryOf(ctx),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (center.contactInfo != null &&
                  center.contactInfo!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 16, color: AppColors.textSecondaryOf(ctx)),
                    const SizedBox(width: 6),
                    Text(
                      center.contactInfo!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(ctx),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Reported Blood Inventory',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(ctx),
                    ),
                  ),
                  const Spacer(),
                  if (center.updatedAt != null)
                    Text(
                      'Updated ${DateFormat('MMM d, h:mm a').format(center.updatedAt!.toLocal())}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedOf(ctx),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (inv.isEmpty)
                Text(
                  'Call center directly to confirm real-time unit availability.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((grp) {
                    final qty = int.tryParse((inv[grp] ?? '0').toString()) ?? 0;
                    return Container(
                      width: 74,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: qty > 0
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.mutedOf(ctx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: qty > 0
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : AppColors.borderOf(ctx),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            grp,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: qty > 0
                                  ? AppColors.primary
                                  : AppColors.textMutedOf(ctx),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$qty units',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Call Facility'),
                      onPressed: center.contactInfo != null &&
                              center.contactInfo!.isNotEmpty
                          ? () =>
                              launchUrl(Uri.parse('tel:${center.contactInfo}'))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary),
                      onPressed: center.hasValidCoordinates
                          ? () {
                              Navigator.pop(ctx);
                              _launchNavigation(center.latitude,
                                  center.longitude, center.name);
                            }
                          : null,
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
