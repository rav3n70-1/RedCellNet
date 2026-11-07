// lib/features/blood_requests/presentation/pages/create_request_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as native_geo;
import 'package:geolocator/geolocator.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/hospital_directory_service.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';

class CreateRequestPage extends StatefulWidget {
  final String? existingRequestId;
  final Map<String, dynamic>? existingRequest;

  const CreateRequestPage({
    super.key,
    this.existingRequestId,
    this.existingRequest,
  });

  bool get isEditing =>
      existingRequestId != null && existingRequestId!.trim().isNotEmpty;

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _requestService = RequestService();

  // Controllers
  final _patientInfoController = TextEditingController();
  final _reasonController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _hospitalAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  // State
  String? _selectedBloodType;
  String _selectedComponent = 'Whole Blood';
  String _selectedUrgency = 'High';
  int _unitsNeeded = 1;
  int _minUnitsAllowed = 1;
  int _selectedExpiryHours = 48;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  Map<String, double>? _detectedHospitalCoords;
  String? _errorMessage;

  // Persisted draft state (new requests only)
  Map<String, dynamic>? _persistedDraft;
  bool _hasRestoredDraft = false;

  // Hospital Autofill & Proximity Directory State
  List<HospitalItem> _availableHospitals = [];
  HospitalItem? _selectedHospitalItem;
  TextEditingController? _autocompleteTextController;

  final List<String> _bloodTypes = BloodCompatibility.validBloodGroups;
  final List<String> _componentTypes = [
    'Whole Blood',
    'Red Cells',
    'Platelets',
    'Plasma',
  ];

  final List<Map<String, dynamic>> _expiryOptions = [
    {'hours': 24, 'label': '24 Hours'},
    {'hours': 48, 'label': '48 Hours (Standard)'},
    {'hours': 72, 'label': '72 Hours'},
    {'hours': 168, 'label': '7 Days'},
  ];

  final List<Map<String, String>> _urgencyOptions = [
    {
      'level': 'Critical',
      'label': 'Critical Emergency',
      'desc': 'Blood required within 2 hours',
    },
    {
      'level': 'High',
      'label': 'High Priority',
      'desc': 'Required within 6–12 hours',
    },
    {
      'level': 'Medium',
      'label': 'Moderate Need',
      'desc': 'Required today / tomorrow',
    },
    {
      'level': 'Low',
      'label': 'Scheduled',
      'desc': 'Scheduled surgery / planned transfusion',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHospitalDirectory();
    if (widget.isEditing && widget.existingRequest != null) {
      _populateFromExisting(widget.existingRequest!);
    } else {
      _checkSavedDraft();
    }
  }

  void _populateFromExisting(Map<String, dynamic> data) {
    _patientInfoController.text =
        (data['patientIdentifier'] ?? data['patientName'] ?? '').toString();
    _reasonController.text = (data['reason'] ?? '').toString();
    _hospitalNameController.text = (data['hospitalName'] ?? '').toString();
    _hospitalAddressController.text =
        (data['hospitalAddress'] ?? '').toString();
    _cityController.text = (data['city'] ?? '').toString();
    _contactPersonController.text = (data['contactPerson'] ?? '').toString();
    _contactNumberController.text =
        (data['contactPhone'] ?? data['contactNumber'] ?? '').toString();

    final bt = BloodCompatibility.normalizeBloodGroup(
        data['requiredBloodType']?.toString());
    _selectedBloodType = bt;

    final comp = (data['componentType'] ?? 'Whole Blood').toString();
    if (comp.toLowerCase().contains('red')) {
      _selectedComponent = 'Red Cells';
    } else if (_componentTypes.contains(comp)) {
      _selectedComponent = comp;
    }

    final urg = (data['urgencyLevel'] ?? 'High').toString();
    if (_urgencyOptions.any((o) => o['level'] == urg)) {
      _selectedUrgency = urg;
    }

    final int accepted = (data['acceptedUnits'] is num)
        ? (data['acceptedUnits'] as num).toInt()
        : 0;
    _minUnitsAllowed = math.max(1, accepted);
    final int reqUnits = (data['requiredUnits'] is num)
        ? (data['requiredUnits'] as num).toInt()
        : _minUnitsAllowed;
    _unitsNeeded = math.max(_minUnitsAllowed, reqUnits);

    final int exp = (data['expiryHours'] is num)
        ? (data['expiryHours'] as num).toInt()
        : 48;
    if (_expiryOptions.any((o) => o['hours'] == exp)) {
      _selectedExpiryHours = exp;
    }

    final coords = data['locationCoords'] ??
        data['location_coords'] ??
        data['hospitalCoords'];
    if (coords is Map) {
      final lat = coords['latitude'] ?? coords['lat'];
      final lng = coords['longitude'] ?? coords['lng'];
      if (lat is num && lng is num) {
        _detectedHospitalCoords = {
          'latitude': lat.toDouble(),
          'longitude': lng.toDouble(),
        };
      }
    }
  }

  Future<void> _checkSavedDraft() async {
    final draft = await AppSettingsService().loadRequestDraft();
    if (mounted && draft != null && draft.isNotEmpty) {
      setState(() {
        _persistedDraft = draft;
      });
    }
  }

  Map<String, dynamic> _collectDraftPayload() {
    return {
      'patient': _patientInfoController.text,
      'reason': _reasonController.text,
      'hospital': _hospitalNameController.text,
      'address': _hospitalAddressController.text,
      'city': _cityController.text,
      'contactPerson': _contactPersonController.text,
      'contactPhone': _contactNumberController.text,
      'bloodType': _selectedBloodType,
      'component': _selectedComponent,
      'urgency': _selectedUrgency,
      'units': _unitsNeeded,
      'expiry': _selectedExpiryHours,
      'coords': _detectedHospitalCoords,
    };
  }

  Future<void> _saveDraft({bool showToast = true}) async {
    if (widget.isEditing) return;
    final draft = _collectDraftPayload();
    await AppSettingsService().saveRequestDraft(draft);
    _persistedDraft = draft;
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved locally. You can resume anytime.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _restoreDraft() {
    final draft = _persistedDraft;
    if (draft == null) return;
    setState(() {
      _patientInfoController.text = (draft['patient'] ?? '').toString();
      _reasonController.text = (draft['reason'] ?? '').toString();
      _hospitalNameController.text = (draft['hospital'] ?? '').toString();
      if (_autocompleteTextController != null) {
        _autocompleteTextController!.text = _hospitalNameController.text;
      }
      _hospitalAddressController.text = (draft['address'] ?? '').toString();
      _cityController.text = (draft['city'] ?? '').toString();
      _contactPersonController.text = (draft['contactPerson'] ?? '').toString();
      _contactNumberController.text = (draft['contactPhone'] ?? '').toString();
      _selectedBloodType = draft['bloodType']?.toString();
      final comp = (draft['component'] ?? 'Whole Blood').toString();
      _selectedComponent =
          _componentTypes.contains(comp) ? comp : 'Whole Blood';
      _selectedUrgency = (draft['urgency'] ?? 'High').toString();
      _unitsNeeded =
          (draft['units'] is num) ? (draft['units'] as num).toInt() : 1;
      _selectedExpiryHours =
          (draft['expiry'] is num) ? (draft['expiry'] as num).toInt() : 48;
      final coords = draft['coords'];
      if (coords is Map) {
        final lat = coords['latitude'];
        final lng = coords['longitude'];
        if (lat is num && lng is num) {
          _detectedHospitalCoords = {
            'latitude': lat.toDouble(),
            'longitude': lng.toDouble(),
          };
        }
      }
      _hasRestoredDraft = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved draft restored.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadHospitalDirectory() async {
    try {
      final list = await HospitalDirectoryService.getHospitals();
      if (mounted) {
        setState(() {
          _availableHospitals = list;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableHospitals = HospitalDirectoryService.staticHospitals;
        });
      }
    }
  }

  void _selectHospital(HospitalItem hospital) {
    setState(() {
      _selectedHospitalItem = hospital;
      _hospitalNameController.text = hospital.name;
      if (_autocompleteTextController != null &&
          _autocompleteTextController!.text != hospital.name) {
        _autocompleteTextController!.text = hospital.name;
      }
      _hospitalAddressController.text = hospital.address;
      if (hospital.city.isNotEmpty) {
        _cityController.text = hospital.city;
      }
      _detectedHospitalCoords = {
        'latitude': hospital.latitude,
        'longitude': hospital.longitude,
      };
    });
  }

  Future<void> _findNearestHospital() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is needed to locate nearby hospitals.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final nearestList = HospitalDirectoryService.getNearestHospitals(
        userLat: position.latitude,
        userLng: position.longitude,
        hospitals: _availableHospitals.isNotEmpty ? _availableHospitals : null,
        limit: 8,
      );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = AppColors.isDark(ctx);
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBg(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: AppColors.borderOf(ctx), width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.near_me_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nearest Medical Centers',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimaryOf(ctx),
                              ),
                            ),
                            Text(
                              'Ranked by current GPS proximity',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: nearestList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = nearestList[idx];
                      final HospitalItem hospital =
                          item['hospital'] as HospitalItem;
                      final double distKm = item['distanceKm'] as double;
                      final isClosest = idx == 0;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _selectHospital(hospital);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Selected ${hospital.name} (${distKm < 1 ? '${(distKm * 1000).round()}m' : '${distKm.toStringAsFixed(1)} km'} away)',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isClosest
                                ? (isDark
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : AppColors.primaryContainer
                                        .withValues(alpha: 0.6))
                                : AppColors.surfaceMutedOf(ctx),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isClosest
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.borderOf(ctx),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isClosest
                                      ? AppColors.primary
                                      : AppColors.cardBg(ctx),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.local_hospital_rounded,
                                  color: isClosest
                                      ? Colors.white
                                      : AppColors.primary,
                                  size: 20,
                                ),
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
                                            hospital.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5,
                                              color:
                                                  AppColors.textPrimaryOf(ctx),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isClosest
                                                ? AppColors.primary
                                                : AppColors.cardBg(ctx),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isClosest
                                                  ? Colors.transparent
                                                  : AppColors.borderOf(ctx),
                                            ),
                                          ),
                                          child: Text(
                                            distKm < 1
                                                ? '${(distKm * 1000).round()}m'
                                                : '${distKm.toStringAsFixed(1)} km',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                              color: isClosest
                                                  ? Colors.white
                                                  : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hospital.address,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondaryOf(ctx),
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
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not determine nearest facility: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.high,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Widget _buildQuickHospitalChips() {
    final quickHospitals = [
      'Dhaka Medical',
      'BSMMU',
      'NICVD',
      'Square',
      'Red Crescent',
      'Evercare',
    ];
    final isDark = AppColors.isDark(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: quickHospitals.map((shortName) {
          final isSelected = _selectedHospitalItem != null &&
              _selectedHospitalItem!.name
                  .toLowerCase()
                  .contains(shortName.toLowerCase());

          return Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
            child: ActionChip(
              avatar: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.local_hospital_rounded,
                size: 14,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              label: Text(
                shortName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimaryOf(context),
                ),
              ),
              backgroundColor: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.surfaceMutedOf(context)
                      : AppColors.primaryContainer.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              onPressed: () {
                final matches = HospitalDirectoryService.searchHospitals(
                  shortName,
                  source: _availableHospitals.isNotEmpty
                      ? _availableHospitals
                      : null,
                );
                if (matches.isNotEmpty) {
                  _selectHospital(matches.first);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _patientInfoController.dispose();
    _reasonController.dispose();
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _cityController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _detectedHospitalCoords = {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      try {
        final placemarks = await native_geo.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addr = [
            place.name,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
          if (addr.isNotEmpty && _hospitalAddressController.text.isEmpty) {
            _hospitalAddressController.text = addr;
          }
          final city = place.locality ?? place.subAdministrativeArea ?? '';
          if (city.isNotEmpty && _cityController.text.isEmpty) {
            _cityController.text = city;
          }
        }
      } catch (e) {
        debugPrint('Reverse geocode notice: $e');
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Hospital GPS coordinates pinned from current location.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location error: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.high,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _showPreviewAndSubmit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_selectedBloodType == null) {
      setState(
        () => _errorMessage = 'Please select the required patient blood group.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please complete all required fields.');
      return;
    }

    if (widget.isEditing) {
      await _executeSubmit();
      return;
    }

    final bool? confirmBroadcast = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return Dialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          Icons.preview_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Confirm Blood Request',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.textPrimaryOf(ctx),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMutedOf(ctx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderOf(ctx)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BloodGroupBadge(
                              bloodType: _selectedBloodType!,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_unitsNeeded Unit(s) • $_selectedComponent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.textPrimaryOf(ctx),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  UrgencyChip(
                                    urgency: _selectedUrgency,
                                    compact: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 20, color: AppColors.borderOf(ctx)),
                        _previewRow(
                            'Facility', _hospitalNameController.text.trim()),
                        _previewRow(
                            'Address', _hospitalAddressController.text.trim()),
                        _previewRow('City', _cityController.text.trim()),
                        _previewRow('Patient / Ward',
                            _patientInfoController.text.trim()),
                        if (_reasonController.text.trim().isNotEmpty)
                          _previewRow(
                              'Indication', _reasonController.text.trim()),
                        _previewRow(
                            'Attendant', _contactPersonController.text.trim()),
                        _previewRow(
                          'Phone',
                          '${_contactNumberController.text.trim()} (masked until offer accepted)',
                        ),
                        _previewRow(
                            'Expires In', '$_selectedExpiryHours hours'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    BloodCompatibility.medicalCrossMatchDisclaimer,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(ctx),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Edit Details',
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(ctx)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Publish Alert'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmBroadcast == true) {
      await _executeSubmit();
    }
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSubmit() async {
    setState(() => _isSaving = true);

    final String inferredCity = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : (_selectedHospitalItem?.city ?? '');

    final Map<String, dynamic> requestData = {
      'patientIdentifier': _patientInfoController.text.trim(),
      'reason': _reasonController.text.trim(),
      'requiredBloodType': _selectedBloodType,
      'componentType': _selectedComponent,
      'requiredUnits': _unitsNeeded,
      'unitsNeeded': _unitsNeeded,
      'urgencyLevel': _selectedUrgency,
      'isEmergency':
          _selectedUrgency == 'Critical' || _selectedUrgency == 'High',
      'expiryHours': _selectedExpiryHours,
      'hospitalName': _hospitalNameController.text.trim(),
      'hospitalAddress': _hospitalAddressController.text.trim(),
      'city': inferredCity,
      'contactPerson': _contactPersonController.text.trim(),
      'contactPhone': _contactNumberController.text.trim(),
      'contactNumber': _contactNumberController.text.trim(),
    };

    Map<String, double>? hospitalCoords = _detectedHospitalCoords;
    if (hospitalCoords == null &&
        _hospitalAddressController.text.trim().isNotEmpty) {
      try {
        final locations = await native_geo
            .locationFromAddress(_hospitalAddressController.text.trim())
            .timeout(const Duration(seconds: 5));
        if (locations.isNotEmpty) {
          final loc = locations.first;
          hospitalCoords = {
            'latitude': loc.latitude,
            'longitude': loc.longitude,
          };
        }
      } catch (e) {
        debugPrint('Address geocoding fallback notice: $e');
      }
    }

    if (hospitalCoords != null) {
      requestData['hospitalCoords'] = hospitalCoords;
      requestData['locationCoords'] = hospitalCoords;
    }

    String? finalErrorMessage;
    bool submissionSuccess = false;
    int notifiedCount = 0;

    try {
      if (widget.isEditing) {
        await _requestService.updateBloodRequest(
          widget.existingRequestId!,
          requestData,
        );
        submissionSuccess = true;
      } else {
        final newId = await _requestService.createBloodRequest(requestData);
        final dispatchRes =
            await _requestService.dispatchEmergencyNotifications(newId);
        if (dispatchRes['notified_count'] is num) {
          notifiedCount = (dispatchRes['notified_count'] as num).toInt();
        }
        await AppSettingsService().clearRequestDraft();
        _persistedDraft = null;
        submissionSuccess = true;
      }
    } catch (e) {
      debugPrint('Error saving blood request: $e');
      finalErrorMessage =
          'Failed to save request: ${e.toString().replaceFirst("Exception: ", "")}';
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _errorMessage = finalErrorMessage;
      });

      if (submissionSuccess) {
        final msg = widget.isEditing
            ? 'Blood request updated successfully.'
            : (notifiedCount > 0
                ? 'Request published! Alerted $notifiedCount compatible nearby donor(s).'
                : 'Blood request published to the live emergency feed!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compatibleDonorsList = _selectedBloodType != null
        ? BloodCompatibility.canReceiveFrom(
            _selectedBloodType,
            componentType: _selectedComponent,
          )
        : <String>[];
    final isDark = AppColors.isDark(context);
    final settings = AppSettingsService();

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? settings.tr('Edit Request')
              : settings.tr('Post Blood Request'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () async {
            if (!widget.isEditing &&
                (_hospitalNameController.text.isNotEmpty ||
                    _patientInfoController.text.isNotEmpty ||
                    _selectedBloodType != null)) {
              await _saveDraft(showToast: false);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (!widget.isEditing)
            TextButton.icon(
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text(
                'Save Draft',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _saveDraft(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Saved Draft restore banner
              if (!widget.isEditing &&
                  _persistedDraft != null &&
                  !_hasRestoredDraft)
                Container(
                  margin: const EdgeInsets.only(bottom: 14.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.secondary.withValues(alpha: 0.2)
                        : AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unsaved request draft available.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : AppColors.secondaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _restoreDraft,
                        child: const Text(
                          'Restore',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        tooltip: 'Discard draft',
                        onPressed: () async {
                          await AppSettingsService().clearRequestDraft();
                          if (mounted) {
                            setState(() => _persistedDraft = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // Error banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.critical.withValues(alpha: 0.2)
                        : AppColors.criticalLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.critical.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.critical,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : AppColors.critical,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // --- Step 1: Blood Requirement, Component & Units ---
              _buildSectionCard(
                title: '1. Blood & Component Requirement',
                icon: Icons.bloodtype_rounded,
                children: [
                  Text(
                    'Select Required Blood Group *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bloodTypes.map((type) {
                      final isSelected = _selectedBloodType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: isDark
                            ? AppColors.surfaceMutedOf(context)
                            : AppColors.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.primaryDark),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.borderOf(context)
                                    : AppColors.primaryLight),
                            width: 1.5,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedBloodType = selected ? type : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (compatibleDonorsList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Compatible $_selectedComponent donors: ${compatibleDonorsList.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Blood Component Type Selector
                  Text(
                    'Component Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _componentTypes.map((component) {
                      final isSelected = _selectedComponent == component;
                      return FilterChip(
                        label: Text(settings.tr(component)),
                        selected: isSelected,
                        selectedColor: isDark
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.primaryContainer,
                        backgroundColor:
                            isDark ? AppColors.surfaceMutedOf(context) : null,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? (isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primaryDark)
                              : AppColors.textSecondaryOf(context),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderOf(context),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedComponent = component);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Units Needed Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Units (Bags) Needed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            if (_minUnitsAllowed > 1)
                              Text(
                                '$_minUnitsAllowed unit(s) already accepted',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMutedOf(context),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppColors.borderOf(context)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_rounded,
                                size: 20,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              onPressed: _unitsNeeded > _minUnitsAllowed
                                  ? () => setState(() => _unitsNeeded--)
                                  : null,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 32),
                              alignment: Alignment.center,
                              child: Text(
                                '$_unitsNeeded',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              onPressed: _unitsNeeded < 10
                                  ? () => setState(() => _unitsNeeded++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Step 2: Urgency & Expiration ---
              _buildSectionCard(
                title: '2. Urgency & Expiration',
                icon: Icons.timer_outlined,
                children: [
                  ..._urgencyOptions.map((opt) {
                    final level = opt['level']!;
                    final isSelected = _selectedUrgency == level;
                    final color = UrgencyChip.getUrgencyColor(level);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedUrgency = level),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.12)
                              : AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : AppColors.borderOf(context),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              UrgencyChip.getUrgencyIcon(level),
                              color: color,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['label']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? color
                                          : AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                  Text(
                                    opt['desc']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: color,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text(
                    'Request Active Duration (Auto-expiry)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedExpiryHours,
                    dropdownColor: AppColors.cardBg(context),
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.schedule_rounded),
                    ),
                    items: _expiryOptions.map((opt) {
                      return DropdownMenuItem<int>(
                        value: opt['hours'] as int,
                        child: Text(
                          opt['label'] as String,
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedExpiryHours = val);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Step 3: Hospital & GPS Location ---
              _buildSectionCard(
                title: '3. Hospital & Location',
                icon: Icons.local_hospital_rounded,
                headerTrailing: InkWell(
                  onTap: _isFetchingLocation ? null : _findNearestHospital,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFetchingLocation)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.near_me_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                        const SizedBox(width: 5),
                        const Text(
                          'Nearest GPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                children: [
                  _buildQuickHospitalChips(),
                  const SizedBox(height: 12),
                  Autocomplete<HospitalItem>(
                    initialValue:
                        TextEditingValue(text: _hospitalNameController.text),
                    displayStringForOption: (HospitalItem item) => item.name,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<HospitalItem>.empty();
                      }
                      return HospitalDirectoryService.searchHospitals(
                        textEditingValue.text,
                        source: _availableHospitals.isNotEmpty
                            ? _availableHospitals
                            : null,
                      ).take(5);
                    },
                    onSelected: _selectHospital,
                    fieldViewBuilder: (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      _autocompleteTextController = textEditingController;
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        enabled: !_isSaving,
                        style:
                            TextStyle(color: AppColors.textPrimaryOf(context)),
                        decoration: InputDecoration(
                          labelText: 'Hospital or Medical Facility Name *',
                          hintText: 'Type to search or choose chips above',
                          prefixIcon: const Icon(Icons.apartment_rounded),
                          suffixIcon: textEditingController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    textEditingController.clear();
                                    _hospitalNameController.clear();
                                    setState(() {
                                      _selectedHospitalItem = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          _hospitalNameController.text = val;
                        },
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Hospital name is required'
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _hospitalAddressController,
                    enabled: !_isSaving,
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: InputDecoration(
                      labelText: 'Hospital Street Address *',
                      hintText:
                          'Autofilled on hospital select or enter manually',
                      prefixIcon: const Icon(Icons.place_rounded),
                      suffixIcon: IconButton(
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                              ),
                        tooltip: 'Pin Current Device GPS Location',
                        onPressed:
                            _isFetchingLocation ? null : _detectCurrentLocation,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Hospital address is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cityController,
                    enabled: !_isSaving,
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: const InputDecoration(
                      labelText: 'City / District *',
                      hintText: 'e.g. Dhaka, Chattogram, Sylhet',
                      prefixIcon: Icon(Icons.location_city_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'City / district is required'
                        : null,
                  ),
                  if (_detectedHospitalCoords != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF059669)
                              : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'GPS Pinned (${_detectedHospitalCoords!['latitude']?.toStringAsFixed(4)}, ${_detectedHospitalCoords!['longitude']?.toStringAsFixed(4)})',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // --- Step 4: Patient & Contact Info ---
              _buildSectionCard(
                title: '4. Patient & Contact Information',
                icon: Icons.person_rounded,
                children: [
                  TextFormField(
                    controller: _patientInfoController,
                    enabled: !_isSaving,
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: const InputDecoration(
                      labelText: 'Patient Identifier / Ward / Bed *',
                      hintText: 'e.g. Ward 4, Bed 12 (initials ok for privacy)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Patient / ward reference is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reasonController,
                    enabled: !_isSaving,
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: const InputDecoration(
                      labelText: 'Clinical Reason / Indication (Optional)',
                      hintText: 'e.g. Surgery, Thalassemia, Dengue Platelets',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactPersonController,
                    enabled: !_isSaving,
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: const InputDecoration(
                      labelText: 'Attendant / Contact Person Name *',
                      hintText: 'e.g. Family Attendant / Duty Coordinator',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Contact name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactNumberController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: const InputDecoration(
                      labelText: 'Direct Emergency Phone Number *',
                      hintText: 'e.g. +8801700000000',
                      helperText:
                          'Protected: masked publicly until you accept a donor offer',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) {
                        return 'Please enter a valid 10–15 digit phone number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _showPreviewAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Saving Request...',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isEditing
                                ? Icons.save_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isEditing
                                ? 'Save Changes'
                                : 'Review & Publish Request',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? headerTrailing,
    required List<Widget> children,
  }) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
