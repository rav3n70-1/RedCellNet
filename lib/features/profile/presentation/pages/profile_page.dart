// lib/features/profile/presentation/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/edit_profile_page.dart';

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

  final Map<String, Map<String, dynamic>> _badgeDetails = {
    'First Drop': {
      'name': 'First Drop',
      'icon': Icons.water_drop_rounded,
      'desc': 'Completed your first lifesaver blood donation',
      'pts': 25
    },
    'High Five': {
      'name': 'High Five',
      'icon': Icons.thumb_up_alt_rounded,
      'desc': 'Completed 5 blood donations',
      'pts': 50
    },
    'Double Digits': {
      'name': 'Double Digits',
      'icon': Icons.stars_rounded,
      'desc': 'Completed 10 blood donations',
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
      'desc': 'Referred community donors to the app',
      'pts': 20
    },
    'Health Aware': {
      'name': 'Health Aware',
      'icon': Icons.school_rounded,
      'desc': 'Read educational articles in the learn tab',
      'pts': 10
    },
    'Profile Complete': {
      'name': 'Profile Complete',
      'icon': Icons.verified_user_rounded,
      'desc': 'Completed full verified donor contact & blood info',
      'pts': 15
    },
    'Standby Guardian': {
      'name': 'Standby Guardian',
      'icon': Icons.shield_rounded,
      'desc': 'Stayed ready & available to donate for emergencies',
      'pts': 30
    },
    'Legend Donor': {
      'name': 'Legend Donor',
      'icon': Icons.emoji_events_rounded,
      'desc': 'Top tier lifesaver award (over 15 donations)',
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

  Future<void> _logout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out of RedCellNet?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        await SupabaseAuthService().signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Logout error: $e"), backgroundColor: AppColors.critical),
          );
        }
      }
    }
  }

  void _showBadgeDetailSheet(String badgeKey, bool isEarned) {
    final badge = _badgeDetails[badgeKey];
    if (badge == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isEarned ? AppColors.primaryContainer : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badge['icon'] as IconData,
                  color: isEarned ? AppColors.primary : AppColors.textMuted,
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                badge['name'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isEarned ? AppColors.successLight : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isEarned ? 'UNLOCKED • +${badge['pts']} Life Points' : 'LOCKED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isEarned ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                badge['desc'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
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

  // --- Request Donor Verification Dialog ---
  void _showRequestVerificationDialog() {
    final labCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text("Request Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Get the official Verified Donor shield badge by submitting your certified blood test or donor card details for moderation review.",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: labCtrl,
                  decoration: const InputDecoration(
                    labelText: "Diagnostic Lab / Hospital *",
                    hintText: "e.g. Popular Diagnostic / Red Crescent",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: certCtrl,
                  decoration: const InputDecoration(
                    labelText: "Report ID or Certificate #",
                    hintText: "e.g. LAB-2026-9812",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Additional Notes (optional)",
                    hintText: "e.g. Tested O+ blood group at annual camp",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (labCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("Please enter the lab or facility name.")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _profileService.updateUserProfile(currentUserId!, {
                    'verificationStatus': 'pending',
                    'verificationLab': labCtrl.text.trim(),
                    'verificationCert': certCtrl.text.trim(),
                    'verificationNotes': notesCtrl.text.trim(),
                    'verificationRequestedAt': DateTime.now().toUtc().toIso8601String(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Verification submitted! Our moderation team will review your record."),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.critical),
                    );
                  }
                }
              },
              child: const Text("Submit Record"),
            ),
          ],
        );
      },
    );
  }

  void _showLogDonationDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final hospitalController = TextEditingController();
    final unitsController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.water_drop_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Log Blood Donation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Record a recent blood donation to keep your history up-to-date and earn +10 Life Points!',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: hospitalController,
                decoration: const InputDecoration(
                  labelText: 'Hospital or Center Name',
                  hintText: 'e.g. Red Crescent Blood Center',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Units Donated',
                  prefixIcon: Icon(Icons.bloodtype_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (hospitalController.text.trim().isEmpty) return;
                Navigator.pop(dialogCtx);
                try {
                  final newEntry = {
                    'location': hospitalController.text.trim(),
                    'units': int.tryParse(unitsController.text.trim()) ?? 1,
                    'date': DateTime.now().toUtc().toIso8601String(),
                  };
                  final userSnap = await _profileService.getUserProfile(currentUserId!);
                  final currentHistory = List<dynamic>.from(userSnap.data()?['donation_history'] ?? []);
                  currentHistory.add(newEntry);
                  final int newPts = (userSnap.data()?['points'] as int? ?? 0) + 10;
                  final int newTotal = (userSnap.data()?['total_donations'] as int? ?? 0) + 1;

                  await _profileService.updateUserProfile(currentUserId!, {
                    'donationHistory': currentHistory,
                    'points': newPts,
                    'totalDonations': newTotal,
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Donation logged successfully! +10 Life Points added.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error logging donation: $e'), backgroundColor: AppColors.critical),
                  );
                }
              },
              child: const Text('Save Donation'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donor Profile')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfilePage()),
            ),
          ),
          const NotificationBellAction(),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<ProfileSnapshot>(
        stream: _profileService.getUserProfileStream(currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final userData = snapshot.data!.data() ?? {};
          final String name = userData['name'] ?? '';
          final String email = userData['email'] ?? currentUserEmail ?? '';
          final String bloodType = userData['bloodType'] ?? '';
          final String phone = userData['phoneNumber'] ?? '';
          final String city = userData['locationCity'] ?? '';
          final int points = userData['points'] ?? 0;
          final bool isAvailable = userData['isAvailableToDonate'] ?? false;
          final String verificationStatus = userData['verificationStatus'] ?? 'unverified';
          final String role = userData['role'] ?? 'user';
          final dynamic badges = userData['badges'];
          final dynamic history = userData['donationHistory'];

          final tier = _getDonorTier(points);
          final tierColor = _getTierColor(points);

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() {});
            },
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              children: [
                // --- Premium Donor Identity Card ---
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.glowPrimary,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white,
                            child: Text(
                              (name.isNotEmpty
                                      ? name[0]
                                      : email.isNotEmpty
                                          ? email[0]
                                          : 'D')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name.isNotEmpty ? name : 'Blood Donor',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.4,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    VerificationBadge(status: verificationStatus, compact: true),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Tier pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shield_rounded, size: 13, color: tierColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        tier,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (bloodType.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                bloodType,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Glass Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  '$points Pts',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 18,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  '${badges is List ? badges.length : 0} Badges',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // --- Donor Verification Prompt (if unverified or rejected) ---
                if (verificationStatus.toLowerCase() != 'verified') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: verificationStatus.toLowerCase() == 'pending'
                          ? AppColors.warningLight
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: verificationStatus.toLowerCase() == 'pending'
                            ? AppColors.warning
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verificationStatus.toLowerCase() == 'pending'
                                    ? 'Verification In Review'
                                    : 'Become a Verified Donor',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                verificationStatus.toLowerCase() == 'pending'
                                    ? 'Moderators are reviewing your certified blood records.'
                                    : 'Upload or record your certified blood test to earn trust shield.',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (verificationStatus.toLowerCase() != 'pending')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _showRequestVerificationDialog,
                            child: const Text('Verify'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // --- Availability Switch Card ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAvailable
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: SwitchListTile(
                    title: Text(
                      isAvailable ? 'Available to Donate' : 'Unavailable (Off-Duty)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isAvailable ? const Color(0xFF166534) : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      isAvailable
                          ? 'You can receive notifications & calls for urgent blood needs'
                          : 'Turn on to let hospitals & recipients find you in emergencies',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAvailable ? const Color(0xFF15803D) : AppColors.textSecondary,
                      ),
                    ),
                    value: isAvailable,
                    activeThumbColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (newValue) async {
                      try {
                        await _profileService.updateUserProfile(
                            currentUserId!, {'isAvailableToDonate': newValue});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(newValue
                                  ? 'Availability status: Ready to Donate!'
                                  : 'Availability status: Off-duty'),
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
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.critical),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // --- Personal & Contact Information Card ---
                Container(
                  padding: const EdgeInsets.all(18.0),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Donor Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditProfilePage()),
                            ),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildProfileRow(
                        icon: Icons.bloodtype_outlined,
                        iconColor: AppColors.primary,
                        title: 'Blood Group',
                        value: bloodType.isNotEmpty ? bloodType : 'Not Set',
                      ),
                      const Divider(color: AppColors.divider),
                      _buildProfileRow(
                        icon: Icons.phone_outlined,
                        iconColor: AppColors.secondary,
                        title: 'Phone Number',
                        value: phone.isNotEmpty ? phone : 'Not Set',
                      ),
                      const Divider(color: AppColors.divider),
                      _buildProfileRow(
                        icon: Icons.location_on_outlined,
                        iconColor: AppColors.high,
                        title: 'City / Region',
                        value: city.isNotEmpty ? city : 'Not Set',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- App Settings Card (Theme & Language) ---
                Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preferences & Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Theme Selector
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: _settingsService.themeModeNotifier,
                        builder: (ctx, currentTheme, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.palette_outlined, color: AppColors.secondary, size: 20),
                                  SizedBox(width: 10),
                                  Text("Theme Mode", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              DropdownButton<ThemeMode>(
                                value: currentTheme,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: ThemeMode.system, child: Text("System Default")),
                                  DropdownMenuItem(value: ThemeMode.light, child: Text("Light Mode")),
                                  DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark Mode")),
                                ],
                                onChanged: (mode) {
                                  if (mode != null) _settingsService.setThemeMode(mode);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(color: AppColors.divider),

                      // Language Selector
                      ValueListenableBuilder<String>(
                        valueListenable: _settingsService.languageNotifier,
                        builder: (ctx, currentLang, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
                                  SizedBox(width: 10),
                                  Text("Language", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              DropdownButton<String>(
                                value: currentLang,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: 'en', child: Text("English (EN)")),
                                  DropdownMenuItem(value: 'bn', child: Text("বাংলা (BN)")),
                                ],
                                onChanged: (lang) {
                                  if (lang != null) _settingsService.setLanguage(lang);
                                },
                              ),
                            ],
                          );
                        },
                      ),

                      // Admin Console Option (Available to admins or test access)
                      const Divider(color: AppColors.divider),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 20),
                        ),
                        title: const Text("Admin & Moderation Console", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text("Role: $role • Manage verifications, reports, and facilities", style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- Gamification: Badges Earned ---
                SectionHeader(
                  title: 'Achievements & Badges',
                  subtitle: '${badges is List ? badges.length : 0} of ${_badgeDetails.length} badges unlocked (Tap to view)',
                  icon: Icons.military_tech_rounded,
                ),
                const SizedBox(height: 10),
                _buildBadgesGrid(badges),
                const SizedBox(height: 24),

                // --- Donation History Section ---
                SectionHeader(
                  title: 'Donation History',
                  subtitle: 'Your tracked life-saving contributions',
                  icon: Icons.history_rounded,
                  actionLabel: '+ Log Donation',
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

  Widget _buildProfileRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesGrid(dynamic userBadgesData) {
    final List<String> earnedIds = userBadgesData is List
        ? List<String>.from(userBadgesData.map((e) => e.toString()))
        : [];

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
              color: isEarned ? Colors.white : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEarned
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
                width: isEarned ? 1.5 : 1.0,
              ),
              boxShadow: isEarned ? AppColors.softShadow : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEarned ? AppColors.primaryContainer : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge['icon'] as IconData,
                    color: isEarned ? AppColors.primary : AppColors.textMuted,
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
                          color: isEarned ? AppColors.textPrimary : AppColors.textMuted,
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
                          color: isEarned ? AppColors.success : AppColors.textMuted,
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

  Widget _buildDonationHistory(dynamic historyData, String donorName, String bloodType) {
    if (historyData == null || historyData is! List || historyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 8),
            const Text(
              'No donation history recorded yet',
              style: TextStyle(
                color: AppColors.textSecondary,
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
        String location = 'Hospital';
        String units = '1';
        Map<String, dynamic> donationMap = {};

        if (donation is Map<String, dynamic>) {
          donationMap = donation;
          final date = donation['date'];
          location = donation['location'] ?? 'Hospital Donation';
          units = donation['units']?.toString() ?? '1';
          if (date is Timestamp) {
            formattedDate = DateFormat.yMMMd().format(date.toDate().toLocal());
          } else if (date is DateTime) {
            formattedDate = DateFormat.yMMMd().format(date.toLocal());
          } else if (date is String) {
            try {
              formattedDate = DateFormat.yMMMd().format(DateTime.parse(date).toLocal());
            } catch (_) {
              formattedDate = date;
            }
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.softShadow,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 20),
            ),
            title: Text(
              location,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Text(
              formattedDate,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 22),
                  tooltip: 'View Lifesaver Certificate',
                  onPressed: () {
                    showDonationCertificateDialog(
                      context,
                      donation: donationMap.isNotEmpty ? donationMap : {'date': formattedDate, 'hospital': location, 'units': units},
                      donorName: donorName,
                      bloodType: bloodType,
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$units Unit(s)',
                    style: const TextStyle(
                      color: Color(0xFF166534),
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
