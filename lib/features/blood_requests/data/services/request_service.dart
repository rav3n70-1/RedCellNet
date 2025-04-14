// lib/features/blood_requests/data/services/request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class RequestService {
  final CollectionReference<Map<String, dynamic>> _requestsCollection =
      FirebaseFirestore.instance
          .collection('bloodRequests')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (map, _) => map,
          );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Create Request (Fully Expanded) ---
  Future<void> createBloodRequest(Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("User must be logged in to create a request.");
    }
    // Prepare the full data including server timestamp and user ID
    final Map<String, dynamic> completeRequestData = {
      ...requestData, // Spread the data passed from the page
      'requesterUserId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(), // Use server time
      'status': 'Open', // Initial status
    };
    try {
      // Add the document to the typed collection reference
      await _requestsCollection.add(completeRequestData);
      print('Blood request created successfully in service.'); // Specific log
    } catch (e) {
      print('Error creating blood request in service: $e');
      // Rethrow a potentially more user-friendly error or the original
      throw Exception('Failed to create blood request in Firestore.');
    }
  }
  // --- End Create Request ---

  // --- Get Request Details (Fully Expanded) ---
  Future<DocumentSnapshot<Map<String, dynamic>>> getRequestDetails(
      String requestId) async {
    if (requestId.isEmpty) {
      throw ArgumentError("Request ID cannot be empty.");
    }
    try {
      final docSnapshot = await _requestsCollection.doc(requestId).get();
      if (!docSnapshot.exists) {
        throw Exception('Request document does not exist for ID: $requestId');
      }
      return docSnapshot;
    } catch (e) {
      print('Error getting request details for $requestId: $e');
      rethrow;
    }
  }
  // --- End Get Request Details ---

  // --- Get Request Stream (Fully Expanded) ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getBloodRequestsStream(
      {String? bloodTypeFilter,
      String? ownerUserId,
      String? urgencyLevelFilter}) {
    try {
      Query<Map<String, dynamic>> query =
          _requestsCollection.where('status', isEqualTo: 'Open');
      if (ownerUserId != null && ownerUserId.isNotEmpty) {
        query = query.where('requesterUserId', isEqualTo: ownerUserId);
      }
      if (bloodTypeFilter != null && bloodTypeFilter.isNotEmpty) {
        query = query.where('requiredBloodType', isEqualTo: bloodTypeFilter);
      }
      if (urgencyLevelFilter != null && urgencyLevelFilter.isNotEmpty) {
        query = query.where('urgencyLevel', isEqualTo: urgencyLevelFilter);
      }
      // NOTE: Combined filters/order will require Firestore index(es)
      query = query.orderBy('createdAt', descending: true);
      return query.snapshots();
    } catch (e) {
      print("Error building bloodRequests stream query: $e");
      return Stream.empty();
    }
  }
  // --- End Get Request Stream ---

  // --- Delete Request (Fully Expanded) ---
  Future<void> deleteBloodRequest(String requestId) async {
    if (requestId.isEmpty) {
      throw ArgumentError("Request ID cannot be empty.");
    }
    print("Attempting to delete request $requestId from service...");
    try {
      // Call delete on the document reference
      await _requestsCollection.doc(requestId).delete();
      print("Request $requestId delete command sent successfully via service.");
    } catch (e) {
      // Log details and rethrow
      print("!!! SERVICE ERROR deleting request $requestId: $e");
      print("!!! Service Error Type: ${e.runtimeType}");
      throw Exception("Could not delete blood request. Service error.");
    }
  }
  // --- End Delete Request ---

  // --- Get Urgent Requests Stream (Fully Expanded) ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getUrgentRequestsStream(
      {int limit = 3}) {
    try {
      // NOTE: Requires index: status (Asc), urgencyLevel (Asc), createdAt (Desc)
      Query<Map<String, dynamic>> query = _requestsCollection
          .where('status', isEqualTo: 'Open')
          .where('urgencyLevel', isEqualTo: 'Critical')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      return query.snapshots();
    } catch (e) {
      print("Error building urgent request stream query: $e");
      return Stream.empty();
    }
  }
  // --- End Get Urgent Requests Stream ---

  // --- Get Offers Stream (Fully Expanded) ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getOffersStream(
      String requestId) {
    try {
      // NOTE: Rules must allow read. Ordering might need index later.
      return _requestsCollection
          .doc(requestId)
          .collection('offers')
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } catch (e) {
      print("Error building offers stream query: $e");
      return Stream.empty();
    }
  }
  // --- End Get Offers Stream ---

  // --- Accept Offer Method (Fully Expanded) ---
  Future<void> acceptOffer(
      String requestId, String offerId, String donorId) async {
    print("Service: Accepting offer $offerId for request $requestId");
    final DocumentReference requestRef = _requestsCollection.doc(requestId);
    final DocumentReference offerRef =
        requestRef.collection('offers').doc(offerId);
    final Query<Map<String, dynamic>> otherPendingOffersQuery =
        requestRef.collection('offers').where('status', isEqualTo: 'pending');
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final QuerySnapshot<Map<String, dynamic>> otherOffersSnapshot =
            await otherPendingOffersQuery.get(); // Execute query
        transaction
            .update(offerRef, {'status': 'accepted'}); // Update accepted offer
        transaction.update(requestRef, {
          'status': 'Fulfilled',
          'acceptedDonorId': donorId
        }); // Update main request
        // Reject other pending offers
        for (var doc in otherOffersSnapshot.docs) {
          if (doc.id != offerId) {
            transaction.update(doc.reference, {'status': 'rejected_auto'});
          }
        }
      });
      print(
          "Transaction Success: Offer $offerId accepted, request $requestId updated.");
    } catch (e) {
      print("!!! SERVICE ERROR accepting offer: $e");
      throw Exception("Failed to accept offer: ${e.toString()}");
    }
  }
  // --- End Accept Offer Method ---

  // --- Reject Offer Method (Fully Expanded) ---
  Future<void> rejectOffer(String requestId, String offerId) async {
    print("Service: Rejecting offer $offerId for request $requestId");
    final DocumentReference offerRef =
        _requestsCollection.doc(requestId).collection('offers').doc(offerId);
    try {
      await offerRef.update({'status': 'rejected'});
      print("Offer $offerId rejected successfully.");
    } catch (e) {
      print("!!! SERVICE ERROR rejecting offer: $e");
      throw Exception("Failed to reject offer: $e");
    }
  }
  // --- End Reject Offer Method ---
} // End Class
