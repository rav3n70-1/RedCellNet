// lib/features/educational_content/presentation/pages/content_detail_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';
import 'package:red_cell_net_final/features/educational_content/data/services/content_service.dart';
// Imports for awarding points
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import dart:convert if using JSON parsing for notification payload later
// import 'dart:convert';

class ContentDetailPage extends StatefulWidget {
  final String contentId;

  const ContentDetailPage({super.key, required this.contentId});

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  final ContentService _contentService = ContentService();
  // Add instances for awarding points
  final UserProfileService _profileService = UserProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Future<ContentItem?> _contentFuture;
  bool _pointsAwardedAttempted =
      false; // Prevent multiple attempts per page load

  @override
  void initState() {
    super.initState();
    _contentFuture = _contentService.getContentItem(widget.contentId);
    // Don't call award points here yet, wait for FutureBuilder successful load
  }

  // Helper to get localized text
  String getLocalizedText(String english, String bangla) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'bn' ? bangla : english;
  }

  // Helper function to attempt awarding points
  Future<void> _attemptAwardPoints(String contentId) async {
    // Only attempt once per page view
    if (_pointsAwardedAttempted) return;
    setState(() {
      _pointsAwardedAttempted = true;
    }); // Mark as attempted

    final currentUser = _auth.currentUser;
    if (currentUser == null || contentId.isEmpty) return;

    print("Attempting to award points for viewing content: $contentId");
    final bool awarded = await _profileService.awardPointsForViewingContent(
        currentUser.uid, contentId);

    if (awarded && mounted) {
      print("Points awarded!");
      // Show confirmation SnackBar
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("+1 Point for reading!"),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ));
    } else if (mounted) {
      // Don't show snackbar if already viewed, just log it
      print("Points not awarded (likely already viewed or error occurred).");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar is now part of CustomScrollView
      body: FutureBuilder<ContentItem?>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
                child: Text(
                    'Error loading content: ${snapshot.error ?? 'Content not found.'}'));
          }

          final contentItem = snapshot.data!;

          // --- Attempt to award points AFTER content is loaded ---
          // Use addPostFrameCallback to avoid calling during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _attemptAwardPoints(contentItem.id);
          });
          // --- End attempt ---

          final title =
              getLocalizedText(contentItem.titleEn, contentItem.titleBn);
          final content =
              getLocalizedText(contentItem.contentEn, contentItem.contentBn);

          // Use CustomScrollView for potentially collapsible AppBar with image
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: Text(title.isNotEmpty ? title : "Details"),
                pinned: true, // Keeps AppBar visible
                expandedHeight: contentItem.imageUrl != null &&
                        contentItem.imageUrl!.isNotEmpty
                    ? 250.0
                    : kToolbarHeight, // Expand more if image exists
                flexibleSpace: (contentItem.imageUrl != null &&
                        contentItem.imageUrl!.isNotEmpty)
                    ? FlexibleSpaceBar(
                        background: Image.network(
                          contentItem.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                  color: Colors.grey[300],
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey[600])),
                        ),
                      )
                    : null, // No flexible space if no image
              ),
              // Use SliverPadding for content padding
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  // Use SliverToBoxAdapter for single child
                  child: Text(
                    content.isNotEmpty ? content : "No content available.",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        height:
                            1.6), // Slightly larger text, better line height
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
