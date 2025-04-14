// lib/features/blood_requests/presentation/pages/create_request_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb

// Import the Geocoding client and necessary Core types from Maps_apis package
import 'package:google_maps_apis/geocoding.dart';
import 'package:google_maps_apis/src/core.dart'; // For Component, Location, Geometry

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
  final _unitsController = TextEditingController();
  final _hospitalNameController =
      TextEditingController(); // Standard text field
  final _hospitalAddressController =
      TextEditingController(); // Standard text field
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  // State
  String? _selectedBloodType;
  String? _selectedUrgency;
  bool _isSaving = false;
  String? _errorMessage;

  // Lists for dropdowns
  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];
  final List<String> _urgencyLevels = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void dispose() {
    _patientInfoController.dispose();
    _unitsController.dispose();
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  // --- Submit Request using Maps_apis for Geocoding ---
  Future<void> _submitRequest() async {
    print("--- Button Tapped: Submit Request ---");
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final Map<String, dynamic> requestData = {
        'patientIdentifier': _patientInfoController.text.trim(),
        'requiredBloodType': _selectedBloodType,
        'unitsNeeded': int.tryParse(_unitsController.text.trim()) ?? 1,
        'urgencyLevel': _selectedUrgency,
        'hospitalName': _hospitalNameController.text.trim(),
        'hospitalAddress': _hospitalAddressController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
      };

      // --- Attempt Geocoding using 'Maps_apis' package ---
      GeoPoint? hospitalGeoPoint;
      final String address = _hospitalAddressController.text.trim();
      // ⚠️ IMPORTANT: Use your restricted key. Load securely if possible.
      const String apiKey = "AIzaSyCb5HmOC7NMgHy537YCFprdFDHZi5HsVVQ";
      bool geocodingAttempted = false;
      bool geocodingSuccess = false;

      if (apiKey == "YOUR_SECURE_GOOGLE_API_KEY")
        print("ERROR: Google API Key not set!");

      // Skip geocoding on Web
      if (!kIsWeb &&
          address.isNotEmpty &&
          apiKey != "YOUR_SECURE_GOOGLE_API_KEY") {
        geocodingAttempted = true;
        try {
          print("Attempting geocoding via Maps_apis: $address");
          final geocoding = GoogleMapsGeocoding(apiKey: apiKey);
          GeocodingResponse response = await geocoding.searchByAddress(
            address,
            components: [Component(Component.country, "bd")],
          ).timeout(const Duration(seconds: 10));

          if (response.status == "OK" &&
              response.results != null &&
              response.results!.isNotEmpty) {
            final Geometry? geometry = response.results!.first.geometry;
            final Location? location = geometry?.location;
            if (location != null) {
              hospitalGeoPoint = GeoPoint(location.lat, location.lng);
              requestData['hospitalCoords'] = hospitalGeoPoint;
              geocodingSuccess = true;
              print(
                  "Maps_apis Geocoding successful: Lat ${location.lat}, Lng ${location.lng}");
            } else {
              print(
                  "Maps_apis Geocoding failed: Geometry or Location missing.");
            }
          } else {
            print(
                "Maps_apis Geocoding failed: Status '${response.status}' or no results.");
          }
        } on TimeoutException catch (_) {
          print("Maps_apis Geocoding timed out.");
        } on Exception catch (e) {
          print("Error during Maps_apis geocoding: $e");
        }
      } else {
        if (kIsWeb)
          print("Running on Web, skipping client-side geocoding.");
        else
          print("Address empty or API Key missing, skipping geocoding.");
        geocodingAttempted = false;
      }
      // --- End Geocoding ---

      // --- Save to Firestore ---
      String? finalErrorMessage;
      bool submissionSuccess = false;
      try {
        await _requestService.createBloodRequest(requestData);
        submissionSuccess = true;
        print("Firestore save successful.");
      } catch (e) {
        print("Error saving to Firestore: $e");
        finalErrorMessage = "Failed to save request.";
      }
      // --- End Save ---

      // --- Update State & Navigate ---
      if (mounted) {
        // Stop loading indicator FIRST
        setState(() {
          _isSaving = false;
          _errorMessage = finalErrorMessage;
        });

        if (submissionSuccess) {
          String successMessage = "Blood request submitted successfully!";
          if (geocodingAttempted && !geocodingSuccess) {
            successMessage +=
                "\n(Warning: Could not get coordinates for address)";
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
                content: Text(successMessage),
                backgroundColor: Colors.green,
                duration: Duration(
                    seconds:
                        (geocodingAttempted && !geocodingSuccess) ? 4 : 3)));
          // Add delay before pop
          print("Create Request Successful. Attempting to pop page...");
          await Future.delayed(const Duration(milliseconds: 50));
          if (mounted) {
            Navigator.of(context).pop();
            print("Create Request Page popped.");
          }
        }
      }
      // --- End Update State ---
    } else {
      if (mounted)
        setState(() {
          _errorMessage = "Please fill all required fields correctly.";
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Uses standard TextFormFields for hospital name and address
    return Scaffold(
      appBar: AppBar(title: const Text('Create Blood Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Enter Patient & Request Details',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // Patient Info, Blood Type, Units, Urgency...
              TextFormField(
                  controller: _patientInfoController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                      labelText:
                          'Patient Information (e.g., Condition/Relation)',
                      hintText: 'Avoid full names if possible for privacy',
                      prefixIcon: Icon(Icons.person_search_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please provide patient context'
                      : null),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  value: _selectedBloodType,
                  hint: const Text('Select Required Blood Type'),
                  decoration: const InputDecoration(
                      labelText: 'Required Blood Type*',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                      border: OutlineInputBorder()),
                  items: _bloodTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() => _selectedBloodType = v),
                  validator: (v) =>
                      v == null ? 'Please select blood type' : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _unitsController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                      labelText: 'Units Needed*',
                      prefixIcon: Icon(Icons.format_list_numbered)),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter units';
                    if (int.tryParse(v.trim()) == null ||
                        int.parse(v.trim()) <= 0) return 'Enter valid number';
                    return null;
                  }),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  value: _selectedUrgency,
                  hint: const Text('Select Urgency Level'),
                  decoration: const InputDecoration(
                      labelText: 'Urgency Level*',
                      prefixIcon: Icon(Icons.priority_high_rounded),
                      border: OutlineInputBorder()),
                  items: _urgencyLevels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() => _selectedUrgency = v),
                  validator: (v) => v == null ? 'Please select urgency' : null),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Location & Contact',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),

              // --- Hospital Name (Standard TextField) ---
              TextFormField(
                  controller: _hospitalNameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                      labelText: 'Hospital Name*',
                      prefixIcon: Icon(Icons.local_hospital_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter hospital name'
                      : null),
              const SizedBox(height: 16),
              // --- Hospital Address (Standard TextField) ---
              TextFormField(
                  controller: _hospitalAddressController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                      labelText: 'Hospital Address*',
                      hintText: 'Include area for clarity',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                  maxLines: 2,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter hospital address'
                      : null),
              const SizedBox(height: 16),

              // Contact Person, Contact Number...
              TextFormField(
                  controller: _contactPersonController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                      labelText: 'Contact Person Name*',
                      prefixIcon: Icon(Icons.account_circle_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter contact name'
                      : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _contactNumberController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                      labelText: 'Contact Phone Number*',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter contact phone'
                      : null),
              const SizedBox(height: 32),

              // Error Message Display...
              if (_errorMessage != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              // Submit Button...
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit Request'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _submitRequest),
            ],
          ),
        ),
      ),
    );
  }
}
