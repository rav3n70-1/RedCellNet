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
  final String sourceAttribution;
  final String medicalDisclaimer;

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
    this.pointsValue = 5,
    this.sourceAttribution =
        'WHO & National Safe Blood Transfusion Programme Guidelines',
    this.medicalDisclaimer =
        'Educational reference only. Always consult qualified medical staff at a licensed blood bank before donating.',
  });

  factory ContentItem.fromMap(Map<String, dynamic> data, {String? id}) {
    final docId = id ?? data['id']?.toString() ?? '';
    return ContentItem(
      id: docId,
      titleEn: (data['title_en'] ?? data['titleEn'])?.toString() ?? '',
      titleBn: (data['title_bn'] ?? data['titleBn'])?.toString() ?? '',
      contentEn: (data['content_en'] ?? data['contentEn'])?.toString() ?? '',
      contentBn: (data['content_bn'] ?? data['contentBn'])?.toString() ?? '',
      category: data['category']?.toString() ?? 'General',
      imageUrl: (data['image_url'] ?? data['imageUrl'])?.toString(),
      order: data['order'] is int
          ? data['order'] as int
          : int.tryParse('${data['order'] ?? ''}'),
      readTimeMinutes: int.tryParse(
              '${data['read_time_minutes'] ?? data['readTimeMinutes'] ?? 3}') ??
          3,
      pointsValue: int.tryParse(
              '${data['points_value'] ?? data['points'] ?? data['pointsValue'] ?? 5}') ??
          5,
      sourceAttribution: (data['source_attribution'] ??
                  data['sourceAttribution'])
              ?.toString() ??
          'WHO & National Safe Blood Transfusion Programme Guidelines',
      medicalDisclaimer: (data['medical_disclaimer'] ??
                  data['medicalDisclaimer'])
              ?.toString() ??
          'Educational reference only. Always consult qualified medical staff at a licensed blood bank before donating.',
    );
  }
}
