// lib/features/educational_content/presentation/pages/content_detail_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';
import 'package:red_cell_net_final/features/educational_content/data/services/content_service.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';

class ContentDetailPage extends StatefulWidget {
  final String contentId;

  const ContentDetailPage({super.key, required this.contentId});

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  final ContentService _contentService = ContentService();
  final UserProfileService _profileService = UserProfileService();

  late Future<ContentItem?> _contentFuture;
  bool _pointsAwardedAttempted = false;

  @override
  void initState() {
    super.initState();
    _contentFuture = _contentService.getContentItem(widget.contentId);
  }

  String getLocalizedText(String english, String bangla) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'bn' ? bangla : english;
  }

  Future<void> _attemptAwardPoints(String contentId) async {
    if (_pointsAwardedAttempted) return;
    setState(() => _pointsAwardedAttempted = true);

    final String? currentUserId = SupabaseAuthService().currentUserId;
    if (currentUserId == null || contentId.isEmpty) return;

    final bool awarded = await _profileService.awardPointsForViewingContent(
        currentUserId, contentId);

    if (awarded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 +1 Life Point earned for reading this article!"),
          duration: Duration(seconds: 3),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<ContentItem?>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              appBar: AppBar(),
              body: EmptyStateView(
                icon: Icons.article_outlined,
                title: 'Article Not Found',
                message: 'This educational article could not be loaded.',
                buttonText: 'Back to Guides',
                onAction: () => Navigator.pop(context),
              ),
            );
          }

          final contentItem = snapshot.data!;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _attemptAwardPoints(contentItem.id);
          });

          final title =
              getLocalizedText(contentItem.titleEn, contentItem.titleBn);
          final content =
              getLocalizedText(contentItem.contentEn, contentItem.contentBn);
          final bool hasImage = contentItem.imageUrl != null &&
              contentItem.imageUrl!.trim().isNotEmpty;

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: hasImage ? 240.0 : 80.0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasImage ? Colors.black.withValues(alpha: 0.4) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: hasImage ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: hasImage
                    ? FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              contentItem.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: AppColors.primaryLight,
                                child: const Icon(Icons.menu_book_rounded,
                                    size: 64, color: AppColors.primary),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tag & Points Pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              contentItem.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star_rounded,
                                    color: Color(0xFFD97706), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '+1 Life Point',
                                  style: TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Article Title
                      Text(
                        title.isNotEmpty ? title : "Educational Guide",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 20),

                      // Article Content Text
                      Text(
                        content.isNotEmpty
                            ? content
                            : "Detailed guide content will be updated soon.",
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          color: Color(0xFF334155),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
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
