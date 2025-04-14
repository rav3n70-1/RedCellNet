// lib/features/profile/presentation/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  String? _selectedBloodType;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProcessingOcr = false;
  String? _errorMessage;

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    /* ... Load data ... */ if (_currentUser == null) {
      setState(() {
        _errorMessage = "Not logged in.";
        _isLoading = false;
      });
      return;
    }
    try {
      final userDoc = await _profileService.getUserProfile(_currentUser!.uid);
      final userData = userDoc.data();
      if (userData != null) {
        _nameController.text = userData['name'] ?? '';
        _phoneController.text = userData['phoneNumber'] ?? '';
        _cityController.text = userData['locationCity'] ?? '';
        String? currentBloodType = userData['bloodType'];
        if (currentBloodType != null &&
            _bloodTypes.contains(currentBloodType)) {
          _selectedBloodType = currentBloodType;
        } else {
          _selectedBloodType = null;
        }
      } else {
        _errorMessage = "Profile data empty.";
      }
    } on Exception catch (e) {
      print("Error loading user data: $e");
      _errorMessage = e.toString();
    } catch (e) {
      print("Generic error loading: $e");
      _errorMessage = "Failed to load profile.";
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _saveProfile() async {
    /* ... Save profile logic ... */ FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
    });
    if (_formKey.currentState!.validate()) {
      if (_currentUser == null) {
        return;
      }
      setState(() {
        _isSaving = true;
      });
      final String newName = _nameController.text.trim();
      final String? newBloodType = _selectedBloodType;
      final String newCity = _cityController.text.trim();
      final String newPhone = _phoneController.text.trim();
      bool profileWillBeComplete =
          newName.isNotEmpty && newBloodType != null && newCity.isNotEmpty;
      bool awardBadgeAndPoints = false;
      int currentPoints = 0;
      const String profileCompleteBadgeId = "Profile Complete";
      const int pointsForCompletion = 5;
      if (profileWillBeComplete) {
        try {
          final userDoc =
              await _profileService.getUserProfile(_currentUser!.uid);
          final userData = userDoc.data();
          if (userData != null) {
            final List<dynamic> currentBadges = userData['badges'] ?? [];
            currentPoints = userData['points'] ?? 0;
            if (!List<String>.from(currentBadges)
                .contains(profileCompleteBadgeId)) {
              awardBadgeAndPoints = true;
            }
          }
        } catch (e) {
          print("Err fetch badges/pts: $e");
        }
      }
      final Map<String, dynamic> updatedData = {
        'name': newName,
        'phoneNumber': newPhone,
        'locationCity': newCity,
        'bloodType': newBloodType
      };
      if (awardBadgeAndPoints) {
        updatedData['badges'] = FieldValue.arrayUnion([profileCompleteBadgeId]);
        updatedData['points'] = currentPoints + pointsForCompletion;
        print("Adding Profile Complete badge/points.");
      }
      String? finalErrorMessage;
      bool submissionSuccess = false;
      try {
        await _profileService.updateUserProfile(_currentUser!.uid, updatedData);
        submissionSuccess = true;
        print("Profile updated.");
      } catch (e) {
        print("Error saving profile: $e");
        finalErrorMessage = "Failed to save profile.";
      } finally {
        if (mounted)
          setState(() {
            _isSaving = false;
            _errorMessage = finalErrorMessage;
          });
      }
      if (submissionSuccess && mounted) {
        String successMessage = "Profile updated!";
        if (awardBadgeAndPoints) {
          successMessage += "\n+${pointsForCompletion}pts & Badge earned!";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(successMessage), backgroundColor: Colors.green),
        );
        print("Save successful. Attempting pop...");
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) Navigator.of(context).pop();
        print("Edit page popped.");
      }
    } else {
      if (mounted)
        setState(() {
          _errorMessage = "Check required fields.";
        });
    }
  }

  // --- OCR: Scan Blood Report ---
  Future<void> _scanBloodReport() async {
    if (_isProcessingOcr || _isSaving) return;
    setState(() {
      _isProcessingOcr = true;
      _errorMessage = null;
    });
    final ImagePicker picker = ImagePicker();
    XFile? image;
    ImageSource? source;
    if (mounted) {
      source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text("Scan Blood Report"),
                content: Text("Choose image source:"),
                actions: [
                  TextButton(
                      child: Text("Camera"),
                      onPressed: () =>
                          Navigator.pop(context, ImageSource.camera)),
                  TextButton(
                      child: Text("Gallery"),
                      onPressed: () =>
                          Navigator.pop(context, ImageSource.gallery)),
                ],
              ));
    }
    if (source == null) {
      if (mounted) setState(() => _isProcessingOcr = false);
      return;
    }
    try {
      image = await picker.pickImage(source: source);
    } catch (e) {
      print("Error picking image: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error picking image: $e"),
            backgroundColor: Colors.red));
    }
    if (image == null) {
      if (mounted)
        setState(() {
          _isProcessingOcr = false;
        });
      return;
    }
    print("Image picked: ${image.path}");
    final InputImage inputImage = InputImage.fromFilePath(image.path);
    TextRecognizer? textRecognizer;
    try {
      print("Processing image with ML Kit...");
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      String detectedText = recognizedText.text;
      print("OCR Result:\n---\n${detectedText}\n---");
      // Use the UPDATED parsing logic (Attempt 9)
      String? foundBloodType = _findBloodTypeInText(detectedText);
      if (mounted) {
        if (foundBloodType != null) {
          _showConfirmationDialog(foundBloodType);
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Scan Unsuccessful"),
              content: const Text(
                  "Sorry, unable to automatically detect a blood type from the report. Please update your profile manually.\n\nThank you!"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print("Error OCR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error processing image: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      await textRecognizer?.close();
      print("Recognizer closed.");
      if (mounted)
        setState(() {
          _isProcessingOcr = false;
        });
    }
  }

  // --- UPDATED OCR: Find Blood Type Helper (Attempt 9 - Refined Global Scan) ---
  String? _findBloodTypeInText(String text) {
    if (text.isEmpty) return null;
    // Normalize: Uppercase, remove colons/ampersands, keep single spaces
    String searchableText = text
        .toUpperCase()
        .replaceAll(':', '')
        .replaceAll('&', '')
        .replaceAll(RegExp(r'\s+'), ' ');
    print("Searching in (normalized): $searchableText");

    String? aboGroup;
    String? rhFactorSymbol;
    int searchRadius = 40; // How many characters ahead to look

    // --- Strategy 1: Explicit Label + Value Together ---
    final RegExp patternExplicit = RegExp(
        r'\b(BLOOD GROUP|BLOOD TYPE|GROUP)\s?(A|B|AB|O)\s?(\+|-|POSITIVE|NEGATIVE|POS|NEG)\b');
    Match? explicitMatch = patternExplicit.firstMatch(searchableText);
    if (explicitMatch != null) {
      aboGroup = explicitMatch.group(2);
      rhFactorSymbol = _normalizeRh(explicitMatch.group(3));
      print("Strategy 1 Match: $aboGroup$rhFactorSymbol");
      if (aboGroup != null &&
          rhFactorSymbol != null &&
          _bloodTypes.contains(aboGroup + rhFactorSymbol))
        return aboGroup + rhFactorSymbol;
      aboGroup = null;
      rhFactorSymbol = null;
    }

    // --- Strategy 2: Find Keywords then Search Nearby Area (Keep this minimal check if needed) ---
    // This might still be unreliable due to varying formats
    // final aboLabelRegex = RegExp(r'\b(ABO|BLOOD GROUP)\b'); Match? aboLabelMatch = aboLabelRegex.firstMatch(searchableText); if (aboLabelMatch != null) { /* ... */ }
    // final rhLabelRegex = RegExp(r'\b(RH|ANTI D|D ANTIGEN)\b'); Match? rhLabelMatch = rhLabelRegex.firstMatch(searchableText); if (rhLabelMatch != null) { /* ... */ }
    // if (aboGroup != null && rhFactorSymbol != null) { /* ... return combined if valid ... */ }
    // else { print("Could not determine from Strategy 1. Falling back..."); aboGroup = null; rhFactorSymbol = null; }

    // --- Strategy 3: Global Scan & Count (Refined Rh Check) ---
    print("Attempting Global Scan & Count strategy...");
    // Find ABO
    final aboRegex = RegExp(r'\b(AB|A|B|O)\b');
    final aboMatches =
        aboRegex.allMatches(searchableText).map((m) => m.group(1)!).toSet();
    print("Global Scan Found ABO candidates: ${aboMatches.toList()}");

    // Find Rh (Prioritize words, then symbols, avoid symbol-digit)
    Set<String> uniqueRh = {};
    final rhTextRegex = RegExp(r'\b(POSITIVE|NEGATIVE|POS|NEG)\b');
    final rhTextMatches = rhTextRegex
        .allMatches(searchableText)
        .map((m) => _normalizeRh(m.group(1)))
        .toSet();
    print("Global Scan Found Rh Text candidates: ${rhTextMatches.toList()}");

    final rhSymbolRegex =
        RegExp(r'(\+|-)(?!\d)'); // Symbol NOT followed by digit
    final rhSymbolMatches = rhSymbolRegex
        .allMatches(searchableText)
        .map((m) => _normalizeRh(m.group(1)))
        .toSet();
    print(
        "Global Scan Found Rh Symbol candidates: ${rhSymbolMatches.toList()}");

    // Determine unique Rh factor
    if (rhTextMatches.length == 1) {
      uniqueRh = rhTextMatches; // Prioritize text match if unique
      print("Using unique Rh Text match: $uniqueRh");
    } else if (rhTextMatches.isEmpty && rhSymbolMatches.length == 1) {
      uniqueRh = rhSymbolMatches; // Use symbol if unique and no text match
      print("Using unique Rh Symbol match: $uniqueRh");
    } else {
      print(
          "Rh factor is ambiguous: Found ${rhTextMatches.length} text matches and ${rhSymbolMatches.length} symbol matches.");
    }

    // Combine if exactly one unique ABO and one unique Rh found
    if (aboMatches.length == 1 && uniqueRh.length == 1) {
      aboGroup = aboMatches.first;
      rhFactorSymbol = uniqueRh.first;
      String combinedType = aboGroup + rhFactorSymbol;
      print("Found unique combination via Global Scan: $combinedType");
      if (_bloodTypes.contains(combinedType))
        return combinedType;
      else
        print("Combined type '$combinedType' not standard.");
    } else {
      print(
          "Global Scan did not find exactly one unique ABO (${aboMatches.length}) and one unique Rh (${uniqueRh.length}).");
    }

    // --- Strategy 4: Simple Standalone patterns (Final Fallback - less reliable) ---
    // print("Falling back to simple pattern search...");
    // if (RegExp(r'\bA\s?\+\b').hasMatch(searchableText) || RegExp(r'\bA\s?POS\b').hasMatch(searchableText)) return "A+";
    // ... rest of simple patterns ...

    print("Blood type pattern not found after all strategies.");
    return null; // Final fallback - not found
  }

  // Helper to normalize Rh factor
  String _normalizeRh(String? rhText) {
    if (rhText == null) return '-';
    String upperRh = rhText.toUpperCase();
    if (upperRh == '+' || upperRh == 'POS' || upperRh == 'POSITIVE') return '+';
    if (upperRh == '-' || upperRh == 'NEG' || upperRh == 'NEGATIVE') return '-';
    print("Unrecognized Rh: '$rhText'");
    return '-';
  }
  // --- End Find Blood Type Helper ---

  // --- OCR: Confirmation Dialog ---
  Future<void> _showConfirmationDialog(String detectedBloodType) async {
    /* ... Same as before ... */ if (!_bloodTypes.contains(detectedBloodType)) {
      print("Invalid detected: $detectedBloodType");
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Blood Type"),
        content: Text("Detected: $detectedBloodType\nUse this value?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Use Value"),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() {
        _selectedBloodType = detectedBloodType;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Blood type set to $detectedBloodType."),
          backgroundColor: Colors.green));
    }
  }

  // Helper for Save button
  Widget _buildSaveButton() {
    bool isBusy = _isSaving || _isProcessingOcr;
    return isBusy
        ? const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator()))
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _saveProfile,
            child: const Text('Save Changes'),
          );
  }

  @override
  Widget build(BuildContext context) {
    bool enableForm = !_isLoading && !_isSaving && !_isProcessingOcr;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ]
              ],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Form fields...
                    TextFormField(
                      controller: _nameController,
                      enabled: enableForm,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: enableForm,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      enabled: enableForm,
                      decoration: const InputDecoration(
                        labelText: 'City / Area (e.g., Dhaka)',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter city'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBloodType,
                      hint: const Text('Select Blood Type'),
                      icon: const Icon(Icons.arrow_drop_down),
                      decoration: const InputDecoration(
                        labelText: 'Blood Type',
                        prefixIcon: Icon(Icons.bloodtype_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _bloodTypes
                          .map<DropdownMenuItem<String>>(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: enableForm
                          ? (v) => setState(() => _selectedBloodType = v)
                          : null,
                      validator: (v) =>
                          v == null ? 'Please select blood type' : null,
                    ),
                    const SizedBox(height: 8),
                    // OCR Button / Loader
                    _isProcessingOcr
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text("Scanning...")
                              ])
                        : TextButton.icon(
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text("Scan Blood Type from Report"),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent),
                            onPressed: _isSaving ? null : _scanBloodReport,
                          ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 32),
                    if (_errorMessage != null && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }
}
