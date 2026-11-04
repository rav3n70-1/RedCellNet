// lib/features/blood_requests/presentation/pages/create_request_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as native_geo;
import 'package:geolocator/geolocator.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _requestService = RequestService();

  // Controllers
  final _patientInfoController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _hospitalAddressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  // State
  String? _selectedBloodType;
  String _selectedComponent = 'Whole Blood';
  String _selectedUrgency = 'High';
  int _unitsNeeded = 1;
  int _selectedExpiryHours = 48;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  Map<String, double>? _detectedHospitalCoords;
  String? _errorMessage;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _componentTypes = [
    'Whole Blood',
    'Red Cells (PRBC)',
    'Platelets',
    'Plasma',
    'Cryoprecipitate',
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
      'desc': 'Required within 6-12 hours',
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

  static const Map<String, List<String>> _compatibleDonors = {
    'O-': ['O-'],
    'O+': ['O-', 'O+'],
    'A-': ['O-', 'A-'],
    'A+': ['O-', 'O+', 'A-', 'A+'],
    'B-': ['O-', 'B-'],
    'B+': ['O-', 'O+', 'B-', 'B+'],
    'AB-': ['O-', 'A-', 'B-', 'AB-'],
    'AB+': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
  };

  @override
  void dispose() {
    _patientInfoController.dispose();
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
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
        throw Exception("Location permission denied.");
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
            place.administrativeArea
          ].where((e) => e != null && e.isNotEmpty).join(', ');
          if (addr.isNotEmpty && _hospitalAddressController.text.isEmpty) {
            _hospitalAddressController.text = addr;
          }
        }
      } catch (e) {
        debugPrint("Reverse geocode notice: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hospital GPS location pinned from current position!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.high,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // --- Show Draft Preview Dialog Before Broadcasting ---
  Future<void> _showPreviewAndSubmit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_selectedBloodType == null) {
      setState(() => _errorMessage = 'Please choose the required blood group.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = "Please fill in all mandatory fields.");
      return;
    }

    final bool? confirmBroadcast = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.preview_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Preview Request",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BloodGroupBadge(bloodType: _selectedBloodType!, size: 48),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$_unitsNeeded Unit(s) • $_selectedComponent",
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  UrgencyChip(urgency: _selectedUrgency, compact: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _previewRow("Facility", _hospitalNameController.text.trim()),
                        _previewRow("Address", _hospitalAddressController.text.trim()),
                        _previewRow("Patient / Ward", _patientInfoController.text.trim()),
                        _previewRow("Attendant", _contactPersonController.text.trim()),
                        _previewRow("Phone", _contactNumberController.text.trim()),
                        _previewRow("Expires In", "$_selectedExpiryHours hours"),
                        _previewRow("GPS Pinned", _detectedHospitalCoords != null ? "Yes" : "Auto geocoded"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "⚠️ Once broadcasted, all compatible registered donors nearby will be notified.",
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Edit Details"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Broadcast Now"),
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
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "—",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSubmit() async {
    setState(() => _isSaving = true);

    final Map<String, dynamic> requestData = {
      'patientIdentifier': _patientInfoController.text.trim(),
      'requiredBloodType': _selectedBloodType,
      'componentType': _selectedComponent,
      'requiredUnits': _unitsNeeded,
      'unitsNeeded': _unitsNeeded,
      'remainingUnits': _unitsNeeded,
      'acceptedUnits': 0,
      'urgencyLevel': _selectedUrgency,
      'expiryHours': _selectedExpiryHours,
      'hospitalName': _hospitalNameController.text.trim(),
      'hospitalAddress': _hospitalAddressController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'contactNumber': _contactNumberController.text.trim(),
    };

    Map<String, double>? hospitalCoords = _detectedHospitalCoords;
    if (hospitalCoords == null &&
        _hospitalAddressController.text.trim().isNotEmpty) {
      try {
        final locations = await native_geo.locationFromAddress(
          _hospitalAddressController.text.trim(),
        ).timeout(const Duration(seconds: 5));
        if (locations.isNotEmpty) {
          final loc = locations.first;
          hospitalCoords = {
            'latitude': loc.latitude,
            'longitude': loc.longitude,
          };
        }
      } catch (e) {
        debugPrint("Address geocoding fallback notice: $e");
      }
    }

    if (hospitalCoords != null) {
      requestData['hospitalCoords'] = hospitalCoords;
      requestData['locationCoords'] = hospitalCoords;
    }

    String? finalErrorMessage;
    bool submissionSuccess = false;
    try {
      await _requestService.createBloodRequest(requestData);
      submissionSuccess = true;
    } catch (e) {
      debugPrint("Error saving blood request: $e");
      finalErrorMessage = "Failed to submit request: $e";
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _errorMessage = finalErrorMessage;
      });

      if (submissionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Emergency blood request published successfully!"),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compatibleDonorsList = _selectedBloodType != null
        ? (_compatibleDonors[_selectedBloodType] ?? [])
        : [];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Create Blood Request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.criticalLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.critical, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.critical,
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
                  const Text(
                    'Select Required Blood Group *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
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
                        backgroundColor: AppColors.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.primaryLight,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Compatible donors: ${compatibleDonorsList.join(', ')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Blood Component Type Selector
                  const Text(
                    'Component Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _componentTypes.map((component) {
                      final isSelected = _selectedComponent == component;
                      return FilterChip(
                        label: Text(component),
                        selected: isSelected,
                        selectedColor: AppColors.primaryContainer,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedComponent = component);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Units Needed Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Units (Bags) Needed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 20),
                              onPressed: _unitsNeeded > 1
                                  ? () => setState(() => _unitsNeeded--)
                                  : null,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 32),
                              alignment: Alignment.center,
                              child: Text(
                                '$_unitsNeeded',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 20),
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
                          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? color : AppColors.border,
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
                                      color: isSelected ? color : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    opt['desc']!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: color, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Text(
                    'Request Active Duration (Auto-expiry)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedExpiryHours,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.schedule_rounded),
                    ),
                    items: _expiryOptions.map((opt) {
                      return DropdownMenuItem<int>(
                        value: opt['hours'] as int,
                        child: Text(opt['label'] as String, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedExpiryHours = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Step 3: Hospital & GPS Location ---
              _buildSectionCard(
                title: '3. Hospital & Location',
                icon: Icons.local_hospital_rounded,
                children: [
                  TextFormField(
                    controller: _hospitalNameController,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Hospital or Medical Facility Name *',
                      hintText: 'e.g. Dhaka Medical College Hospital',
                      prefixIcon: Icon(Icons.apartment_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Hospital name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _hospitalAddressController,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: 'Hospital Street Address & City *',
                      hintText: 'e.g. Secretariate Road, Ramna, Dhaka',
                      prefixIcon: const Icon(Icons.place_rounded),
                      suffixIcon: IconButton(
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, color: AppColors.primary),
                        tooltip: 'Pin Current GPS Location',
                        onPressed: _isFetchingLocation ? null : _detectCurrentLocation,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Hospital address is required' : null,
                  ),
                  if (_detectedHospitalCoords != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'GPS coordinates pinned: ${_detectedHospitalCoords!['latitude']?.toStringAsFixed(4)}, ${_detectedHospitalCoords!['longitude']?.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
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
                    decoration: const InputDecoration(
                      labelText: 'Patient Identifier / Diagnosis *',
                      hintText: 'e.g. Ward 4 / Emergency ICU delivery',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Patient information is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactPersonController,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Attendant / Contact Person Name *',
                      hintText: 'e.g. Dr. Rahman / Family Member',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Contact name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactNumberController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Direct Emergency Phone Number *',
                      hintText: 'e.g. +8801700000000',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (v.trim().length < 6) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Preview & Submit Button
              ElevatedButton(
                onPressed: _isSaving ? null : _showPreviewAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                          ),
                          SizedBox(width: 12),
                          Text('Broadcasting Request...',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Review & Broadcast Request',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
