// lib/features/educational_content/presentation/pages/content_list_page.dart
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for StreamBuilder type
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';
import 'package:red_cell_net_final/features/educational_content/data/services/content_service.dart';
// Import the detail page (Make sure this path is correct)
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_detail_page.dart';

class EducationalContentListPage extends StatefulWidget {
  const EducationalContentListPage({super.key});

  @override
  State<EducationalContentListPage> createState() =>
      _EducationalContentListPageState();
}

class _EducationalContentListPageState
    extends State<EducationalContentListPage> {
  final ContentService _contentService = ContentService();

  // Helper to get localized title
  String getLocalizedTitle(ContentItem item) {
    final locale = Localizations.localeOf(context);
    // Basic check, refine later with proper localization state management
    return locale.languageCode == 'bn' ? item.titleBn : item.titleEn;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn & Aware'),
      ),
      body: StreamBuilder<List<ContentItem>>(
        stream: _contentService.getContentStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error loading content: ${snapshot.error}");
            return Center(
                child: Text('Error loading content: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No educational content available yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final contentItems = snapshot.data!;

          return ListView.separated(
            itemCount: contentItems.length,
            padding: const EdgeInsets.all(8.0),
            separatorBuilder: (context, index) =>
                Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final item = contentItems[index];
              final displayTitle = getLocalizedTitle(item);

              return ListTile(
                title: Text(
                  displayTitle.isNotEmpty ? displayTitle : "(No Title)",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  item.category,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right),
                // --- Ensure onTap looks exactly like this ---
                onTap: () {
                  // Navigate to ContentDetailPage, passing the document ID
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ContentDetailPage(contentId: item.id), // Pass ID
                    ),
                  );
                },
                // --- End Correct onTap ---
              );
            },
          );
        },
      ),
    );
  }
}
