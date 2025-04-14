// lib/features/nearby_map/presentation/pages/map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';

// --- NEW: Imports for Donation Centers ---
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';
import 'package:red_cell_net_final/features/donation_centers/data/services/donation_center_service.dart';
// --- End NEW Imports ---

// Default location (Dhaka coordinates)
final LatLng defaultLocation = LatLng(23.8103, 90.4125);
const double defaultZoom = 13.0;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;

  LatLng? _currentMapCenter;
  bool _isLoading = true;
  bool _permissionGranted = false;
  String? _errorMessage;

  // Services
  final RequestService _requestService = RequestService();
  // --- NEW: Add Donation Center Service ---
  final DonationCenterService _donationCenterService = DonationCenterService();
  // --- End NEW ---

  // Markers state is now handled within the nested StreamBuilders

  @override
  void initState() {
    super.initState();
    _currentMapCenter = defaultLocation;
    _checkPermissionAndGetLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // --- Location/Permission/Animate/Settings methods remain the same ---
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
    LatLng center = defaultLocation;
    bool permissionOk = false;
    String? errorMsg;
    if (status.isGranted) {
      permissionOk = true;
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15));
        center = LatLng(position.latitude, position.longitude);
        print("Location fetched: $center");
      } on LocationServiceDisabledException catch (_) {
        errorMsg = "Location services disabled.";
        permissionOk = false;
        print(errorMsg);
      } on TimeoutException catch (_) {
        errorMsg = "Location fetch timed out.";
        print(errorMsg);
      } catch (e) {
        print("Loc Error: $e");
        errorMsg = "Could not get location.";
      }
    } else {
      permissionOk = false;
      errorMsg = status.isPermanentlyDenied
          ? "Perm denied. Enable in settings."
          : "Permission denied.";
      print(errorMsg);
    }
    if (mounted) {
      setState(() {
        _currentMapCenter = center;
        _permissionGranted = permissionOk;
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      _animateToLocation(center);
    }
  }

  Future<void> _animateToLocation(LatLng location, {double? zoom}) async {
    try {
      final GoogleMapController controller = await _controllerCompleter.future;
      if (mounted) {
        print("Animating camera to $location");
        controller.animateCamera(
            CameraUpdate.newLatLngZoom(location, zoom ?? defaultZoom));
      }
    } catch (e) {
      print("Error animating camera: $e");
    }
  }

  Future<void> _openAppSettings() async => await openAppSettings();
  // --- End unchanged methods ---

  // --- Builds Markers for Requests AND Centers ---
  Set<Marker> _buildAllMarkers(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> requestDocs,
      List<DonationCenter> centers // Accept list of centers
      ) {
    Set<Marker> markers = {};

    // NOTE: User Location marker is handled by myLocationEnabled on GoogleMap

    // Add Blood Request Markers
    for (var doc in requestDocs) {
      final data = doc.data();
      final dynamic coordsData = data['hospitalCoords'];
      GeoPoint? geoPoint;
      if (coordsData is GeoPoint) geoPoint = coordsData;
      final String urgency = data['urgencyLevel'] ?? 'Unknown';
      final String bloodType = data['requiredBloodType'] ?? 'N/A';
      final String hospital = data['hospitalName'] ?? 'Unknown Hospital';

      if (geoPoint != null) {
        final LatLng requestLatLng =
            LatLng(geoPoint.latitude, geoPoint.longitude);
        markers.add(
          Marker(
            markerId: MarkerId("req_${doc.id}"), position: requestLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(urgency)), // Urgency color
            infoWindow: InfoWindow(
                title: 'Need $bloodType @ $hospital',
                snippet: 'Urgency: $urgency. Tap for details.',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              RequestDetailsPage(requestId: doc.id)),
                    )),
          ),
        );
      }
    }

    // --- NEW: Add Donation Center Markers ---
    for (var center in centers) {
      final LatLng centerLatLng =
          LatLng(center.coordinates.latitude, center.coordinates.longitude);
      markers.add(
        Marker(
          markerId: MarkerId("ctr_${center.id}"), position: centerLatLng,
          // Use a different color/icon for centers
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure), // Example: Blue
          infoWindow: InfoWindow(
              title: center.name,
              snippet: center.address, // Show name/address
              onTap: () {
                // TODO: Implement navigation to Center Details Page later
                print("Tapped center: ${center.name}");
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Details for ${center.name} TBD.')));
              }),
        ),
      );
    }
    // --- End NEW ---

    print("Total markers built: ${markers.length}");
    return markers; // Return the combined set
  }

  // Urgency color helper
  double _getMarkerHue(String? urgency) {
    switch (urgency) {
      case 'Critical':
        return BitmapDescriptor.hueRed;
      case 'High':
        return BitmapDescriptor.hueOrange;
      case 'Medium':
        return BitmapDescriptor.hueYellow;
      case 'Low':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  // Builds the GoogleMap widget
  Widget _buildMap(Set<Marker> markers) {
    // Accept Set<Marker>
    if (_currentMapCenter == null)
      return const Center(child: Text("Error initializing map center."));
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition:
          CameraPosition(target: _currentMapCenter!, zoom: defaultZoom),
      markers: markers, // Display combined markers
      myLocationEnabled: _permissionGranted, myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      onMapCreated: (GoogleMapController controller) {
        print("Google Map Created");
        if (!_controllerCompleter.isCompleted) {
          _controllerCompleter.complete(controller);
        }
        _mapController = controller;
        _animateToLocation(_currentMapCenter!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center',
            onPressed: (_isLoading || _currentMapCenter == null)
                ? null
                : () {
                    final centerTarget = (_permissionGranted &&
                            _currentMapCenter != defaultLocation)
                        ? _currentMapCenter!
                        : defaultLocation;
                    _animateToLocation(centerTarget);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _checkPermissionAndGetLocation,
          )
        ],
      ),
      // --- NEW: Nested StreamBuilders ---
      body: StreamBuilder<List<DonationCenter>>(
          stream: _donationCenterService
              .getVerifiedCentersStream(), // Outer: Centers
          builder: (context, centerSnapshot) {
            final bool centersLoadingOrError =
                centerSnapshot.connectionState == ConnectionState.waiting ||
                    !centerSnapshot.hasData ||
                    centerSnapshot.hasError;
            if (centerSnapshot.hasError)
              print("Error loading centers: ${centerSnapshot.error}");
            final List<DonationCenter> centers =
                centerSnapshot.data ?? []; // Get centers or empty list

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    _requestService.getBloodRequestsStream(), // Inner: Requests
                builder: (context, requestSnapshot) {
                  final bool requestsLoadingOrError =
                      requestSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          !requestSnapshot.hasData ||
                          requestSnapshot.hasError;
                  if (requestSnapshot.hasError)
                    print("Error loading requests: ${requestSnapshot.error}");
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      requestDocs = requestSnapshot.data?.docs ?? [];

                  // --- Build markers using BOTH lists ---
                  Set<Marker> allMarkers = {};
                  // Build only when location is loaded (map is ready)
                  if (!_isLoading && _currentMapCenter != null) {
                    allMarkers = _buildAllMarkers(requestDocs, centers);
                  }
                  // --- End Build Markers ---

                  // --- Build UI Stack ---
                  return Stack(
                    children: [
                      // Show map only when initial center is known
                      if (!_isLoading && _currentMapCenter != null)
                        _buildMap(allMarkers) // Pass combined markers
                      else if (_isLoading)
                        const Center(
                            child:
                                CircularProgressIndicator()) // Initial location load
                      else
                        Center(
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                    _errorMessage ?? "Map failed to load.",
                                    textAlign:
                                        TextAlign.center))), // Location error

                      // Permission/error overlay for location
                      if (!_isLoading &&
                          (!_permissionGranted ||
                              (_errorMessage != null &&
                                  _errorMessage!.isNotEmpty)))
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.7),
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    _errorMessage ??
                                        "Location permission required.",
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center),
                                if (_errorMessage != null &&
                                    _errorMessage!
                                        .contains("permanently denied"))
                                  TextButton(
                                      onPressed: _openAppSettings,
                                      child: const Text("Open Settings",
                                          style: TextStyle(
                                              color: Colors.lightBlueAccent))),
                              ],
                            ),
                          ),
                        ),

                      // Optional: Loading indicator if map is visible but streams are loading
                      if (!_isLoading &&
                          _currentMapCenter != null &&
                          (centersLoadingOrError || requestsLoadingOrError))
                        Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Colors.white.withOpacity(0.5),
                              color: Colors.redAccent,
                            )),
                    ],
                  );
                  // --- End Build UI Stack ---
                });
          }),
      // --- End Main Body ---
    );
  }
}
