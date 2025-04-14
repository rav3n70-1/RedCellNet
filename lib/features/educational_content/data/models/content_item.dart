// lib/features/educational_content/data/models/content_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentItem {
  final String id;
  final String titleEn;
  final String titleBn;
  final String contentEn;
  final String contentBn;
  final String category;
  final String? imageUrl; // Nullable
  final int? order; // Nullable

  ContentItem({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.contentEn,
    required this.contentBn,
    required this.category,
    this.imageUrl,
    this.order,
  });

  // Factory constructor to create a ContentItem from a Firestore document
  factory ContentItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      // Handle cases where data might be unexpectedly null, though unlikely for existing docs
      throw Exception("Document data was null for doc ID: ${doc.id}");
    }

    return ContentItem(
      id: doc.id,
      titleEn:
          data['title_en'] as String? ?? '', // Provide default value if null
      titleBn: data['title_bn'] as String? ?? '',
      contentEn: data['content_en'] as String? ?? '',
      contentBn: data['content_bn'] as String? ?? '',
      category: data['category'] as String? ?? 'Uncategorized',
      imageUrl: data['imageUrl'] as String?, // Already nullable
      order: data['order'] as int?, // Already nullable
    );
  }
}
