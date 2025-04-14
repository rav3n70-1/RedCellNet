// lib/features/educational_content/data/services/content_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';

class ContentService {
  final CollectionReference<Map<String, dynamic>> _contentCollection =
      FirebaseFirestore.instance
          .collection('educationalContent')
          .withConverter<Map<String, dynamic>>(
            // Use a converter for type safety
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (map, _) => map,
          );

  // Gets a stream of content items, optionally filtered by category
  Stream<List<ContentItem>> getContentStream({String? categoryFilter}) {
    // Start with base query, maybe order by 'order' field or 'title_en'
    Query<Map<String, dynamic>> query =
        _contentCollection.orderBy('order'); // Example ordering

    // Apply category filter if provided
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    // Map the stream of snapshots to a stream of List<ContentItem>
    return query.snapshots().map((snapshot) {
      try {
        // Convert each document snapshot into a ContentItem object
        return snapshot.docs
            .map((doc) => ContentItem.fromFirestore(doc))
            .toList();
      } catch (e) {
        print("Error mapping content stream: $e");
        // Return an empty list or handle the error appropriately
        return [];
      }
    });
  }

  // Optional: Method to get a single item (e.g., for detail page if needed)
  Future<ContentItem?> getContentItem(String docId) async {
    try {
      final docSnapshot = await _contentCollection.doc(docId).get();
      if (docSnapshot.exists) {
        return ContentItem.fromFirestore(docSnapshot);
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching single content item $docId: $e");
      return null;
    }
  }
}
