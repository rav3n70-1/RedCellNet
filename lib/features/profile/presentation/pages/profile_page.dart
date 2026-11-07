// lib/features/profile/presentation/pages/profile_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_list_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:red_cell_net_final/main.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserProfileService _profileService = UserProfileService();
  final AppSettingsService _settingsService = AppSettingsService();
  String? get currentUserId => SupabaseAuthService().currentUserId;
  String? get currentUserEmail => SupabaseAuthService().currentUserEmail;

  Stream<ProfileSnapshot>? _profileStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final uid = currentUserId;
    if (uid != null && uid.isNotEmpty) {
      _profileStream = _profileService.getUserProfileStream(uid);
    } else {
      _profileStream = const Stream.empty();
    }
  }

  final Map<String, Map<String, dynamic>> _badgeDetails = {
    'First Drop': {
      'name': 'First Drop',
      'icon': Icons.water_drop_rounded,
      'desc': 'Completed your first verified hospital blood donation',
      'pts': 25
    },
    'High Five': {
      'name': 'High Five',
      'icon': Icons.thumb_up_alt_rounded,
      'desc': 'Completed 5 verified blood donations',
      'pts': 50
    },
    'Double Digits': {
      'name': 'Double Digits',
      'icon': Icons.stars_rounded,
      'desc': 'Completed 10 verified blood donations',
      'pts': 100
    },
    'Rare Hero': {
      'name': 'Rare Hero',
      'icon': Icons.offline_bolt_rounded,
      'desc': 'Donated rare blood group (Rh- or AB)',
      'pts': 40
    },
    'Crisis Warrior': {
      'name': 'Crisis Warrior',
      'icon': Icons.local_fire_department_rounded,
      'desc': 'Responded directly during a critical emergency',
      'pts': 50
    },
    'Lifesaver Buddy': {
      'name': 'Lifesaver Buddy',
      'icon': Icons.group_add_rounded,
      'desc': 'Invited community donors to join RedCellNet',
      'pts': 20
    },
    'Health Aware': {
      'name': 'Health Aware',
      'icon': Icons.school_rounded,
      'desc': 'Completed clinical health articles in the Learn tab',
      'pts': 10
    },
    'Profile Complete': {
      'name': 'Profile Complete',
      'icon': Icons.verified_user_rounded,
      'desc': 'Completed full donor contact, area, & blood group details',
      'pts': 15
    },
    'Standby Guardian': {
      'name': 'Standby Guardian',
      'icon': Icons.shield_rounded,
      'desc': 'Stayed ready & available to respond to emergencies',
      'pts': 30
    },
    'Legend Donor': {
      'name': 'Legend Donor',
      'icon': Icons.emoji_events_rounded,
      'desc': 'Top tier lifesaver recognition (15+ verified donations)',
      'pts': 150
    },
  };

  String _getDonorTier(int points) {
    if (points >= 150) return 'Gold Guardian';
    if (points >= 50) return 'Silver Hero';
    return 'Bronze Lifesaver';
  }

  Color _getTierColor(int points) {
    if (points >= 150) return const Color(0xFFD97706);
    if (points >= 50) return const Color(0xFF64748B);
    return const Color(0xFFB45309);
  }

  Future<void> _logout([BuildContext? activeContext]) async {
    final dialogContext = activeContext ?? context;
    final bool? confirmLogout = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
          ),
          title: Text(
            'Log Out',
            style: TextStyle(
              color: AppColors.textPrimaryOf(ctx),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of RedCellNet?',
            style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondaryOf(ctx))),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      final rootNav = navigatorKey.currentState ??
          (dialogContext.mounted
              ? Navigator.of(dialogContext, rootNavigator: true)
              : null);
      try {
        await SupabaseAuthService().signOut();
        if (rootNav != null && rootNav.mounted) {
          rootNav.pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout error: $e'),
              backgroundColor: AppColors.critical,
            ),
          );
        }
      }
    }
  }

  void _showBadgeDetailSheet(String badgeKey, bool isEarned) {
    final badge = _badgeDetails[badgeKey];
    if (badge == null) return;
    final isDark = AppColors.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: isDark ? AppColors.borderSideOf(context) : BorderSide.none,
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isEarned
                      ? (isDark
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.primaryContainer)
                      : AppColors.surfaceMutedOf(ctx),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badge['icon'] as IconData,
                  color: isEarned
                      ? AppColors.primary
                      : AppColors.textMutedOf(ctx),
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                badge['name'] as String,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimaryOf(ctx),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isEarned
                      ? AppColors.success.withValues(alpha: 0.14)
                      : AppColors.surfaceMutedOf(ctx),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isEarned
                      ? 'UNLOCKED • +${badge['pts']} Life Points'
                      : 'LOCKED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isEarned
                        ? AppColors.success
                        : AppColors.textMutedOf(ctx),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                badge['desc'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(ctx),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Request Donor Verification Dialog with Multi-Factor Zero-Cost Clinical Engine ---
  void _showRequestVerificationDialog({
    String? currentBloodType,
    String? donorName,
    String? initialLab,
    String? initialCert,
    String? initialNotes,
  }) {
    final cleanInitialNotes = (initialNotes ?? '')
        .replaceAll(RegExp(r'\[ZCV-SCORE:[^\]]+\]\s*'), '')
        .trim();
    final labCtrl = TextEditingController(text: initialLab ?? '');
    final certCtrl = TextEditingController(text: initialCert ?? '');
    final notesCtrl = TextEditingController(text: cleanInitialNotes);
    final digitalReportTextCtrl = TextEditingController();
    Uint8List? selectedDocBytes;
    String selectedDocName = '';
    String rawOcrText = '';
    ZeroCostVerificationAnalysis? clinicalAnalysis;
    bool syncExtractedBloodGroupToProfile =
        (currentBloodType == null || currentBloodType.trim().isEmpty);
    bool showDigitalTextPaste = false;
    bool isScanning = false;
    bool isSubmitting = false;

    void recomputeAnalysis(void Function(void Function()) setDState) {
      final combinedText = [
        rawOcrText,
        digitalReportTextCtrl.text,
        labCtrl.text,
        certCtrl.text,
      ].where((s) => s.trim().isNotEmpty).join('\n');

      if (combinedText.trim().isEmpty) {
        setDState(() => clinicalAnalysis = null);
        return;
      }

      final result = BloodCompatibility.analyzeClinicalVerificationReport(
        rawText: combinedText,
        profileBloodGroup: currentBloodType,
        donorName: donorName,
        manualLabName: labCtrl.text,
        manualCertId: certCtrl.text,
      );

      setDState(() {
        clinicalAnalysis = result;
        if (labCtrl.text.trim().isEmpty && result.recognizedLabName != null) {
          labCtrl.text = result.recognizedLabName!;
        }
        if (certCtrl.text.trim().isEmpty &&
            result.extractedCertificateId != null) {
          certCtrl.text = result.extractedCertificateId!;
        }
      });
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = AppColors.isDark(dialogCtx);
        return StatefulBuilder(
          builder: (ctx, setDState) {
            Future<void> pickReport(ImageSource source) async {
              final picker = ImagePicker();
              try {
                final file = await picker.pickImage(
                  source: source,
                  maxWidth: 1800,
                  imageQuality: 88,
                );
                if (file == null) return;
                setDState(() => isScanning = true);
                final bytes = await file.readAsBytes();
                String scannedText = '';
                if (!kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS)) {
                  TextRecognizer? recognizer;
                  try {
                    recognizer =
                        TextRecognizer(script: TextRecognitionScript.latin);
                    final res = await recognizer
                        .processImage(InputImage.fromFilePath(file.path));
                    scannedText = res.text;
                  } catch (_) {
                  } finally {
                    await recognizer?.close();
                  }
                }
                selectedDocBytes = bytes;
                selectedDocName = file.name;
                rawOcrText = scannedText;
                isScanning = false;
                recomputeAnalysis(setDState);
              } catch (e) {
                setDState(() => isScanning = false);
              }
            }

            final analysis = clinicalAnalysis;
            final int score = analysis?.confidenceScore ?? 0;
            final Color scoreColor = analysis == null
                ? AppColors.textSecondaryOf(ctx)
                : (analysis.hasBloodGroupConflict
                    ? AppColors.critical
                    : (score >= 78
                        ? AppColors.success
                        : (score >= 50
                            ? AppColors.warning
                            : AppColors.primary)));

            return AlertDialog(
              backgroundColor: AppColors.cardBg(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: isDark ? AppColors.borderSideOf(ctx) : BorderSide.none,
              ),
              title: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donor Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryOf(ctx),
                          ),
                        ),
                        Text(
                          'Lab Report & Voluntary Donor Card Review',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryOf(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload your diagnostic blood group report or voluntary donor card (Red Crescent, Sandhani, Badhan, Popular, Ibn Sina, Square, BSMMU, DMCH). Note: Uploaded files are automatically deleted from storage after staff verification to keep your data private and storage clean.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryOf(ctx),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mutedOf(ctx),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderOf(ctx)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.document_scanner_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedDocBytes != null
                                        ? selectedDocName
                                        : 'Scan Lab Report or Donor Card',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimaryOf(ctx),
                                    ),
                                  ),
                                ),
                                if (isScanning)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isScanning || isSubmitting
                                        ? null
                                        : () => pickReport(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_outlined,
                                        size: 15),
                                    label: const Text('Camera',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isScanning || isSubmitting
                                        ? null
                                        : () => pickReport(ImageSource.gallery),
                                    icon: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 15),
                                    label: const Text('Gallery',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => setDState(() =>
                                    showDigitalTextPaste =
                                        !showDigitalTextPaste),
                                icon: Icon(
                                  showDigitalTextPaste
                                      ? Icons.expand_less_rounded
                                      : Icons.paste_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  showDigitalTextPaste
                                      ? 'Hide Digital Report Text Analyzer'
                                      : 'Have an SMS / Digital Portal Report? Paste Text',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            if (showDigitalTextPaste) ...[
                              const SizedBox(height: 6),
                              TextField(
                                controller: digitalReportTextCtrl,
                                maxLines: 2,
                                onChanged: (_) => recomputeAnalysis(setDState),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textPrimaryOf(ctx),
                                ),
                                decoration: const InputDecoration(
                                  labelText:
                                      'Paste Digital Lab Report / SMS Text',
                                  hintText:
                                      'e.g. Popular Diagnostic | Lab ID: LAB-2026-441 | ABO: O Rh(D): Positive | Hb: 14.4 g/dL | HBsAg: Negative',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (analysis != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: scoreColor.withValues(alpha: 0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      analysis.tierLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: scoreColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: scoreColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$score% Trust',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (analysis.extractedBloodGroup != null)
                                    _buildVerificationSignalChip(
                                      label:
                                          'Detected: ${analysis.extractedBloodGroup}',
                                      color: analysis.hasBloodGroupConflict
                                          ? AppColors.critical
                                          : AppColors.success,
                                      icon: analysis.hasBloodGroupConflict
                                          ? Icons.warning_amber_rounded
                                          : Icons.bloodtype_rounded,
                                    ),
                                  if (analysis.recognizedLabName != null)
                                    _buildVerificationSignalChip(
                                      label: 'Accredited Lab',
                                      color: AppColors.secondary,
                                      icon: Icons.domain_verification_rounded,
                                    ),
                                  if (analysis.extractedCertificateId != null)
                                    _buildVerificationSignalChip(
                                      label:
                                          'ID: ${analysis.extractedCertificateId}',
                                      color: AppColors.accent,
                                      icon: Icons.tag_rounded,
                                    ),
                                  if (analysis.extractedHemoglobin != null)
                                    _buildVerificationSignalChip(
                                      label:
                                          'Hb: ${analysis.extractedHemoglobin!.toStringAsFixed(1)} g/dL',
                                      color: AppColors.success,
                                      icon: Icons.monitor_heart_rounded,
                                    ),
                                  if (analysis
                                      .detectedScreeningMarkers.isNotEmpty)
                                    _buildVerificationSignalChip(
                                      label:
                                          'TTI: ${analysis.detectedScreeningMarkers.join(", ")}',
                                      color: AppColors.success,
                                      icon: Icons.biotech_rounded,
                                    ),
                                ],
                              ),
                              if (analysis.hasBloodGroupConflict) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Warning: Report shows ${analysis.extractedBloodGroup}, which differs from your profile (${analysis.profileBloodGroup}). Check below to update your profile to ${analysis.extractedBloodGroup}.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.critical,
                                  ),
                                ),
                              ],
                              if (analysis.extractedBloodGroup != null &&
                                  analysis.extractedBloodGroup !=
                                      analysis.profileBloodGroup) ...[
                                const SizedBox(height: 6),
                                CheckboxListTile(
                                  value: syncExtractedBloodGroupToProfile,
                                  onChanged: (v) => setDState(() =>
                                      syncExtractedBloodGroupToProfile =
                                          v ?? false),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    'Sync my profile blood group to ${analysis.extractedBloodGroup}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimaryOf(ctx),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Quick-Select Accredited Hospital / Blood Bank:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondaryOf(ctx),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: BloodCompatibility.accreditedBangladeshLabs
                              .take(10)
                              .map((lab) {
                            final selected = labCtrl.text.trim() == lab;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: selected
                                    ? AppColors.primary.withValues(alpha: 0.16)
                                    : AppColors.mutedOf(ctx),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.borderOf(ctx),
                                ),
                                label: Text(
                                  lab,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textPrimaryOf(ctx),
                                  ),
                                ),
                                onPressed: () {
                                  labCtrl.text = lab;
                                  recomputeAnalysis(setDState);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: labCtrl,
                        onChanged: (_) => recomputeAnalysis(setDState),
                        style: TextStyle(color: AppColors.textPrimaryOf(ctx)),
                        decoration: const InputDecoration(
                          labelText: 'Diagnostic Lab / Blood Bank *',
                          hintText: 'e.g. Popular Diagnostic / Red Crescent',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: certCtrl,
                        onChanged: (_) => recomputeAnalysis(setDState),
                        style: TextStyle(color: AppColors.textPrimaryOf(ctx)),
                        decoration: const InputDecoration(
                          labelText: 'Report ID / Sample # / Donor Card #',
                          hintText: 'e.g. LAB-2026-9812',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: TextStyle(color: AppColors.textPrimaryOf(ctx)),
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (optional)',
                          hintText: 'e.g. Tested at annual hospital camp',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondaryOf(ctx))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (labCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please enter or select the diagnostic lab or hospital name.'),
                              ),
                            );
                            return;
                          }
                          final uid = currentUserId;
                          if (uid == null) return;
                          setDState(() => isSubmitting = true);
                          try {
                            String? docPath;
                            if (selectedDocBytes != null) {
                              final ext = selectedDocName.contains('.')
                                  ? selectedDocName
                                      .split('.')
                                      .last
                                      .toLowerCase()
                                  : 'jpg';
                              docPath = await _profileService
                                  .uploadVerificationDocument(
                                uid: uid,
                                bytes: selectedDocBytes!,
                                extension: ext,
                              );
                            }

                            final finalAnalysis = BloodCompatibility
                                .analyzeClinicalVerificationReport(
                              rawText: [
                                rawOcrText,
                                digitalReportTextCtrl.text,
                                labCtrl.text,
                                certCtrl.text,
                              ].join('\n'),
                              profileBloodGroup: currentBloodType,
                              donorName: donorName,
                              manualLabName: labCtrl.text,
                              manualCertId: certCtrl.text,
                            );

                            final userNotes = notesCtrl.text.trim();
                            final structuredNotes = userNotes.isEmpty
                                ? finalAnalysis.toStructuredSummaryTag()
                                : '${finalAnalysis.toStructuredSummaryTag()} $userNotes';

                            final Map<String, dynamic> payload = {
                              'verificationStatus': 'pending',
                              'verificationLab': labCtrl.text.trim(),
                              'verificationCert': certCtrl.text.trim(),
                              'verificationNotes': structuredNotes,
                              if (docPath != null)
                                'verificationDocUrl': docPath,
                              if (finalAnalysis.extractedBloodGroup != null)
                                'extractedBloodType':
                                    finalAnalysis.extractedBloodGroup,
                              if (syncExtractedBloodGroupToProfile &&
                                  finalAnalysis.extractedBloodGroup != null)
                                'bloodType': finalAnalysis.extractedBloodGroup,
                              'verificationRequestedAt':
                                  DateTime.now().toUtc().toIso8601String(),
                            };

                            await _profileService.updateUserProfile(
                                uid, payload);

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Verification submitted (${finalAnalysis.confidenceScore}% Clinical Confidence)!',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Submission error: $e'),
                                  backgroundColor: AppColors.critical,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Evidence'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVerificationSignalChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Self-Logged Past Donation Dialog (Never issues fake official certificates or overwrites newer dates) ---
  void _showLogDonationDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final hospitalController = TextEditingController();
    final unitsController = TextEditingController(text: '1');
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = AppColors.isDark(dialogCtx);

        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final nextEligible = selectedDate.add(const Duration(days: 90));
            final daysLeft =
                nextEligible.difference(DateTime.now()).inDays.clamp(0, 366);
            final bool isCurrentlyHealing =
                nextEligible.isAfter(DateTime.now());

            return AlertDialog(
              backgroundColor: AppColors.cardBg(dialogCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side:
                    isDark ? AppColors.borderSideOf(dialogCtx) : BorderSide.none,
              ),
              title: Row(
                children: [
                  const Icon(Icons.water_drop_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Log Past Donation',
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(dialogCtx),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log an external donation to keep your 90-day medical recovery timer accurate. Self-logged records are marked as unverified personal entries.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(dialogCtx),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Date of Donation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimaryOf(dialogCtx),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.mutedOf(dialogCtx),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.borderOf(dialogCtx)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat.yMMMMd().format(selectedDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimaryOf(dialogCtx),
                                ),
                              ),
                            ),
                            Icon(Icons.edit_calendar_rounded,
                                size: 18,
                                color: AppColors.textSecondaryOf(dialogCtx)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrentlyHealing
                            ? (isDark
                                ? const Color(0xFF064E3B)
                                    .withValues(alpha: 0.35)
                                : const Color(0xFFECFDF5))
                            : AppColors.mutedOf(dialogCtx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrentlyHealing
                              ? AppColors.success.withValues(alpha: 0.45)
                              : AppColors.borderOf(dialogCtx),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCurrentlyHealing
                                ? Icons.health_and_safety_rounded
                                : Icons.check_circle_outline_rounded,
                            color: isCurrentlyHealing
                                ? AppColors.success
                                : AppColors.textSecondaryOf(dialogCtx),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCurrentlyHealing
                                      ? '90-Day Healing Recovery Active'
                                      : 'Safe Interval Completed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isCurrentlyHealing
                                        ? AppColors.success
                                        : AppColors.textPrimaryOf(dialogCtx),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isCurrentlyHealing
                                      ? 'Eligible on ${DateFormat.yMMMd().format(nextEligible)} ($daysLeft days left).'
                                      : 'Full 90-day recovery interval observed.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryOf(dialogCtx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: hospitalController,
                      style:
                          TextStyle(color: AppColors.textPrimaryOf(dialogCtx)),
                      decoration: const InputDecoration(
                        labelText: 'Hospital or Blood Center *',
                        hintText: 'e.g. Dhaka Medical College / Red Crescent',
                        prefixIcon: Icon(Icons.apartment_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitsController,
                      keyboardType: TextInputType.number,
                      style:
                          TextStyle(color: AppColors.textPrimaryOf(dialogCtx)),
                      decoration: const InputDecoration(
                        labelText: 'Units Donated',
                        prefixIcon: Icon(Icons.bloodtype_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel',
                      style:
                          TextStyle(color: AppColors.textSecondaryOf(dialogCtx))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (hospitalController.text.trim().isEmpty) return;
                    final uid = currentUserId;
                    if (uid == null) return;
                    Navigator.pop(dialogCtx);
                    try {
                      final userSnap =
                          await _profileService.getUserProfile(uid);
                      final profileMap = userSnap.data() ?? {};
                      final currentHistory = List<dynamic>.from(
                          profileMap['donation_history'] ?? []);
                      final units =
                          (int.tryParse(unitsController.text.trim()) ?? 1)
                              .clamp(1, 2);

                      final newEntry = {
                        'id':
                            'self_${DateTime.now().millisecondsSinceEpoch}',
                        'hospital': hospitalController.text.trim(),
                        'location': hospitalController.text.trim(),
                        'units': units,
                        'date': selectedDate.toUtc().toIso8601String(),
                        'nextEligibleDate':
                            nextEligible.toUtc().toIso8601String(),
                        'verified': false,
                        'source': 'self_logged',
                      };
                      currentHistory.insert(0, newEntry);

                      DateTime? existingLast;
                      if (profileMap['lastDonationDate'] != null) {
                        existingLast = DateTime.tryParse(
                            profileMap['lastDonationDate'].toString());
                      }
                      DateTime? existingNext;
                      if (profileMap['nextEligibleDate'] != null) {
                        existingNext = DateTime.tryParse(
                            profileMap['nextEligibleDate'].toString());
                      }

                      final bool isNewerOrFirst = existingLast == null ||
                          selectedDate.isAfter(existingLast);
                      final DateTime effectiveLast =
                          isNewerOrFirst ? selectedDate : existingLast;
                      final DateTime effectiveNext = isNewerOrFirst
                          ? nextEligible
                          : (existingNext ??
                              existingLast.add(const Duration(days: 90)));
                      final bool anyCooldownActive =
                          effectiveNext.isAfter(DateTime.now());

                      final Map<String, dynamic> updates = {
                        'donationHistory': currentHistory,
                        if (isNewerOrFirst) ...{
                          'lastDonationDate':
                              effectiveLast.toUtc().toIso8601String(),
                          'nextEligibleDate':
                              effectiveNext.toUtc().toIso8601String(),
                        },
                        if (anyCooldownActive) ...{
                          'isAvailableToDonate': false,
                          'availabilityStatus': 'unavailable',
                        },
                      };

                      await _profileService.updateUserProfile(uid, updates);

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            anyCooldownActive
                                ? 'Self-logged record saved. Recovery active until ${DateFormat.yMMMd().format(effectiveNext)}.'
                                : 'Past donation record saved to your personal log.',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error logging donation: $e'),
                          backgroundColor: AppColors.critical,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Notification Preferences Sheet ---
  void _showNotificationPreferencesSheet(Map<String, dynamic> currentPrefs) {
    bool emergencyAlerts = currentPrefs['emergency_alerts'] != false;
    bool offerUpdates = currentPrefs['offer_updates'] != false;
    bool systemBroadcasts = currentPrefs['system_broadcasts'] != false;
    bool cooldownReminders = currentPrefs['cooldown_reminders'] != false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sCtx, setSState) {
          Future<void> persist() async {
            final uid = currentUserId;
            if (uid == null) return;
            await _profileService.updateUserProfile(uid, {
              'notificationPreferences': {
                'emergency_alerts': emergencyAlerts,
                'offer_updates': offerUpdates,
                'system_broadcasts': systemBroadcasts,
                'cooldown_reminders': cooldownReminders,
              },
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(sCtx),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Control which clinical & coordination alerts reach you.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondaryOf(sCtx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nearby Compatible Emergencies',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Urgent requests matching your blood group & area'),
                    value: emergencyAlerts,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) {
                      setSState(() => emergencyAlerts = v);
                      persist();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Offer & Request Coordination',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Status updates when offers are accepted or completed'),
                    value: offerUpdates,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) {
                      setSState(() => offerUpdates = v);
                      persist();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hospital Blood Bank Broadcasts',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'City-wide shortage bulletins from moderators'),
                    value: systemBroadcasts,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) {
                      setSState(() => systemBroadcasts = v);
                      persist();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('90-Day Recovery Reminders',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Reminder when your safe healing interval completes'),
                    value: cooldownReminders,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) {
                      setSState(() => cooldownReminders = v);
                      persist();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Privacy Settings Sheet ---
  void _showPrivacySettingsSheet(Map<String, dynamic> currentPrivacy) {
    bool showAreaAvailability =
        currentPrivacy['show_area_availability'] != false;
    bool shareStatsOnPass = currentPrivacy['share_stats_on_pass'] != false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sCtx, setSState) {
          Future<void> persist() async {
            final uid = currentUserId;
            if (uid == null) return;
            await _profileService.updateUserProfile(uid, {
              'privacySettings': {
                'show_area_availability': showAreaAvailability,
                'share_stats_on_pass': shareStatsOnPass,
              },
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy & Safety Controls',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(sCtx),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your phone number and exact home address are NEVER publicly visible. Contact details are shared only when a requester accepts your offer.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondaryOf(sCtx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include in Anonymized Area Zones',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Count me anonymously in ~2 km city availability zones on the map'),
                    value: showAreaAvailability,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) {
                      setSState(() => showAreaAvailability = v);
                      persist();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Donation Count on Digital Pass',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Display total verified donations on your flippable donor pass'),
                    value: shareStatsOnPass,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) {
                      setSState(() => shareStatsOnPass = v);
                      persist();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Change Password Dialog ---
  void _showChangePasswordDialog() {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: AppColors.cardBg(dCtx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: AppColors.borderSideOf(dCtx),
          ),
          title: const Text('Change Password',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password (min 6 characters)',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final p1 = passCtrl.text;
                      final p2 = confirmCtrl.text;
                      if (p1.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Password must be at least 6 characters.')),
                        );
                        return;
                      }
                      if (p1 != p2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Passwords do not match.')),
                        );
                        return;
                      }
                      setDState(() => saving = true);
                      try {
                        await SupabaseAuthService().updatePassword(p1);
                        if (dCtx.mounted) Navigator.pop(dCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not update password: $e'),
                              backgroundColor: AppColors.critical,
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Request Own Account Deletion (Requires Admin/Staff Approval) ---
  void _showDeleteAccountDialog({
    BuildContext? activeContext,
    VoidCallback? onSubmitted,
  }) {
    final dialogCtx = activeContext ?? context;
    final reasonCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: dialogCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBg(dCtx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(
                color: AppColors.critical,
                width: 1.2,
              ),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.critical,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Request Account Deletion',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.5,
                      color: AppColors.critical,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded,
                            color: AppColors.warning, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin / Staff Approval Required: To protect active emergency blood requests and clinical records, account deletion requests are reviewed by RedCellNet Admin/Staff before permanent database removal.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.38,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryOf(dCtx),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason for deleting account',
                      hintText:
                          'e.g. Moving abroad, medical condition, duplicate account...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your donor availability will be immediately paused while your request is under review. Type DELETE below to submit:',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondaryOf(dCtx),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE',
                      prefixIcon: Icon(Icons.warning_amber_rounded,
                          color: AppColors.critical),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  foregroundColor: Colors.white,
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        if (confirmCtrl.text.trim().toUpperCase() != 'DELETE') {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Please type DELETE to confirm.'),
                            ),
                          );
                          return;
                        }
                        setDState(() => submitting = true);
                        try {
                          await _profileService.requestAccountDeletion(
                            reason: reasonCtrl.text.trim(),
                          );
                          if (dCtx.mounted) Navigator.pop(dCtx);
                          onSubmitted?.call();
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Account deletion request submitted for Admin/Staff approval. Your availability is paused.',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        } catch (e) {
                          setDState(() => submitting = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text('Could not submit request: $e'),
                                backgroundColor: AppColors.critical,
                              ),
                            );
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Deletion Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _callPhoneNumber(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number specified.')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $phone')),
      );
    }
  }

  void _copyICECredentialsToClipboard({
    required String name,
    required String bloodType,
    required String contactName,
    required String contactPhone,
    required String medicalNotes,
    required String uid,
  }) {
    HapticFeedback.lightImpact();
    final buffer = StringBuffer();
    buffer.writeln('[EMERGENCY MEDICAL ICE CARD]');
    buffer.writeln(
        'Patient/Donor: ${name.isNotEmpty ? name : "RedCellNet Member"}');
    buffer.writeln(
        'Blood Group: ${bloodType.isNotEmpty ? bloodType : "Unset / Unknown (Cross-match required)"}');
    buffer.writeln(
        'Emergency Contact: ${contactName.isNotEmpty ? contactName : "Primary Contact"} (${contactPhone.isNotEmpty ? contactPhone : "Not set"})');
    if (medicalNotes.isNotEmpty) {
      buffer.writeln('Medical Notes/Allergies: $medicalNotes');
    }
    buffer.writeln(
        'Identifier: RCN-${uid.length >= 8 ? uid.substring(0, 8).toUpperCase() : uid}');
    buffer.writeln('Platform: RedCellNet Medical Network');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Medical ICE summary copied to clipboard for lockscreen/first responders.'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showEditICEDialog({
    required String currentName,
    required String currentPhone,
    required String currentNotes,
    String donorName = '',
    String bloodType = '',
  }) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final notesCtrl = TextEditingController(text: currentNotes);
    bool saving = false;

    const List<String> relationshipChips = [
      'Spouse',
      'Parent',
      'Sibling',
      'Family',
      'Friend',
      'Physician',
    ];
    const List<String> allergyChips = [
      'No Known Allergies',
      'Penicillin Allergy',
      'NSAID / Aspirin Allergy',
      'Sulfa Allergy',
      'Latex Allergy',
    ];
    const List<String> conditionChips = [
      'No Chronic Conditions',
      'Asthma',
      'Hypertension',
      'Diabetes',
      'Iron Supplement User',
      'Organ Donor',
    ];

    void toggleTagInNotes(String tag, StateSetter setSState) {
      final raw = notesCtrl.text.trim();
      final parts = raw
          .split(RegExp(r'\s*[•|,]\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.any((p) => p.toLowerCase() == tag.toLowerCase())) {
        parts.removeWhere((p) => p.toLowerCase() == tag.toLowerCase());
      } else {
        if (tag == 'No Known Allergies') {
          parts.removeWhere((p) => p.toLowerCase().contains('allergy'));
        }
        if (tag == 'No Chronic Conditions') {
          parts.removeWhere((p) =>
              p.toLowerCase() == 'asthma' ||
              p.toLowerCase() == 'hypertension' ||
              p.toLowerCase() == 'diabetes');
        }
        parts.add(tag);
      }
      notesCtrl.text = parts.join(' • ');
      setSState(() {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return StatefulBuilder(
          builder: (sCtx, setSState) {
            final currentNotesText = notesCtrl.text.trim();
            final effectiveBlood =
                BloodCompatibility.normalizeBloodGroup(bloodType) ?? 'UNSET';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sCtx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sCtx).size.height * 0.90,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(sCtx),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: AppColors.borderOf(sCtx)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderOf(sCtx),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.critical.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.emergency_rounded,
                              color: AppColors.critical,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Medical ID (ICE)',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimaryOf(sCtx),
                                  ),
                                ),
                                Text(
                                  'First-responder contact, allergies & clinical alerts',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondaryOf(sCtx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sCtx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Live First-Responder Lock-Screen Preview
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? const [
                                          Color(0xFF2A0A14),
                                          Color(0xFF150912)
                                        ]
                                      : const [
                                          Color(0xFFFFF1F2),
                                          Color(0xFFFFE4E6)
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.critical
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.critical,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          effectiveBlood,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const Text(
                                          'ABO/Rh',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'LIVE FIRST-RESPONDER PREVIEW',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                            color: AppColors.critical,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          nameCtrl.text.trim().isNotEmpty
                                              ? 'ICE Kin: ${nameCtrl.text.trim()}'
                                              : 'ICE Kin: Not configured yet',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                AppColors.textPrimaryOf(sCtx),
                                          ),
                                        ),
                                        Text(
                                          phoneCtrl.text.trim().isNotEmpty
                                              ? 'Tel: ${phoneCtrl.text.trim()}'
                                              : 'Tel: Add emergency phone below',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (currentNotesText.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Alerts: $currentNotesText',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Contact Person Name + Relationship Quick Chips
                            Text(
                              '1. EMERGENCY CONTACT PERSON',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                                color: AppColors.textMutedOf(sCtx),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameCtrl,
                              onChanged: (_) => setSState(() {}),
                              style: TextStyle(
                                  color: AppColors.textPrimaryOf(sCtx)),
                              decoration: const InputDecoration(
                                labelText: 'Emergency Contact Name',
                                hintText: 'e.g. Mrs. Farhana Rahman (Spouse)',
                                prefixIcon: Icon(Icons.person_pin_rounded),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: relationshipChips.map((rel) {
                                  final hasRel = nameCtrl.text
                                      .toLowerCase()
                                      .contains('($rel)'.toLowerCase());
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: hasRel
                                          ? AppColors.primary
                                              .withValues(alpha: 0.16)
                                          : AppColors.mutedOf(sCtx),
                                      side: BorderSide(
                                        color: hasRel
                                            ? AppColors.primary
                                            : AppColors.borderOf(sCtx),
                                      ),
                                      label: Text(
                                        rel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: hasRel
                                              ? AppColors.primary
                                              : AppColors.textPrimaryOf(sCtx),
                                        ),
                                      ),
                                      onPressed: () {
                                        final base = nameCtrl.text
                                            .replaceAll(
                                                RegExp(r'\s*\([^)]*\)\s*$'), '')
                                            .trim();
                                        nameCtrl.text = base.isEmpty
                                            ? '($rel)'
                                            : '$base ($rel)';
                                        setSState(() {});
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Contact Phone
                            Text(
                              '2. EMERGENCY CONTACT PHONE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                                color: AppColors.textMutedOf(sCtx),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              onChanged: (_) => setSState(() {}),
                              style: TextStyle(
                                  color: AppColors.textPrimaryOf(sCtx)),
                              decoration: const InputDecoration(
                                labelText: 'Emergency Phone Number *',
                                hintText: '+880 1711 000000',
                                prefixIcon: Icon(Icons.phone_in_talk_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Allergies & Medical Alerts Quick Chips
                            Text(
                              '3. KNOWN ALLERGIES & CLINICAL ALERTS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                                color: AppColors.textMutedOf(sCtx),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...allergyChips,
                                ...conditionChips,
                              ].map((chip) {
                                final isSelected = currentNotesText
                                    .toLowerCase()
                                    .contains(chip.toLowerCase());
                                return FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  selected: isSelected,
                                  selectedColor:
                                      AppColors.critical.withValues(alpha: 0.16),
                                  checkmarkColor: AppColors.critical,
                                  backgroundColor: AppColors.mutedOf(sCtx),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.critical
                                        : AppColors.borderOf(sCtx),
                                  ),
                                  label: Text(
                                    chip,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.critical
                                          : AppColors.textPrimaryOf(sCtx),
                                    ),
                                  ),
                                  onSelected: (_) =>
                                      toggleTagInNotes(chip, setSState),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: notesCtrl,
                              maxLines: 2,
                              onChanged: (_) => setSState(() {}),
                              style: TextStyle(
                                  color: AppColors.textPrimaryOf(sCtx)),
                              decoration: const InputDecoration(
                                labelText:
                                    'Allergies, Medications & Transfusion Notes',
                                hintText:
                                    'e.g. No Known Allergies • CMV Negative • Organ Donor',
                                prefixIcon:
                                    Icon(Icons.medical_information_rounded),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: saving
                                        ? null
                                        : () => Navigator.pop(sCtx),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.critical,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: saving
                                        ? null
                                        : () async {
                                            final uid = currentUserId;
                                            if (uid == null) return;
                                            setSState(() => saving = true);
                                            try {
                                              await _profileService
                                                  .updateUserProfile(uid, {
                                                'emergencyContactName':
                                                    nameCtrl.text.trim(),
                                                'emergencyContactPhone':
                                                    phoneCtrl.text.trim(),
                                                'medicalNotes':
                                                    notesCtrl.text.trim(),
                                              });
                                              if (sCtx.mounted) {
                                                Navigator.pop(sCtx);
                                              }
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Emergency Medical ID (ICE) updated & synced to your Digital Pass!',
                                                    ),
                                                    backgroundColor:
                                                        AppColors.success,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              setSState(() => saving = false);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Error updating ICE info: $e'),
                                                    backgroundColor:
                                                        AppColors.critical,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    icon: saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.save_rounded,
                                            size: 18,
                                          ),
                                    label: const Text(
                                      'Save Emergency Medical ID',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  void _showCompatibilityMatrixSheet(
      BuildContext context, String initialType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return _CompatibilityMatrixModalContent(
              scrollController: scrollCtrl,
              initialBloodGroup:
                  BloodCompatibility.normalizeBloodGroup(initialType) ?? 'O+',
            );
          },
        );
      },
    );
  }

  Widget _buildMedicalICECard(
    BuildContext context, {
    required String name,
    required String bloodType,
    required String contactName,
    required String contactPhone,
    required String medicalNotes,
    required String primaryPhone,
    required String uid,
  }) {
    final isDark = AppColors.isDark(context);
    final effectiveContactPhone =
        contactPhone.isNotEmpty ? contactPhone : primaryPhone;
    final bool hasICEConfigured =
        contactPhone.isNotEmpty || contactName.isNotEmpty;
    final String? validGroup =
        BloodCompatibility.normalizeBloodGroup(bloodType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasICEConfigured
              ? AppColors.critical.withValues(alpha: isDark ? 0.35 : 0.25)
              : AppColors.borderOf(context),
          width: 1.2,
        ),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1015) : const Color(0xFFFFF1F2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(21)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.critical,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.emergency_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MEDICAL ICE CARD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: AppColors.critical,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'In Case of Emergency • First Responder Reference',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded,
                      size: 22, color: AppColors.critical),
                  tooltip: 'Edit Medical ICE Data',
                  onPressed: () => _showEditICEDialog(
                    currentName: contactName,
                    currentPhone: contactPhone,
                    currentNotes: medicalNotes,
                    donorName: name,
                    bloodType: bloodType,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Never fabricate a default blood group ("O+") if unset!
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: validGroup != null
                            ? const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.blueGrey.shade600,
                                  Colors.blueGrey.shade800
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            validGroup ?? 'UNSET',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: validGroup != null ? 22 : 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'BLOOD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMERGENCY CONTACT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMutedOf(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contactName.isNotEmpty
                                ? contactName
                                : 'Family Contact (Not Configured)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            effectiveContactPhone.isNotEmpty
                                ? effectiveContactPhone
                                : 'Add emergency phone number',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: effectiveContactPhone.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.textMutedOf(context),
                            ),
                          ),
                          if (medicalNotes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Allergies/Alert: $medicalNotes',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.critical,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: effectiveContactPhone.isNotEmpty
                            ? () => _callPhoneNumber(effectiveContactPhone)
                            : () => _showEditICEDialog(
                                  currentName: contactName,
                                  currentPhone: contactPhone,
                                  currentNotes: medicalNotes,
                                  donorName: name,
                                  bloodType: bloodType,
                                ),
                        icon: const Icon(Icons.call_rounded, size: 16),
                        label: const Text(
                          'Call ICE Contact',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white : AppColors.textPrimary,
                          side: BorderSide(color: AppColors.borderOf(context)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _copyICECredentialsToClipboard(
                          name: name,
                          bloodType: validGroup ?? '',
                          contactName: contactName,
                          contactPhone: effectiveContactPhone,
                          medicalNotes: medicalNotes,
                          uid: uid,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text(
                          'Copy ICE Card',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRecognitionAndMilestonesPage({
    required Map<String, dynamic> userData,
    required String name,
    required String bloodType,
    required String city,
    required String referralCode,
    required int points,
    required dynamic badges,
    required dynamic history,
  }) {
    final tier = _getDonorTier(points);
    final tierColor = _getTierColor(points);
    final int earnedCount = badges is List ? badges.length : 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageCtx) {
          final isDark = AppColors.isDark(pageCtx);
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(pageCtx),
            appBar: AppBar(
              title: const Text('Recognition & Milestones'),
              actions: [
                TextButton.icon(
                  onPressed: () => showCommunityLeaderboardSheet(
                    pageCtx,
                    userCity: city,
                    referralCode: referralCode,
                  ),
                  icon: const Icon(Icons.leaderboard_rounded,
                      size: 16, color: AppColors.imperialGold),
                  label: const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.imperialGold,
                    ),
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF1E1B4B), Color(0xFF0F172A)]
                          : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: tierColor.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.emoji_events_rounded,
                            color: tierColor, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: tierColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$points Life Points • $earnedCount / ${_badgeDetails.length} Badges Unlocked',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(pageCtx),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              points >= 150
                                  ? 'Maximum Gold Guardian tier achieved!'
                                  : (points >= 50
                                      ? '${150 - points} more Life Points to Gold Guardian'
                                      : '${50 - points} more Life Points to Silver Hero'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(pageCtx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'Donor Badges & Milestones',
                  subtitle:
                      'Tap any badge to view how to unlock it and earn Life Points',
                  icon: Icons.military_tech_rounded,
                ),
                const SizedBox(height: 10),
                _buildBadgesGrid(badges),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Donation History & Certificates',
                  subtitle:
                      'Verified hospital donations & personal recovery log',
                  icon: Icons.history_rounded,
                  actionLabel: '+ Log Past',
                  onAction: _showLogDonationDialog,
                ),
                const SizedBox(height: 10),
                _buildDonationHistory(history, name, bloodType),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openProfileSettingsPage({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> notifPrefs,
    required Map<String, dynamic> privacySettings,
    required String name,
    required String bloodType,
    required String donorId,
    required String city,
    required String nextEligibleText,
    required bool isVerified,
    required bool isEligible,
    required int totalDonations,
    required int points,
    required String referralCode,
    required int referralCount,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageCtx) {
          bool biometricAvailable = false;
          bool biometricChecking = true;
          bool biometricEnabled = _settingsService.biometricLockEnabled;
          bool deletionRequested = userData['deletionRequested'] == true &&
              (userData['deletionRequestStatus'] ?? 'pending').toString() ==
                  'pending';

          return StatefulBuilder(
            builder: (sCtx, setSState) {
              if (biometricChecking) {
                biometricChecking = false;
                _settingsService.isBiometricAvailable().then((avail) {
                  if (sCtx.mounted) {
                    setSState(() => biometricAvailable = avail);
                  }
                });
              }

              return Scaffold(
                backgroundColor: AppColors.scaffoldOf(sCtx),
                appBar: AppBar(
                  title: const Text('Settings & Security'),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // --- App Preferences Card ---
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(sCtx),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderOf(sCtx)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(sCtx),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: _settingsService.themeModeNotifier,
                            builder: (ctx, currentTheme, _) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.palette_outlined,
                                            color: AppColors.secondary,
                                            size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Appearance',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color:
                                                  AppColors.textPrimaryOf(ctx),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownButton<ThemeMode>(
                                    value: currentTheme,
                                    dropdownColor: AppColors.cardBg(ctx),
                                    style: TextStyle(
                                        color: AppColors.textPrimaryOf(ctx),
                                        fontSize: 13),
                                    underline: const SizedBox.shrink(),
                                    items: const [
                                      DropdownMenuItem(
                                          value: ThemeMode.system,
                                          child: Text('System Default')),
                                      DropdownMenuItem(
                                          value: ThemeMode.light,
                                          child: Text('Light Mode')),
                                      DropdownMenuItem(
                                          value: ThemeMode.dark,
                                          child: Text('Dark Mode')),
                                    ],
                                    onChanged: (mode) {
                                      if (mode != null) {
                                        _settingsService.setThemeMode(mode);
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          Divider(color: AppColors.borderOf(sCtx)),
                          ValueListenableBuilder<String>(
                            valueListenable: _settingsService.languageNotifier,
                            builder: (ctx, currentLang, _) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.language_rounded,
                                            color: AppColors.primary, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Language',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color:
                                                  AppColors.textPrimaryOf(ctx),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: currentLang,
                                    dropdownColor: AppColors.cardBg(ctx),
                                    style: TextStyle(
                                        color: AppColors.textPrimaryOf(ctx),
                                        fontSize: 13),
                                    underline: const SizedBox.shrink(),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'en',
                                          child: Text('English (EN)')),
                                      DropdownMenuItem(
                                          value: 'bn',
                                          child: Text('বাংলা (BN)')),
                                    ],
                                    onChanged: (lang) {
                                      if (lang != null) {
                                        _settingsService.setLanguage(lang);
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          Divider(color: AppColors.borderOf(sCtx)),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(
                                Icons.notifications_active_outlined,
                                color: AppColors.primary,
                                size: 20),
                            title: Text(
                              'Notification Preferences',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(sCtx),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _showNotificationPreferencesSheet(notifPrefs),
                          ),
                          Divider(color: AppColors.borderOf(sCtx)),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.privacy_tip_outlined,
                                color: AppColors.success, size: 20),
                            title: Text(
                              'Privacy & Map Visibility',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(sCtx),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _showPrivacySettingsSheet(privacySettings),
                          ),
                          Divider(color: AppColors.borderOf(sCtx)),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.card_giftcard_rounded,
                                color: AppColors.imperialGold, size: 20),
                            title: Text(
                              'Lifesaver Referral Program (+50 Pts)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(sCtx),
                              ),
                            ),
                            subtitle: Text(
                              'Code: $referralCode • $referralCount donor(s) referred',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(sCtx),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => showReferralProgramSheet(
                              sCtx,
                              referralCode: referralCode,
                              referralCount: referralCount,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Account Security & Biometrics Card ---
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(sCtx),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderOf(sCtx)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Security',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(sCtx),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.fingerprint_rounded,
                                color: AppColors.primary, size: 22),
                            title: Text(
                              'Biometric App Lock (Face / Fingerprint)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(sCtx),
                              ),
                            ),
                            subtitle: Text(
                              biometricAvailable
                                  ? 'Require Face Unlock or Fingerprint when opening RedCellNet'
                                  : 'Biometric hardware not enrolled or unavailable on this device',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(sCtx),
                              ),
                            ),
                            value: biometricEnabled && biometricAvailable,
                            activeThumbColor: AppColors.success,
                            onChanged: !biometricAvailable
                                ? null
                                : (enable) async {
                                    if (enable) {
                                      final verified = await _settingsService
                                          .authenticateWithBiometrics(
                                        reason:
                                            'Confirm your Face or Fingerprint to enable Biometric Lock',
                                      );
                                      if (!verified) {
                                        if (sCtx.mounted) {
                                          ScaffoldMessenger.of(sCtx)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Biometric verification cancelled.'),
                                              backgroundColor:
                                                  AppColors.warning,
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    await _settingsService
                                        .setBiometricLockEnabled(enable);
                                    setSState(() => biometricEnabled = enable);
                                    if (sCtx.mounted) {
                                      ScaffoldMessenger.of(sCtx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            enable
                                                ? 'Biometric Lock (Face / Fingerprint) enabled!'
                                                : 'Biometric Lock disabled.',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  },
                          ),
                          Divider(color: AppColors.borderOf(sCtx)),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.lock_outline_rounded,
                                color: AppColors.secondary, size: 20),
                            title: Text(
                              'Change Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(sCtx),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _showChangePasswordDialog,
                          ),
                          Divider(color: AppColors.borderOf(sCtx)),
                          if (deletionRequested)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.hourglass_top_rounded,
                                          color: AppColors.warning,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Account Deletion Pending Admin/Staff Approval',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: AppColors.textPrimaryOf(
                                                sCtx),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Your deletion request has been sent to RedCellNet Admin/Staff for review. You can cancel this request anytime before approval.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: AppColors.textSecondaryOf(sCtx),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await _profileService
                                              .cancelAccountDeletionRequest();
                                          setSState(
                                              () => deletionRequested = false);
                                          if (sCtx.mounted) {
                                            ScaffoldMessenger.of(sCtx)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Account deletion request cancelled.',
                                                ),
                                                backgroundColor:
                                                    AppColors.success,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (sCtx.mounted) {
                                            ScaffoldMessenger.of(sCtx)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor:
                                                    AppColors.critical,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.undo_rounded,
                                          size: 16),
                                      label: const Text(
                                          'Cancel Deletion Request'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.delete_forever_rounded,
                                  color: AppColors.critical, size: 20),
                              title: const Text(
                                'Delete Account (Requires Admin/Staff Approval)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.critical,
                                ),
                              ),
                              subtitle: Text(
                                'Submit a permanent profile deletion request for Admin/Staff approval',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryOf(sCtx),
                                ),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () => _showDeleteAccountDialog(
                                activeContext: sCtx,
                                onSubmitted: () {
                                  if (sCtx.mounted) {
                                    setSState(() => deletionRequested = true);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Log Out Button Inside Settings ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.critical,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _logout(sCtx),
                        icon: const Icon(Icons.logout_rounded, size: 19),
                        label: const Text(
                          'Log Out of RedCellNet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldOf(context),
        appBar: AppBar(title: Text(_settingsService.tr('nav_profile'))),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    return StreamBuilder<ProfileSnapshot>(
      stream: _profileStream ??
          _profileService.getUserProfileStream(currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            appBar: AppBar(title: Text(_settingsService.tr('nav_profile'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            appBar: AppBar(title: Text(_settingsService.tr('nav_profile'))),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            appBar: AppBar(title: Text(_settingsService.tr('nav_profile'))),
            body: const Center(child: Text('Profile not found.')),
          );
        }

        final userData = snapshot.data!.data() ?? {};
        final String role =
            (userData['role'] ?? 'user').toString().toLowerCase();
        final bool isStaff = role == 'admin' || role == 'moderator';
        if (isStaff) {
          return const AdminDashboardPage();
        }

        final String name = (userData['name'] ?? '').toString();
        final String nickname = (userData['nickname'] ?? '').toString();
        final String email =
            (userData['email'] ?? currentUserEmail ?? '').toString();
        final String bloodType = BloodCompatibility.normalizeBloodGroup(
                userData['bloodType']?.toString()) ??
            '';
        final String phone = (userData['phoneNumber'] ?? '').toString();
        final bool isPhoneVerified = userData['isPhoneVerified'] == true;
        final String city = (userData['locationCity'] ?? '').toString();
        final int points = (userData['points'] as int?) ?? 0;
        final bool isAvailable = userData['isAvailableToDonate'] == true;
        final String verificationStatus =
            (userData['verificationStatus'] ?? 'unverified')
                .toString()
                .toLowerCase();
        final String? verificationDocUrl =
            userData['verificationDocUrl']?.toString();
        final String? rejectionReason =
            userData['rejectionReason']?.toString();
        final dynamic badges = userData['badges'];
        final dynamic history = userData['donationHistory'];
        final Map<String, dynamic> notifPrefs =
            userData['notificationPreferences'] is Map
                ? Map<String, dynamic>.from(
                    userData['notificationPreferences'] as Map)
                : const <String, dynamic>{};
        final Map<String, dynamic> privacySettings =
            userData['privacySettings'] is Map
                ? Map<String, dynamic>.from(
                    userData['privacySettings'] as Map)
                : const <String, dynamic>{};
        final bool shareStatsOnPass =
            privacySettings['share_stats_on_pass'] != false;

        final tier = _getDonorTier(points);
        final tierColor = _getTierColor(points);

        final String emergencyContactName =
            (userData['emergencyContactName'] ?? '').toString();
        final String emergencyContactPhone =
            (userData['emergencyContactPhone'] ?? '').toString();
        final String medicalNotes =
            (userData['medicalNotes'] ?? '').toString();

        final DateTime? lastDonDate = userData['lastDonationDate'] != null
            ? DateTime.tryParse(userData['lastDonationDate'].toString())
            : null;
        final DateTime? nextEligDate = userData['nextEligibleDate'] != null
            ? DateTime.tryParse(userData['nextEligibleDate'].toString())
            : null;
        final eligibility = BloodCompatibility.checkEligibility(
          lastDonationDate: lastDonDate,
          nextEligibleDate: nextEligDate,
          cooldownDays: (userData['cooldownDays'] as int?) ?? 90,
        );

        final String formattedLastDonation = lastDonDate != null
            ? DateFormat.yMMMd().format(lastDonDate.toLocal())
            : '';
        final String formattedNextEligible =
            eligibility.nextEligibleDate != null
                ? DateFormat.yMMMd()
                    .format(eligibility.nextEligibleDate!.toLocal())
                : '';

        final int verifiedDonationCount =
            (userData['totalDonations'] as int?) ?? 0;
        final List<dynamic> historyList =
            history is List ? history : const <dynamic>[];
        final bool isStreakFrozen = userData['streakFrozen'] == true ||
            AppSettingsService().isStreakFrozen;
        final String? streakFreezeReason =
            userData['streakFreezeReason']?.toString() ??
                AppSettingsService().streakFreezeReason;
        final int computedStreak = AppSettingsService().computeDonorStreak(
          historyList,
          isFrozenOverride: isStreakFrozen,
          fallbackDonationsCount: verifiedDonationCount,
        );
        final String referralCode = (userData['referralCode'] ?? '')
                .toString()
                .trim()
                .isNotEmpty
            ? userData['referralCode'].toString().trim()
            : AppSettingsService.generateReferralCode(
                userId: currentUserId,
                fullName: name,
                bloodGroup: bloodType,
              );
        final int referralCount = (userData['referralCount'] as int?) ?? 0;
        final String donorId =
            (currentUserId != null && currentUserId!.length >= 8)
                ? 'RCN-${currentUserId!.substring(0, 8).toUpperCase()}'
                : 'RCN-MEMBER';

        return Scaffold(
          backgroundColor: AppColors.scaffoldOf(context),
          appBar: AppBar(
            title: Text(_settingsService.tr('nav_profile')),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Donor Profile',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfilePage()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.emoji_events_outlined),
                tooltip: 'Recognition & Milestones',
                onPressed: () => _openRecognitionAndMilestonesPage(
                  userData: userData,
                  name: name,
                  bloodType: bloodType,
                  city: city,
                  referralCode: referralCode,
                  points: points,
                  badges: badges,
                  history: history,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings & Account Security',
                onPressed: () => _openProfileSettingsPage(
                  userData: userData,
                  notifPrefs: notifPrefs,
                  privacySettings: privacySettings,
                  name: name,
                  bloodType: bloodType,
                  donorId: donorId,
                  city: city,
                  nextEligibleText: formattedNextEligible,
                  isVerified: verificationStatus == 'verified',
                  isEligible: eligibility.isEligible,
                  totalDonations: verifiedDonationCount,
                  points: points,
                  referralCode: referralCode,
                  referralCount: referralCount,
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              if (mounted) {
                setState(() {
                  _initStream();
                });
              }
            },
            color: AppColors.primary,
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              children: [
                // Top Tier Badge Pill (tappable to open Recognition & Milestones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openRecognitionAndMilestonesPage(
                      userData: userData,
                      name: name,
                      bloodType: bloodType,
                      city: city,
                      referralCode: referralCode,
                      points: points,
                      badges: badges,
                      history: history,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: tierColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded,
                                  size: 14, color: tierColor),
                              const SizedBox(width: 6),
                              Text(
                                tier.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: tierColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$points Life Points',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Pending Account Deletion Request Banner (if submitted) ---
                if (userData['deletionRequested'] == true &&
                    (userData['deletionRequestStatus'] ?? 'pending')
                            .toString() ==
                        'pending')
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            color: AppColors.warning, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Deletion Pending Admin/Staff Approval',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Your profile deletion request is awaiting review by RedCellNet staff. Availability is currently paused.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor:
                                      AppColors.warning.withValues(alpha: 0.15),
                                ),
                                onPressed: () async {
                                  try {
                                    await _profileService
                                        .cancelAccountDeletionRequest();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Account deletion request cancelled.',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: AppColors.critical,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.undo_rounded, size: 15),
                                label: const Text(
                                  'Cancel Deletion Request',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- 3D Flippable Digital Pass Card (Contains all Donor Details inside) ---
                DigitalPassCard(
                  donorName: name.isNotEmpty ? name : 'Community Lifesaver',
                  nickname: nickname,
                  email: email,
                  phone: phone,
                  bloodType: bloodType,
                  donorId: donorId,
                  isVerified: verificationStatus == 'verified',
                  verificationStatus: verificationStatus,
                  isAvailable: isAvailable && eligibility.isEligible,
                  totalDonations: shareStatsOnPass ? verifiedDonationCount : 0,
                  livesSaved:
                      shareStatsOnPass ? (verifiedDonationCount * 3) : 0,
                  lastDonationDate: formattedLastDonation,
                  nextEligibleDate: formattedNextEligible,
                  emergencyContact: emergencyContactPhone.isNotEmpty
                      ? (emergencyContactName.isNotEmpty
                          ? '$emergencyContactName ($emergencyContactPhone)'
                          : emergencyContactPhone)
                      : phone,
                  points: points,
                  streakCount: computedStreak,
                  isStreakFrozen: isStreakFrozen,
                  streakFreezeReason: streakFreezeReason,
                  isEligible: eligibility.isEligible,
                  daysUntilEligible: eligibility.daysRemaining,
                  city: city,
                  isPhoneVerified: isPhoneVerified,
                  medicalNotes: medicalNotes,
                  referralCode: referralCode,
                  referralCount: referralCount,
                  showActionDock: true,
                  onStreakFreezeChanged: (frozen) {
                    if (currentUserId != null && currentUserId!.isNotEmpty) {
                      _profileService.toggleMedicalStreakFreeze(
                        uid: currentUserId!,
                        frozen: frozen,
                        reason: AppSettingsService().streakFreezeReason,
                      );
                    }
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 14),

                // --- Medical Healing & Recovery Interval Banner (90-Day WHO Safe Interval) ---
                if (!eligibility.isEligible &&
                    eligibility.nextEligibleDate != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.isDark(context)
                          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: AppColors.success, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Healing & Recovery Period',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: AppColors.isDark(context)
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${eligibility.daysRemaining} d left',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your body is replenishing red blood cells and iron stores. Medically eligible on ${DateFormat.yMMMd().format(eligibility.nextEligibleDate!.toLocal())} (90-day safe interval).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.isDark(context)
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF166534),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- Availability Switch Card ---
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isAvailable && eligibility.isEligible)
                        ? (AppColors.isDark(context)
                            ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                            : const Color(0xFFF0FDF4))
                        : AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: (isAvailable && eligibility.isEligible)
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.borderOf(context),
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      (isAvailable && eligibility.isEligible)
                          ? 'Available to Donate'
                          : (!eligibility.isEligible
                              ? 'Recovery Cooldown Active'
                              : 'Unavailable (Off-Duty)'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: (isAvailable && eligibility.isEligible)
                            ? (AppColors.isDark(context)
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534))
                            : AppColors.textPrimaryOf(context),
                      ),
                    ),
                    subtitle: Text(
                      !eligibility.isEligible
                          ? 'Protected for ${eligibility.daysRemaining} more day(s) until safe recovery completes'
                          : (isAvailable
                              ? 'Receiving alerts for compatible urgent blood needs'
                              : 'Turn on to receive nearby compatible emergency requests'),
                      style: TextStyle(
                        fontSize: 12,
                        color: (isAvailable && eligibility.isEligible)
                            ? (AppColors.isDark(context)
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFF15803D))
                            : AppColors.textSecondaryOf(context),
                      ),
                    ),
                    value: isAvailable && eligibility.isEligible,
                    activeThumbColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (newValue) async {
                      if (newValue && bloodType.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please set your blood group in Edit Profile before going available.'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfilePage()),
                        );
                        return;
                      }

                      if (newValue && !eligibility.isEligible) {
                        showDialog(
                          context: context,
                          builder: (warnCtx) => AlertDialog(
                            backgroundColor: AppColors.cardBg(warnCtx),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: AppColors.borderSideOf(warnCtx),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.health_and_safety_rounded,
                                    color: AppColors.success, size: 22),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '90-Day Recovery Protected',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'For your safety and WHO clinical guidelines, availability cannot be enabled during your 90-day whole-blood recovery interval (${eligibility.daysRemaining} day(s) remaining). You will be eligible again on $formattedNextEligible.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondaryOf(warnCtx),
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(warnCtx),
                                child: const Text('Understood'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }

                      try {
                        final List<dynamic> currentBadges =
                            List<dynamic>.from(userData['badges'] ?? []);
                        bool awardStandby = false;
                        if (newValue &&
                            !currentBadges
                                .map((e) => e.toString())
                                .contains('Standby Guardian')) {
                          currentBadges.add('Standby Guardian');
                          awardStandby = true;
                        }

                        await _profileService.updateUserProfile(
                          currentUserId!,
                          {
                            'isAvailableToDonate': newValue,
                            'availabilityStatus':
                                newValue ? 'available' : 'unavailable',
                            if (awardStandby) ...{
                              'badges': currentBadges,
                              'points': points + 30,
                            },
                          },
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newValue
                                    ? 'Availability status: Ready to Donate!'
                                    : 'Availability status: Off-Duty',
                              ),
                              backgroundColor: newValue
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.critical,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // --- Donor Verification Status Card ---
                _buildVerificationStatusCard(
                  context,
                  verificationStatus: verificationStatus,
                  bloodType: bloodType,
                  donorName: name,
                  isPhoneVerified: isPhoneVerified,
                  hasIceContact: emergencyContactPhone.trim().isNotEmpty,
                  verificationLab: userData['verificationLab']?.toString(),
                  verificationCert: userData['verificationCert']?.toString(),
                  verificationNotes: userData['verificationNotes']?.toString(),
                  verificationDocUrl: verificationDocUrl,
                  rejectionReason: rejectionReason,
                ),
                const SizedBox(height: 14),

                // --- Medical ICE Emergency Card ---
                _buildMedicalICECard(
                  context,
                  name: name,
                  bloodType: bloodType,
                  contactName: emergencyContactName,
                  contactPhone: emergencyContactPhone,
                  medicalNotes: medicalNotes,
                  primaryPhone: phone,
                  uid: currentUserId ?? '',
                ),

                // --- Collapsible Clinical & Wellness Tools Strip ---
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.medical_services_outlined,
                            color: AppColors.primary, size: 18),
                      ),
                      title: Text(
                        'Clinical Tools & Community Hub',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      subtitle: Text(
                        'Self-Triage, Compatibility, Hb Journal & Blood Camps',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    showDonorSelfTriageSheet(context),
                                icon: const Icon(Icons.checklist_rounded,
                                    size: 15, color: Color(0xFF10B981)),
                                label: const Text('60s Triage',
                                    style: TextStyle(fontSize: 11.5)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showCompatibilityMatrixSheet(
                                    context, bloodType),
                                icon: const Icon(Icons.sync_alt_rounded,
                                    size: 15, color: AppColors.primary),
                                label: const Text('Compatibility',
                                    style: TextStyle(fontSize: 11.5)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => showHealthJournalSheet(
                                  context,
                                  donorName: name,
                                  bloodType: bloodType,
                                ),
                                icon: const Icon(Icons.monitor_heart_rounded,
                                    size: 15, color: AppColors.secondary),
                                label: const Text('Hb Journal',
                                    style: TextStyle(fontSize: 11.5)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    showBloodCampCalendarSheet(context),
                                icon: const Icon(Icons.event_available_rounded,
                                    size: 15, color: AppColors.accent),
                                label: const Text('Blood Camps',
                                    style: TextStyle(fontSize: 11.5)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationStatusCard(
    BuildContext context, {
    required String verificationStatus,
    required String bloodType,
    required String donorName,
    required bool isPhoneVerified,
    required bool hasIceContact,
    String? verificationLab,
    String? verificationCert,
    String? verificationNotes,
    String? verificationDocUrl,
    String? rejectionReason,
  }) {
    final isDark = AppColors.isDark(context);
    final bool hasBloodGroup = bloodType.trim().isNotEmpty;
    final bool hasLabVerified = verificationStatus == 'verified';
    final bool isPending = verificationStatus == 'pending';
    final bool isRejected = verificationStatus == 'rejected';

    Widget buildPillarRow() {
      Widget pillar(
        String label,
        String sub,
        bool done, {
        bool pending = false,
      }) {
        final Color c = done
            ? AppColors.success
            : (pending
                ? AppColors.warning
                : AppColors.textSecondaryOf(context));
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: c.withValues(alpha: done || pending ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: c.withValues(alpha: done || pending ? 0.35 : 0.18)),
            ),
            child: Column(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : (pending
                          ? Icons.schedule_rounded
                          : Icons.radio_button_unchecked_rounded),
                  size: 15,
                  color: c,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Row(
        children: [
          pillar(
            'ABO / Rh',
            hasBloodGroup ? bloodType : 'Required',
            hasBloodGroup,
          ),
          const SizedBox(width: 8),
          pillar(
            'ICE Contact',
            hasIceContact ? 'Configured' : 'Add ICE',
            hasIceContact,
          ),
          const SizedBox(width: 8),
          pillar(
            'Lab / Card',
            hasLabVerified
                ? 'Verified'
                : (isPending ? 'In Review' : 'Pending'),
            hasLabVerified,
            pending: isPending,
          ),
        ],
      );
    }

    if (verificationStatus == 'verified') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.success.withValues(alpha: 0.15)
              : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: AppColors.success, size: 22),
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
                              'Donor Verification',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Verified by RedCellNet',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        verificationLab != null && verificationLab.isNotEmpty
                            ? 'Accredited Lab: $verificationLab${verificationCert != null && verificationCert.isNotEmpty ? " • #$verificationCert" : ""}'
                            : 'Your blood group evidence has been verified by RedCellNet staff.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            buildPillarRow(),
          ],
        ),
      );
    }

    final Color accent = isRejected ? AppColors.critical : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded,
                  color: accent,
                  size: 22,
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
                            'Donor Verification',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            isRejected
                                ? 'Resubmission Needed'
                                : 'Verification Pending',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRejected
                          ? (rejectionReason != null &&
                                  rejectionReason.trim().isNotEmpty
                              ? rejectionReason
                              : 'Please upload a clearer laboratory blood group report or donor card.')
                          : (isPending
                              ? 'Medical moderators are reviewing your submitted report. Stored document will be purged automatically after review.'
                              : 'Submit your lab blood group report or donor card (Red Crescent, Sandhani, Badhan, Popular, Ibn Sina) to unlock your Verified by RedCellNet badge.'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: isRejected
                            ? AppColors.critical
                            : AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          buildPillarRow(),
          if (!isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.document_scanner_rounded, size: 17),
                onPressed: () => _showRequestVerificationDialog(
                  currentBloodType: bloodType,
                  donorName: donorName,
                  initialLab: verificationLab,
                  initialCert: verificationCert,
                  initialNotes: verificationNotes,
                ),
                label: Text(
                  isRejected
                      ? 'Resubmit Lab Report / Donor Card'
                      : 'Submit Lab Report / Donor Card',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgesGrid(dynamic userBadgesData) {
    final List<String> earnedIds = userBadgesData is List
        ? List<String>.from(userBadgesData.map((e) => e.toString()))
        : [];
    final isDark = AppColors.isDark(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _badgeDetails.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final badgeKey = _badgeDetails.keys.elementAt(index);
        final badge = _badgeDetails[badgeKey]!;
        final bool isEarned = earnedIds.contains(badgeKey);

        return GestureDetector(
          onTap: () => _showBadgeDetailSheet(badgeKey, isEarned),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isEarned
                  ? AppColors.cardBg(context)
                  : (isDark
                      ? AppColors.surfaceMutedOf(context)
                      : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEarned
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.borderOf(context),
                width: isEarned ? 1.5 : 1.0,
              ),
              boxShadow: (isEarned && !isDark) ? AppColors.softShadow : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? (isDark
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.primaryContainer)
                        : (isDark
                            ? AppColors.surfaceOf(context)
                            : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge['icon'] as IconData,
                    color: isEarned
                        ? AppColors.primary
                        : AppColors.textMutedOf(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isEarned
                              ? AppColors.textPrimaryOf(context)
                              : AppColors.textMutedOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEarned ? 'Unlocked' : 'Locked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isEarned
                              ? AppColors.success
                              : AppColors.textMutedOf(context),
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
    );
  }

  Widget _buildDonationHistory(
      dynamic historyData, String donorName, String bloodType) {
    final isDark = AppColors.isDark(context);

    if (historyData == null || historyData is! List || historyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded,
                size: 36, color: AppColors.textMutedOf(context)),
            const SizedBox(height: 8),
            Text(
              'No donation history recorded yet',
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showLogDonationDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Log a Past Donation'),
            ),
          ],
        ),
      );
    }

    final List<dynamic> historyList = List<dynamic>.from(historyData);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: historyList.length,
      itemBuilder: (context, index) {
        final donation = historyList[index];
        String formattedDate = 'Recent Date';
        String location = 'Hospital Donation';
        String units = '1';
        bool isVerifiedRecord = false;
        Map<String, dynamic> donationMap = {};

        if (donation is Map) {
          donationMap = Map<String, dynamic>.from(donation);
          final date = donationMap['date'];
          location = (donationMap['hospital'] ??
                  donationMap['location'] ??
                  'Hospital Donation')
              .toString();
          units = donationMap['units']?.toString() ?? '1';
          isVerifiedRecord = donationMap['verified'] == true;
          if (date is Timestamp) {
            formattedDate =
                DateFormat.yMMMd().format(date.toDate().toLocal());
          } else if (date is DateTime) {
            formattedDate = DateFormat.yMMMd().format(date.toLocal());
          } else if (date is String) {
            final parsed = DateTime.tryParse(date);
            formattedDate = parsed != null
                ? DateFormat.yMMMd().format(parsed.toLocal())
                : date;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: isDark ? null : AppColors.softShadow,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isVerifiedRecord
                    ? AppColors.success.withValues(alpha: 0.16)
                    : AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVerifiedRecord
                    ? Icons.verified_rounded
                    : Icons.water_drop_rounded,
                color: isVerifiedRecord ? AppColors.success : AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              location,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            subtitle: Text(
              '$formattedDate • ${isVerifiedRecord ? "Verified Hospital Donation" : "Self-Logged Record"}',
              style: TextStyle(
                fontSize: 11.5,
                color: isVerifiedRecord
                    ? AppColors.success
                    : AppColors.textSecondaryOf(context),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Official Lifesaver Certificate is ONLY issued for verified hospital donations!
                if (isVerifiedRecord)
                  IconButton(
                    icon: const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFD97706), size: 22),
                    tooltip: 'View Verified Lifesaver Certificate',
                    onPressed: () {
                      showDonationCertificateDialog(
                        context,
                        donation: donationMap,
                        donorName: donorName,
                        bloodType:
                            bloodType.isNotEmpty ? bloodType : 'Verified',
                      );
                    },
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$units Unit(s)',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFF166534),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Interactive Component-Specific Transfusion Compatibility Matrix Modal
class _CompatibilityMatrixModalContent extends StatefulWidget {
  final ScrollController scrollController;
  final String initialBloodGroup;

  const _CompatibilityMatrixModalContent({
    required this.scrollController,
    required this.initialBloodGroup,
  });

  @override
  State<_CompatibilityMatrixModalContent> createState() =>
      _CompatibilityMatrixModalContentState();
}

class _CompatibilityMatrixModalContentState
    extends State<_CompatibilityMatrixModalContent> {
  late String _selectedGroup;
  String _selectedComponent = 'Whole Blood';

  static const List<String> _allGroups = BloodCompatibility.validBloodGroups;
  static const List<String> _components =
      BloodCompatibility.supportedComponents;

  @override
  void initState() {
    super.initState();
    _selectedGroup = _allGroups.contains(widget.initialBloodGroup)
        ? widget.initialBloodGroup
        : 'O+';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final canDonate = BloodCompatibility.canDonateTo(
      _selectedGroup,
      componentType: _selectedComponent,
    );
    final canReceive = BloodCompatibility.canReceiveFrom(
      _selectedGroup,
      componentType: _selectedComponent,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_alt_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transfusion Compatibility',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        Text(
                          'Component-Aware Screening Matrix',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'SELECT BLOOD GROUP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMutedOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allGroups.map((g) {
                    final isSel = g == _selectedGroup;
                    return ChoiceChip(
                      label: Text(
                        g,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isSel
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedGroup = g);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'SELECT BLOOD COMPONENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMutedOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _components.map((comp) {
                    final isSel = comp == _selectedComponent;
                    return ChoiceChip(
                      label: Text(
                        comp,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isSel
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.secondary,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedComponent = comp);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _buildCompatibilitySection(
                  title: '$_selectedGroup CAN DONATE $_selectedComponent TO',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFF10B981),
                  groups: canDonate,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildCompatibilitySection(
                  title: '$_selectedGroup CAN RECEIVE $_selectedComponent FROM',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  groups: canReceive,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.medical_information_rounded,
                          color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          BloodCompatibility.medicalCrossMatchDisclaimer,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> groups,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                '${groups.length} Compatible',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groups.map((g) {
              final isCurrent = g == _selectedGroup;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? iconColor.withValues(alpha: 0.18)
                      : (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent ? iconColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  g,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isCurrent
                        ? iconColor
                        : AppColors.textPrimaryOf(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
