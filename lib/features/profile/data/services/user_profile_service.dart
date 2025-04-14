// lib/features/profile/data/services/user_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  Future<void> createUserProfile(User user, {String? name}) async {
    final DocumentReference userDoc = _usersCollection.doc(user.uid);
    final Map<String, dynamic> initialData = {
      'uid': user.uid, 'email': user.email, 'name': name ?? '',
      'bloodType': null, 'locationCity': null, 'locationCoords': null,
      'phoneNumber': null, 'points': 0, 'badges': [],
      'isAvailableToDonate': false, 'createdAt': FieldValue.serverTimestamp(),
      'donationHistory': [], 'fcmToken': null,
      'viewedContentIds': [], // <-- Initialize viewed content list
    };
    try {
      await userDoc.set(initialData);
      print('User profile created successfully for UID: ${user.uid}');
    } catch (e) {
      print('Error creating user profile: $e');
      throw Exception('Failed to create user profile.');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfileStream(
      String uid) {
    return _usersCollection
        .doc(uid)
        .snapshots()
        .cast<DocumentSnapshot<Map<String, dynamic>>>();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    final Map<String, dynamic> dataWithTimestamp = {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _usersCollection.doc(uid).update(dataWithTimestamp);
      print('User profile updated successfully for UID: $uid');
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update user profile.');
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(
      String uid) async {
    try {
      final docSnapshot = await _usersCollection.doc(uid).get().then(
          (snapshot) => snapshot as DocumentSnapshot<Map<String, dynamic>>);
      if (!docSnapshot.exists) {
        throw Exception('User profile document does not exist.');
      }
      return docSnapshot;
    } catch (e) {
      print('Error getting user profile: $e');
      throw Exception('Failed to get user profile.');
    }
  }

  Future<void> saveUserFcmToken(String uid, String? token) async {
    if (token == null || token.isEmpty) {
      print("FCM token null/empty, not saving.");
      return;
    }
    try {
      await _usersCollection.doc(uid).update({'fcmToken': token});
      print('User FCM token saved/updated for UID: $uid');
    } catch (e) {
      print('Update failed for FCM token ($e), attempting set with merge...');
      try {
        await _usersCollection
            .doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        print('User FCM token set via merge for UID: $uid');
      } catch (e2) {
        print('Error saving FCM token via set/merge for user $uid: $e2');
      }
    }
  }

  // --- NEW METHOD for Content Points ---
  /// Attempts to award points for viewing content.
  /// Returns true if points were awarded, false otherwise (already viewed or error).
  Future<bool> awardPointsForViewingContent(
      String userId, String contentId) async {
    if (userId.isEmpty || contentId.isEmpty) return false;

    final DocumentReference userDocRef = _usersCollection.doc(userId);
    const int pointsPerView = 1; // Points awarded for reading

    try {
      // Use a transaction to read and write atomically
      return await FirebaseFirestore.instance
          .runTransaction<bool>((transaction) async {
        final DocumentSnapshot<Object?> userSnapshot =
            await transaction.get(userDocRef);

        if (!userSnapshot.exists) {
          print("User document $userId not found for awarding points.");
          return false; // User doesn't exist
        }

        // Get current data safely
        final Map<String, dynamic> userData =
            userSnapshot.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> viewedIdsDyn = userData['viewedContentIds'] ?? [];
        // Ensure we have a List<String> for contains check
        final List<String> viewedIds =
            List<String>.from(viewedIdsDyn.map((e) => e.toString()));
        final int currentPoints = userData['points'] ?? 0;

        // Check if content already viewed
        if (viewedIds.contains(contentId)) {
          print(
              "Content $contentId already viewed by user $userId. No points awarded.");
          return false; // Already viewed, no points awarded
        }

        // Content not viewed before: Award points and add ID to list
        final int newPoints = currentPoints + pointsPerView;
        transaction.update(userDocRef, {
          'points': newPoints,
          'viewedContentIds':
              FieldValue.arrayUnion([contentId]) // Atomically add ID
        });
        print(
            "Awarded $pointsPerView point(s) to user $userId for viewing content $contentId. New total: $newPoints");
        return true; // Points awarded
      });
    } catch (e) {
      print("Error during awardPointsForViewingContent transaction: $e");
      return false; // Transaction failed
    }
  }
  // --- End NEW METHOD ---
}
