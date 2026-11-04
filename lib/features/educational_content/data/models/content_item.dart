// lib/features/educational_content/data/models/content_item.dart

class ContentItem {
  final String id;
  final String titleEn;
  final String titleBn;
  final String contentEn;
  final String contentBn;
  final String category;
  final String? imageUrl;
  final int? order;
  final int readTimeMinutes;
  final int pointsValue;

  ContentItem({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.contentEn,
    required this.contentBn,
    required this.category,
    this.imageUrl,
    this.order,
    this.readTimeMinutes = 3,
    this.pointsValue = 1,
  });

  factory ContentItem.fromMap(Map<String, dynamic> data, {String? id}) {
    final docId = id ?? data['id']?.toString() ?? '';
    return ContentItem(
      id: docId,
      titleEn: (data['title_en'] ?? data['titleEn']) as String? ?? '',
      titleBn: (data['title_bn'] ?? data['titleBn']) as String? ?? '',
      contentEn: (data['content_en'] ?? data['contentEn']) as String? ?? '',
      contentBn: (data['content_bn'] ?? data['contentBn']) as String? ?? '',
      category: data['category'] as String? ?? 'General',
      imageUrl: (data['image_url'] ?? data['imageUrl']) as String?,
      order: (data['order']) as int?,
      readTimeMinutes: (data['read_time_minutes'] ?? data['readTimeMinutes']) as int? ?? 3,
      pointsValue: (data['points_value'] ?? data['pointsValue']) as int? ?? 1,
    );
  }
}
