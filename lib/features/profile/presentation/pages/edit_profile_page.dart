// lib/features/profile/presentation/pages/edit_profile_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();
  String? get _currentUserId => SupabaseAuthService().currentUserId;

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
    final uid = _currentUserId;
    if (uid == null) {
      setState(() {
        _errorMessage = "Not logged in.";
        _isLoading = false;
      });
      return;
    }
    try {
      final userDoc = await _profileService.getUserProfile(uid);
      final userData = userDoc.data();
      if (userData != null) {
        _nameController.text = userData['name'] ?? '';
        _phoneController.text = userData['phoneNumber'] ?? '';
        _cityController.text = userData['locationCity'] ?? '';
        final String? currentBloodType = userData['bloodType'];
        if (currentBloodType != null && _bloodTypes.contains(currentBloodType)) {
          _selectedBloodType = currentBloodType;
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      _errorMessage = "Could not load profile details.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_formKey.currentState!.validate()) {
      final uid = _currentUserId;
      if (uid == null) return;

      setState(() => _isSaving = true);
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
              await _profileService.getUserProfile(uid);
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
          debugPrint("Badge check error: $e");
        }
      }

      final Map<String, dynamic> updatedData = {
        'name': newName,
        'phoneNumber': newPhone,
        'locationCity': newCity,
        'bloodType': newBloodType,
      };

      if (awardBadgeAndPoints) {
        final List<dynamic> updatedBadges = List<dynamic>.from(
            (await _profileService.getUserProfile(uid)).data()?['badges'] ?? []);
        if (!updatedBadges.contains(profileCompleteBadgeId)) {
          updatedBadges.add(profileCompleteBadgeId);
        }
        updatedData['badges'] = updatedBadges;
        updatedData['points'] = currentPoints + pointsForCompletion;
      }

      String? finalErrorMessage;
      bool submissionSuccess = false;

      try {
        await _profileService.updateUserProfile(uid, updatedData);
        submissionSuccess = true;
      } catch (e) {
        debugPrint("Error updating profile: $e");
        finalErrorMessage = "Failed to save profile. Please try again.";
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage = finalErrorMessage;
          });
        }
      }

      if (submissionSuccess && mounted) {
        String successMessage = "Profile updated successfully!";
        if (awardBadgeAndPoints) {
          successMessage += "\n🎉 +$pointsForCompletion Life Points & Profile Complete Badge earned!";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        setState(() => _errorMessage = "Please fill all required fields.");
      }
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
    ImageSource? source;

    if (mounted) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan Blood Report (OCR)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Take a photo or upload an image of your lab report to auto-detect your blood group.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.primary),
                  ),
                  title: const Text('Capture with Camera',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: AppColors.secondary),
                  ),
                  title: const Text('Upload from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (source == null) {
      if (mounted) setState(() => _isProcessingOcr = false);
      return;
    }

    XFile? image;
    try {
      image = await picker.pickImage(source: source);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking image: $e"),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }

    if (image == null) {
      if (mounted) setState(() => _isProcessingOcr = false);
      return;
    }

    final InputImage inputImage = InputImage.fromFilePath(image.path);
    TextRecognizer? textRecognizer;

    try {
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String detectedText = recognizedText.text;
      final String? foundBloodType = _findBloodTypeInText(detectedText);

      if (mounted) {
        if (foundBloodType != null) {
          _showConfirmationDialog(foundBloodType);
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("No Blood Group Detected"),
              content: const Text(
                "Could not clearly identify a blood group from the image. Please select your blood group manually below.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error processing document: $e"),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      await textRecognizer?.close();
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  String? _findBloodTypeInText(String text) {
    if (text.isEmpty) return null;
    String searchableText = text
        .toUpperCase()
        .replaceAll(':', '')
        .replaceAll('&', '')
        .replaceAll(RegExp(r'\s+'), ' ');

    final RegExp patternExplicit = RegExp(
        r'\b(BLOOD GROUP|BLOOD TYPE|GROUP)\s?(A|B|AB|O)\s?(\+|-|POSITIVE|NEGATIVE|POS|NEG)\b');
    Match? explicitMatch = patternExplicit.firstMatch(searchableText);
    if (explicitMatch != null) {
      final abo = explicitMatch.group(2);
      final rh = _normalizeRh(explicitMatch.group(3));
      if (abo != null && _bloodTypes.contains(abo + rh)) {
        return abo + rh;
      }
    }

    final aboRegex = RegExp(r'\b(AB|A|B|O)\b');
    final aboMatches =
        aboRegex.allMatches(searchableText).map((m) => m.group(1)!).toSet();

    final rhTextRegex = RegExp(r'\b(POSITIVE|NEGATIVE|POS|NEG)\b');
    final rhTextMatches = rhTextRegex
        .allMatches(searchableText)
        .map((m) => _normalizeRh(m.group(1)))
        .toSet();

    final rhSymbolRegex = RegExp(r'(\+|-)(?!\d)');
    final rhSymbolMatches = rhSymbolRegex
        .allMatches(searchableText)
        .map((m) => _normalizeRh(m.group(1)))
        .toSet();

    Set<String> uniqueRh = {};
    if (rhTextMatches.length == 1) {
      uniqueRh = rhTextMatches;
    } else if (rhTextMatches.isEmpty && rhSymbolMatches.length == 1) {
      uniqueRh = rhSymbolMatches;
    }

    if (aboMatches.length == 1 && uniqueRh.length == 1) {
      final combined = aboMatches.first + uniqueRh.first;
      if (_bloodTypes.contains(combined)) return combined;
    }

    return null;
  }

  String _normalizeRh(String? rhText) {
    if (rhText == null) return '-';
    String upperRh = rhText.toUpperCase();
    if (upperRh == '+' || upperRh == 'POS' || upperRh == 'POSITIVE') return '+';
    if (upperRh == '-' || upperRh == 'NEG' || upperRh == 'NEGATIVE') return '-';
    return '-';
  }

  Future<void> _showConfirmationDialog(String detectedBloodType) async {
    if (!_bloodTypes.contains(detectedBloodType)) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text("Blood Group Detected!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "We recognized your blood type from the report:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            BloodGroupBadge(bloodType: detectedBloodType, size: 64),
            const SizedBox(height: 16),
            const Text(
              "Would you like to set this as your profile blood group?",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("Use This Group"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _selectedBloodType = detectedBloodType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Blood group updated to $detectedBloodType."),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enableForm = !_isLoading && !_isSaving && !_isProcessingOcr;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Edit Donor Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Error Alert Banner ---
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.critical, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.critical,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // --- Smart OCR Blood Report Card ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.document_scanner_rounded,
                                color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smart Blood Report OCR',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Scan your lab report to auto-detect blood group',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                enableForm ? () => _scanBloodReport() : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isProcessingOcr
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Scan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- Personal Information Section ---
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            enabled: enableForm,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              hintText: 'Your donor display name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your name'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            enabled: enableForm,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '+880 1XXXXXXXXX',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _cityController,
                            enabled: enableForm,
                            decoration: const InputDecoration(
                              labelText: 'City / Area *',
                              hintText: 'e.g. Dhanmondi, Dhaka',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your city/area'
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // Blood Group Selection Chips
                          const Text(
                            'Blood Group *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _bloodTypes.map((type) {
                              final isSelected = _selectedBloodType == type;
                              return ChoiceChip(
                                label: Text(type),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.primaryLight,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                onSelected: enableForm
                                    ? (selected) {
                                        setState(() {
                                          _selectedBloodType =
                                              selected ? type : null;
                                        });
                                      }
                                    : null,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: enableForm ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
