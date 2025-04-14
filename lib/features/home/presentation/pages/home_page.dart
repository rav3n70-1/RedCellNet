// lib/features/home/presentation/pages/home_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/requests_page.dart';
import 'package:red_cell_net_final/features/nearby_map/presentation/pages/map_page.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/profile_page.dart'; // Correct path to ProfilePage
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_list_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:red_cell_net_final/main.dart';
import 'dart:convert';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart'; // Correct path

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final UserProfileService _userProfileService = UserProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Initialize list here where _onItemTapped exists
    _widgetOptions = <Widget>[
      HomeContent(onNavigate: _onItemTapped), // Pass callback
      const RequestsPage(),
      const MapPage(),
      const ProfilePage(), // Use ProfilePage from correct import
      const EducationalContentListPage(),
    ];
    _setupFcm();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _setupFcm() async {
    /* ... FCM Setup logic ... */ FirebaseMessaging messaging =
        FirebaseMessaging.instance;
    try {
      NotificationSettings settings = await messaging.requestPermission(
          alert: true, badge: true, sound: true);
      print('User granted permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? fcmToken = await messaging.getToken();
        print("FirebaseMessaging token: $fcmToken");
        final currentUser = _auth.currentUser;
        if (currentUser != null && fcmToken != null) {
          await _userProfileService.saveUserFcmToken(currentUser.uid, fcmToken);
          messaging.onTokenRefresh.listen((newToken) {
            print("FCM Token Refreshed: $newToken");
            if (mounted)
              _userProfileService.saveUserFcmToken(currentUser.uid, newToken);
          });
        } else {
          print("Cannot save token.");
        }
      } else {
        print('User declined permissions');
      }
    } catch (e) {
      print("FCM Setup Error: $e");
    }
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground FCM Message Received!');
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        print('Notification: ${notification.title} - ${notification.body}');
        String? screenTarget = message.data['screen'];
        String? resourceId = message.data['requestId'];
        Map<String, dynamic> payloadData = {};
        if (screenTarget != null) payloadData['screen'] = screenTarget;
        if (resourceId != null) payloadData['id'] = resourceId;
        String payloadJson = jsonEncode(payloadData);
        print("Using payload: $payloadJson");
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
                presentAlert: true, presentBadge: true, presentSound: true),
          ),
          payload: payloadJson,
        );
      }
    });
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print("Terminated App Opened!");
        _handleNotificationNavigation(message.data);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Background App Opened!");
      _handleNotificationNavigation(message.data);
    });
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    /* ... Navigation Helper ... */ print("Handling nav for: $data");
    final String? screen = data['screen'];
    final String? id = data['id'];
    try {
      if (screen == '/request_details' && id != null) {
        print("Navigating to Request Details: $id");
        Future.delayed(Duration(milliseconds: 100), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => RequestDetailsPage(requestId: id),
            ),
          );
          print("Nav push attempted.");
        });
      } else {
        print("No nav info.");
      }
    } catch (e) {
      print("Nav Error: $e");
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Requests'),
          BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined),
              activeIcon: Icon(Icons.library_books),
              label: 'Learn'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- HomeContent Widget ---
class HomeContent extends StatelessWidget {
  final Function(int) onNavigate;
  HomeContent({super.key, required this.onNavigate}); // Non-const constructor

  final UserProfileService _profileService = UserProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Logout method REMOVED from here

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // AppBar removed, as it's handled by parent Scaffold in ProfilePage now
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Welcome Message
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: user != null
                      ? _profileService.getUserProfileStream(user.uid)
                      : Stream.empty(),
                  builder: (context, snapshot) {
                    String name = '';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      name = snapshot.data!.data()?['name'] ?? '';
                    }
                    String welcomeText = (name.isNotEmpty)
                        ? 'Welcome back, $name!'
                        : (user?.email?.isNotEmpty ?? false)
                            ? 'Welcome, ${user!.email}!'
                            : 'Welcome!';
                    return Text(welcomeText,
                        style: textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center);
                  }),
            ),
            // Quick Actions / Summary Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                      elevation: 2,
                      color: Colors.amber[50],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber[800], size: 32),
                          const SizedBox(height: 8),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: user != null
                                  ? _profileService
                                      .getUserProfileStream(user.uid)
                                  : Stream.empty(),
                              builder: (context, snapshot) {
                                int points = 0;
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  points =
                                      snapshot.data!.data()?['points'] ?? 0;
                                }
                                return Text(points.toString(),
                                    style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold));
                              }),
                          Text("Points",
                              style: textTheme.labelMedium
                                  ?.copyWith(color: Colors.grey[700])),
                        ]),
                      )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    color: Colors.red[50],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CreateRequestPage())),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(children: [
                            Icon(Icons.bloodtype_outlined,
                                color: colorScheme.error, size: 32),
                            const SizedBox(height: 8),
                            Text("Request",
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text("Blood",
                                style: textTheme.labelMedium
                                    ?.copyWith(color: Colors.grey[700])),
                          ]),
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Urgent Requests Section
            Text("Urgent Needs", style: textTheme.titleLarge),
            const SizedBox(height: 8),
            _buildUrgentRequestsSection(context), const SizedBox(height: 24),
            // Other Links
            Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Icon(
                    Icons.map_outlined,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  title: const Text('Find Centers & Requests'),
                  subtitle: const Text('View nearby activity on map'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => onNavigate(2),
                )),
            const SizedBox(height: 12),
            Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Icon(
                    Icons.library_books_outlined,
                    color: Colors.blue[700],
                    size: 28,
                  ),
                  title: const Text('Learn About Donation'),
                  subtitle: const Text('Articles, tips, and FAQs'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => onNavigate(4),
                )),
          ],
        ),
      ),
    );
  }

  // --- Urgent Requests Helper ---
  Widget _buildUrgentRequestsSection(BuildContext context) {
    final RequestService requestService =
        RequestService(); // Instantiate service here
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: requestService.getUrgentRequestsStream(limit: 3),
                builder: (context, snapshot) {
                  // ... (Loading/Error/Empty checks) ...
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            )));
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Error: ${snapshot.error}",
                            style: TextStyle(color: Colors.red[700])));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text("No critical requests currently.",
                          style: TextStyle(color: Colors.grey)),
                    ));
                  }
                  final requests = snapshot.data!.docs;
                  // Return Column containing list AND button
                  return Column(
                    children: [
                      // Map requests to ListTiles
                      ...requests.map((doc) {
                        final data = doc.data();
                        final bloodType = data['requiredBloodType'] ?? '?';
                        final hospital = data['hospitalName'] ?? 'Unknown';
                        final units = data['unitsNeeded'] ?? '?';
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.red[100],
                              child: Text(bloodType,
                                  style: TextStyle(
                                      color: Colors.red[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          title: Text(hospital,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text("$units Unit(s) Critical",
                              style: TextStyle(fontSize: 12)),
                          trailing: Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey[400]),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      RequestDetailsPage(requestId: doc.id))),
                        );
                      }).toList(),
                      // "View All" Button
                      if (snapshot.hasData &&
                          snapshot
                              .data!.docs.isNotEmpty) // Check snapshot directly
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => onNavigate(1),
                            child: Text("View All Requests",
                                style: TextStyle(color: colorScheme.primary)),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  );
                }),
          ],
        ),
      ),
    );
  }
  // --- End Urgent Requests Helper ---
}
// --- End HomeContent Widget ---
