// lib/features/donation_centers/data/services/donation_center_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// Ensure the model import path is correct for your structure
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';

class DonationCenterService {
  final CollectionReference<Map<String, dynamic>> _centersCollection =
      FirebaseFirestore.instance
          .collection('donationCenters')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (map, _) => map,
          );

  // Gets a stream of VERIFIED donation centers
  // Gets a stream of VERIFIED donation centers with enhanced logging
  Stream<List<DonationCenter>> getVerifiedCentersStream() {
    Query<Map<String, dynamic>> query =
        _centersCollection.where('isVerified', isEqualTo: true);
    // Removed .orderBy('name') for simplicity during debugging

    return query.snapshots().map((snapshot) {
      // Log how many documents Firestore returned for this query snapshot
      print(
          ">>> Center Stream Snapshot Received: ${snapshot.docs.length} documents matched query.");

      List<DonationCenter> centers =
          []; // List to hold successfully mapped centers
      for (var doc in snapshot.docs) {
        // Try to map each document individually and catch errors per document
        try {
          print("  --> Attempting to map doc ID: ${doc.id}");
          // Call the factory constructor which might throw an error
          centers.add(DonationCenter.fromFirestore(doc));
          print("  --> Successfully mapped doc ID: ${doc.id}");
        } catch (e) {
          // Log which specific document failed and why
          print(
              "!!! FAILED to map doc ID: ${doc.id}. Error during conversion: $e");
          // Continue to the next document without adding the failed one
        }
      }
      // Log how many documents were successfully converted
      print("<<< Center Stream Mapped List Count: ${centers.length}");
      return centers; // Return the list of successfully mapped items
    });
    // Removed outer try-catch as errors are handled per-document now
    // Removed .handleError as stream errors better handled in UI
  }

  // Optional: Method to get a single item
  Future<DonationCenter?> getCenter(String docId) async {
    try {
      final docSnapshot = await _centersCollection.doc(docId).get();
      if (docSnapshot.exists) {
        return DonationCenter.fromFirestore(docSnapshot);
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching single center $docId: $e");
      return null;
    }
  }
}
