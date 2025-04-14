// lib/features/profile/presentation/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserProfileService _profileService = UserProfileService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- Badge Definitions ---
  final Map<String, Map<String, dynamic>> _badgeDetails = {
    'First Drop': {'name': 'First Drop', 'icon': Icons.water_drop_outlined},
    'High Five': {'name': 'High Five', 'icon': Icons.thumb_up_alt_outlined},
    'Double Digits': {
      'name': 'Double Digits',
      'icon': Icons.filter_alt_outlined
    },
    'Rare Hero': {'name': 'Rare Hero', 'icon': Icons.star_outline},
    'Crisis Warrior': {
      'name': 'Crisis Warrior',
      'icon': Icons.local_fire_department_outlined
    },
    'Lifesaver Buddy': {
      'name': 'Lifesaver Buddy',
      'icon': Icons.group_add_outlined
    },
    'Health Aware': {'name': 'Health Aware', 'icon': Icons.school_outlined},
    'Profile Complete': {
      'name': 'Profile Complete',
      'icon': Icons.check_circle_outline
    },
    'Standby Guardian': {
      'name': 'Standby Guardian',
      'icon': Icons.shield_outlined
    },
    'Legend Donor': {
      'name': 'Legend Donor',
      'icon': Icons.emoji_events_outlined
    },
  };
  Map<String, dynamic> _getBadgeInfo(String badgeId) {
    return _badgeDetails[badgeId] ??
        {'name': badgeId, 'icon': Icons.circle_outlined};
  }
  // --- End Badge Definitions ---

  // --- Temporary function to add points REMOVED ---
  // Future<void> _addTestPoints(int currentPoints) async { ... }

  // --- Logout Method ---
  Future<void> _logout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmLogout == true) {
      try {
        print("Logging out user...");
        await FirebaseAuth.instance.signOut();
        print("User logged out successfully.");
      } catch (e) {
        print("Error during logout: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Logout failed: ${e.toString()}'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  // --- End Logout Method ---

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: const Center(child: Text('Error: No user logged in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditProfilePage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileService.getUserProfileStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading profile: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile data not found.'));
          }
          final userData = snapshot.data!.data();
          if (userData == null) {
            return const Center(child: Text('Profile data is empty.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: <Widget>[
                _buildProfileHeader(context, userData),
                const SizedBox(height: 16),
                // Points Display
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded,
                          color: Colors.amber[700], size: 28),
                      const SizedBox(width: 8),
                      Text((userData['points'] ?? 0).toString(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Text('Points',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.grey[700])),
                    ],
                  ),
                ),
                const Divider(),
                // Info Tiles
                _buildInfoTile(
                    icon: Icons.bloodtype_outlined,
                    title: 'Blood Type',
                    value: userData['bloodType'] ?? 'Not Set'),
                const Divider(height: 1, thickness: 1, indent: 50),
                _buildInfoTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone Number',
                    value: userData['phoneNumber']?.isNotEmpty ?? false
                        ? userData['phoneNumber']
                        : 'Not Set'),
                const Divider(height: 1, thickness: 1, indent: 50),
                _buildInfoTile(
                    icon: Icons.location_city_outlined,
                    title: 'City/Area',
                    value: userData['locationCity']?.isNotEmpty ?? false
                        ? userData['locationCity']
                        : 'Not Set'),
                const Divider(height: 1, thickness: 1, indent: 50),
                _buildAvailabilityTile(userData['isAvailableToDonate'] ?? false,
                    currentUser!.uid), // Interactive Toggle
                const Divider(height: 1, thickness: 1),
                // Badges Section
                const SizedBox(height: 24),
                Text('Badges Earned',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildBadgesSection(userData['badges']),
                const SizedBox(height: 24), const Divider(),
                // Donation History Section
                const SizedBox(height: 20),
                Text('Donation History',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildDonationHistory(userData['donationHistory']),

                // Temp Button REMOVED
                // const SizedBox(height: 30),
                // ElevatedButton( onPressed: () => _addTestPoints(userData['points'] ?? 0), child: const Text('Add 10 Test Points')),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildInfoTile(
      {required IconData icon, required String title, required String value}) {
    return ListTile(
      leading: Icon(icon, color: Colors.redAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        value.isNotEmpty ? value : 'Not Set',
        style: TextStyle(
            color: value.isNotEmpty ? Colors.grey[700] : Colors.grey[500],
            fontSize: 16),
      ),
      dense: true,
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, Map<String, dynamic> userData) {
    String displayName = userData['name'] ?? '';
    String displayEmail = userData['email'] ?? 'No Email';
    String initialLetter = '?';
    if (displayName.isNotEmpty) {
      initialLetter = displayName[0].toUpperCase();
    } else if (displayEmail.isNotEmpty) {
      initialLetter = displayEmail[0].toUpperCase();
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.red[100],
          child: Text(
            initialLetter,
            style: TextStyle(fontSize: 30, color: Colors.red[800]),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isNotEmpty ? displayName : 'Name Not Set',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                displayEmail,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityTile(bool isAvailable, String userId) {
    return SwitchListTile(
      title: const Text('Available to Donate',
          style: TextStyle(fontWeight: FontWeight.w500)),
      value: isAvailable,
      onChanged: (bool newValue) async {
        print("Setting availability to $newValue for user $userId");
        try {
          await _profileService
              .updateUserProfile(userId, {'isAvailableToDonate': newValue});
          print("Availability updated.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text("Availability updated to ${newValue ? 'Yes' : 'No'}"),
                duration: Duration(seconds: 2)));
          }
        } catch (e) {
          print("Error updating availability: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Error: $e"), backgroundColor: Colors.red));
          }
        }
      },
      secondary: Icon(
        isAvailable ? Icons.check_circle : Icons.cancel_rounded,
        color: isAvailable ? Colors.green[600] : Colors.grey[500],
      ),
      activeColor: Colors.green[600],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
    );
  }

  Widget _buildDonationHistory(dynamic historyData) {
    if (historyData == null || historyData is! List || historyData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Text('No donation history recorded yet.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    final List<dynamic> historyList = List<dynamic>.from(historyData);
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: historyList.length,
      itemBuilder: (context, index) {
        final donation = historyList[index];
        String formattedDate = 'Unknown Date';
        String location = 'Unknown Location';
        String units = '';
        if (donation is Map<String, dynamic>) {
          final date = donation['date'];
          location = donation['location'] ?? 'Unknown Location';
          units = donation['units']?.toString() ?? '';
          if (date is Timestamp) {
            try {
              formattedDate =
                  DateFormat.yMMMd().add_jm().format(date.toDate().toLocal());
            } catch (e) {
              formattedDate = date.toDate().toLocal().toString().split('.')[0];
            }
          } else if (date is String) {
            formattedDate = date;
          }
        }
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: const Icon(Icons.history_rounded,
                size: 25, color: Colors.redAccent),
            title: Text(formattedDate,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(location),
            trailing: units.isNotEmpty
                ? Text('$units Unit(s)',
                    style: TextStyle(color: Colors.grey[600]))
                : null,
            dense: true,
          ),
        );
      },
    );
  }

  Widget _buildBadgesSection(dynamic userBadgesData) {
    if (userBadgesData == null ||
        userBadgesData is! List ||
        userBadgesData.isEmpty) {
      return const Center(
        child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text("No badges earned yet.",
                style: TextStyle(color: Colors.grey))),
      );
    }
    final List<String> earnedBadgeIds =
        List<String>.from(userBadgesData.map((item) => item.toString()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.start,
        children: earnedBadgeIds.map((badgeId) {
          final badgeInfo = _getBadgeInfo(badgeId);
          return Tooltip(
            message: badgeInfo['name'],
            child: Chip(
              avatar:
                  Icon(badgeInfo['icon'], size: 18, color: Colors.redAccent),
              label: Text(badgeInfo['name'], style: TextStyle(fontSize: 12)),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              backgroundColor: Colors.red[50],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }
  // --- End Helper Widgets ---
} // End _ProfilePageState
