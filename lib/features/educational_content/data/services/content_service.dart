// lib/features/educational_content/data/services/content_service.dart
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';

class ContentService {
  Stream<List<ContentItem>> getContentStream({String? categoryFilter}) {
    try {
      return supabase
          .from('educational_content')
          .stream(primaryKey: ['id'])
          .order('order', ascending: true)
          .map((rows) {
            var items = rows.map((r) => ContentItem.fromMap(r));
            if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'All') {
              items = items.where((i) => i.category == categoryFilter);
            }
            return items.toList();
          });
    } catch (e) {
      debugPrint("Error streaming educational content: $e");
      return Stream.value([]);
    }
  }

  Future<ContentItem?> getContentItem(String docId) async {
    try {
      final res = await supabase
          .from('educational_content')
          .select()
          .eq('id', docId)
          .maybeSingle();

      if (res != null) {
        return ContentItem.fromMap(res);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching content item $docId: $e");
      return null;
    }
  }
}
