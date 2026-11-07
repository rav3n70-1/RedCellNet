// lib/features/profile/presentation/pages/edit_profile_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
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
  late TextEditingController _nicknameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;

  String? _selectedBloodType;
  String? _initialBloodType;
  bool _isVerifiedDonor = false;
  String? _avatarUrl;
  Map<String, dynamic>? _locationCoords;
  String? _uploadedVerificationPath;
  String? _extractedBloodType;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProcessingOcr = false;
  bool _isUploadingAvatar = false;
  bool _isDetectingGps = false;
  String? _errorMessage;

  final List<String> _bloodTypes = BloodCompatibility.validBloodGroups;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nicknameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = _currentUserId;
    if (uid == null) {
      setState(() {
        _errorMessage = 'Not logged in.';
        _isLoading = false;
      });
      return;
    }
    try {
      final userDoc = await _profileService.getUserProfile(uid);
      final userData = userDoc.data();
      if (userData != null) {
        _nameController.text = (userData['name'] ?? '').toString();
        _nicknameController.text = (userData['nickname'] ?? '').toString();
        _phoneController.text = (userData['phoneNumber'] ?? '').toString();
        _cityController.text = (userData['locationCity'] ?? '').toString();
        _avatarUrl = userData['avatarUrl']?.toString();
        _isVerifiedDonor = userData['isVerifiedDonor'] == true ||
            userData['verificationStatus'] == 'verified';
        if (userData['locationCoords'] is Map) {
          _locationCoords =
              Map<String, dynamic>.from(userData['locationCoords'] as Map);
        }
        final String? currentBloodType =
            BloodCompatibility.normalizeBloodGroup(userData['bloodType']?.toString());
        if (currentBloodType != null) {
          _selectedBloodType = currentBloodType;
          _initialBloodType = currentBloodType;
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      _errorMessage = 'Could not load profile details.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final uid = _currentUserId;
    if (uid == null || _isUploadingAvatar) return;

    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() {
        _isUploadingAvatar = true;
        _errorMessage = null;
      });

      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final url = await _profileService.uploadAvatar(
        uid: uid,
        bytes: bytes,
        extension: ext,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload photo: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  Future<void> _detectCurrentGpsArea() async {
    if (_isDetectingGps) return;
    setState(() {
      _isDetectingGps = true;
      _errorMessage = null;
    });

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied. Please enable GPS in system settings.';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 7),
      );

      // Round coordinates slightly (~1km coarse privacy precision) while keeping valid emergency radius matching
      final coarseLat = double.parse(pos.latitude.toStringAsFixed(3));
      final coarseLng = double.parse(pos.longitude.toStringAsFixed(3));
      String areaText = '';

      if (!kIsWeb) {
        try {
          final placemarks =
              await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = <String>[
              if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
              if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
            ];
            areaText = parts.toSet().join(', ');
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _locationCoords = {
            'latitude': coarseLat,
            'longitude': coarseLng,
          };
          if (areaText.isNotEmpty) {
            _cityController.text = areaText;
          } else if (_cityController.text.trim().isEmpty) {
            _cityController.text = 'Dhaka';
          }
          _isDetectingGps = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              areaText.isNotEmpty
                  ? 'Area detected: $areaText (coarse privacy coordinates saved)'
                  : 'Coarse area coordinates saved for nearby emergency alerts.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please fill all required fields.');
      return;
    }

    if (_selectedBloodType == null) {
      setState(() => _errorMessage = 'Please select your blood group.');
      return;
    }

    final uid = _currentUserId;
    if (uid == null) return;

    // Warn if user is changing an already verified blood group
    if (_isVerifiedDonor &&
        _initialBloodType != null &&
        _selectedBloodType != _initialBloodType) {
      final confirmChange = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: AppColors.borderSideOf(ctx),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reset Donor Verification?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Text(
            'Your blood group ($_initialBloodType) is currently lab-verified. Changing it to $_selectedBloodType will reset your Verified Donor shield until a new lab report is reviewed by staff.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondaryOf(ctx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Verified Group'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Change & Re-verify'),
            ),
          ],
        ),
      );
      if (confirmChange != true) return;
    }

    setState(() => _isSaving = true);
    final String newName = _nameController.text.trim();
    final String newNickname = _nicknameController.text.trim();
    final String newBloodType = _selectedBloodType!;
    final String newCity = _cityController.text.trim();
    final String newPhone = _phoneController.text.trim();

    final bool profileWillBeComplete = newName.isNotEmpty &&
        newBloodType.isNotEmpty &&
        newCity.isNotEmpty &&
        newPhone.isNotEmpty;

    bool awardBadgeAndPoints = false;
    int currentPoints = 0;
    List<dynamic> existingBadges = [];
    const String profileCompleteBadgeId = 'Profile Complete';
    const int pointsForCompletion = 15;

    try {
      final userDoc = await _profileService.getUserProfile(uid);
      final userData = userDoc.data();
      if (userData != null) {
        existingBadges = List<dynamic>.from(userData['badges'] ?? []);
        currentPoints = (userData['points'] as int?) ?? 0;
        if (profileWillBeComplete &&
            !existingBadges
                .map((e) => e.toString())
                .contains(profileCompleteBadgeId)) {
          awardBadgeAndPoints = true;
        }
      }
    } catch (e) {
      debugPrint('Badge check error: $e');
    }

    final Map<String, dynamic> updatedData = {
      'name': newName,
      'nickname': newNickname,
      'phoneNumber': newPhone,
      'locationCity': newCity,
      'bloodType': newBloodType,
      if (_locationCoords != null) 'locationCoords': _locationCoords,
      if (_uploadedVerificationPath != null) ...{
        'verificationDocUrl': _uploadedVerificationPath,
        'extractedBloodType': _extractedBloodType ?? newBloodType,
        'verificationStatus': 'pending',
        'verificationRequestedAt': DateTime.now().toUtc().toIso8601String(),
      },
    };

    if (awardBadgeAndPoints) {
      existingBadges.add(profileCompleteBadgeId);
      updatedData['badges'] = existingBadges;
      updatedData['points'] = currentPoints + pointsForCompletion;
    }

    String? finalErrorMessage;
    bool submissionSuccess = false;

    try {
      await _profileService.updateUserProfile(uid, updatedData);
      submissionSuccess = true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      finalErrorMessage = 'Failed to save profile: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = finalErrorMessage;
        });
      }
    }

    if (submissionSuccess && mounted) {
      String successMessage = 'Profile updated successfully!';
      if (_uploadedVerificationPath != null) {
        successMessage += '\nLab report submitted for staff verification.';
      }
      if (awardBadgeAndPoints) {
        successMessage +=
            '\n+$pointsForCompletion Life Points & Profile Complete Badge unlocked!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // --- OCR + Verification Upload: Scan Blood Report ---
  Future<void> _scanBloodReport() async {
    if (_isProcessingOcr || _isSaving) return;

    setState(() {
      _isProcessingOcr = true;
      _errorMessage = null;
    });

    final ImagePicker picker = ImagePicker();
    ImageSource? source;

    if (mounted) {
      final isDark = AppColors.isDark(context);
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: isDark ? AppColors.borderSideOf(context) : BorderSide.none,
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan & Upload Lab Report (OCR)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(ctx),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan your diagnostic blood group report to auto-detect your blood type and attach it securely for Verified Donor review.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.primary),
                  ),
                  title: Text(
                    'Capture with Camera',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(ctx),
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.secondary.withValues(alpha: 0.25)
                          : AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: AppColors.secondary),
                  ),
                  title: Text(
                    'Upload from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(ctx),
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
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
      image = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 88,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }

    if (image == null) {
      if (mounted) setState(() => _isProcessingOcr = false);
      return;
    }

    TextRecognizer? textRecognizer;
    String? foundBloodType;

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final InputImage inputImage = InputImage.fromFilePath(image.path);
        textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);
        foundBloodType =
            BloodCompatibility.extractBloodTypeFromOcr(recognizedText.text);
      }

      // Upload private verification document
      final uid = _currentUserId;
      String? uploadedPath;
      if (uid != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.contains('.')
            ? image.name.split('.').last.toLowerCase()
            : 'jpg';
        uploadedPath = await _profileService.uploadVerificationDocument(
          uid: uid,
          bytes: bytes,
          extension: ext,
        );
      }

      if (mounted) {
        setState(() {
          if (uploadedPath != null) {
            _uploadedVerificationPath = uploadedPath;
          }
          if (foundBloodType != null) {
            _extractedBloodType = foundBloodType;
          }
        });

        if (foundBloodType != null) {
          await _showConfirmationDialog(foundBloodType, uploadedPath != null);
        } else {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardBg(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: AppColors.borderSideOf(ctx),
              ),
              title: Text(
                uploadedPath != null
                    ? 'Report Uploaded for Review'
                    : 'Manual Selection Needed',
                style: TextStyle(
                  color: AppColors.textPrimaryOf(ctx),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                uploadedPath != null
                    ? 'Your blood report has been attached securely for staff verification. Auto-OCR could not read the blood group with 100% certainty — please select your blood group below and tap Save Profile.'
                    : 'Could not clearly identify a blood group from the image. Please select your blood group manually below.',
                style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
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
            content: Text('Error processing document: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      await textRecognizer?.close();
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _showConfirmationDialog(
      String detectedBloodType, bool reportAttached) async {
    if (!_bloodTypes.contains(detectedBloodType)) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Blood Group Detected!',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(ctx),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OCR recognized your blood group from the lab report:',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textPrimaryOf(ctx)),
              ),
              const SizedBox(height: 16),
              BloodGroupBadge(bloodType: detectedBloodType, size: 64),
              const SizedBox(height: 16),
              Text(
                reportAttached
                    ? 'Your report image is securely attached for staff verification. Set $detectedBloodType as your profile blood group?'
                    : 'Would you like to set $detectedBloodType as your profile blood group?',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondaryOf(ctx)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondaryOf(ctx))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Use This Group'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      setState(() => _selectedBloodType = detectedBloodType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Blood group set to $detectedBloodType. Tap Save Profile to confirm.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enableForm = !_isLoading && !_isSaving && !_isProcessingOcr;
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
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
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: AppColors.critical.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.critical.withValues(alpha: 0.4)),
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

                    // --- Profile Avatar Picker ---
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.14),
                                backgroundImage: (_avatarUrl != null &&
                                        _avatarUrl!.trim().isNotEmpty)
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: (_avatarUrl == null ||
                                        _avatarUrl!.trim().isEmpty)
                                    ? Text(
                                        _nameController.text.trim().isNotEmpty
                                            ? _nameController.text
                                                .trim()[0]
                                                .toUpperCase()
                                            : 'D',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap:
                                      enableForm ? _pickAndUploadAvatar : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.cardBg(context),
                                          width: 2),
                                    ),
                                    child: _isUploadingAvatar
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 15,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: enableForm ? _pickAndUploadAvatar : null,
                            child: const Text(
                              'Change Profile Photo',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- Smart OCR Blood Report Card ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF881337)
                                      .withValues(alpha: 0.35),
                                  const Color(0xFF4C0519)
                                      .withValues(alpha: 0.35)
                                ]
                              : const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderOf(context)
                              : AppColors.primaryAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardBg(context)
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.document_scanner_rounded,
                                color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uploadedVerificationPath != null
                                      ? 'Lab Report Attached'
                                      : 'Smart Blood Report OCR',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.primaryLight
                                        : AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _uploadedVerificationPath != null
                                      ? 'Ready for Verified Donor moderation when saved'
                                      : 'Scan lab report to detect blood group & verify',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryOf(context),
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
                              foregroundColor: Colors.white,
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
                                : Text(
                                    _uploadedVerificationPath != null
                                        ? 'Rescan'
                                        : 'Scan',
                                    style: const TextStyle(
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
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderOf(context)),
                        boxShadow: isDark ? null : AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal & Contact Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            enabled: enableForm,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
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
                            controller: _nicknameController,
                            enabled: enableForm,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
                            decoration: const InputDecoration(
                              labelText: 'Nickname / Last Name (Greeting Name)',
                              hintText: 'Shown below greetings on Home & Pass Card',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            enabled: enableForm,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
                            decoration: const InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: '+880 1XXXXXXXXX',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => v == null || v.trim().length < 7
                                ? 'Please enter a valid contact phone number'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _cityController,
                            enabled: enableForm,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'City / Area *',
                              hintText: 'e.g. Dhanmondi, Dhaka',
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined),
                              suffixIcon: IconButton(
                                tooltip: 'Use Current GPS Area',
                                icon: _isDetectingGps
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location_rounded,
                                        color: AppColors.primary, size: 20),
                                onPressed:
                                    enableForm ? _detectCurrentGpsArea : null,
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your city/area'
                                : null,
                          ),
                          if (_locationCoords != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.shield_moon_rounded,
                                    size: 13, color: AppColors.success),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Coarse area coordinates saved for nearby emergency matching (exact address is never public).',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Blood Group Selection Chips
                          Row(
                            children: [
                              Text(
                                'Blood Group *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              if (_isVerifiedDonor &&
                                  _selectedBloodType == _initialBloodType) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          size: 12, color: AppColors.success),
                                      SizedBox(width: 3),
                                      Text(
                                        'Lab Verified',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
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
                                backgroundColor: isDark
                                    ? AppColors.surfaceMutedOf(context)
                                    : AppColors.primaryLight,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.textPrimaryOf(context)
                                          : AppColors.primaryDark),
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
