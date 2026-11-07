// lib/features/educational_content/presentation/pages/content_detail_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
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

  String _localizedText(String english, String bangla) {
    final isBn = Localizations.localeOf(context).languageCode == 'bn' ||
        AppSettingsService().isBengali;
    if (isBn && bangla.trim().isNotEmpty) {
      return bangla;
    }
    return english;
  }

  Future<void> _attemptAwardPoints(String contentId) async {
    if (_pointsAwardedAttempted) return;
    _pointsAwardedAttempted = true;

    final String? currentUserId = SupabaseAuthService().currentUserId;
    if (currentUserId == null || contentId.isEmpty) return;

    final res = await _profileService.awardPointsForViewingContentDetailed(
        currentUserId, contentId);

    if (res['awarded'] == true && mounted) {
      final int pts = int.tryParse('${res['points_added'] ?? 5}') ?? 5;
      final String? badge = res['badge_unlocked']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            badge != null && badge.isNotEmpty
                ? 'Badge Unlocked: "$badge" (+$pts recognition points)!'
                : '+$pts recognition points recorded for completing this guide.',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: FutureBuilder<ContentItem?>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppColors.scaffoldOf(context),
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              backgroundColor: AppColors.scaffoldOf(context),
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
              _localizedText(contentItem.titleEn, contentItem.titleBn);
          final content =
              _localizedText(contentItem.contentEn, contentItem.contentBn);
          final bool showingFallbackEnglish = (AppSettingsService().isBengali ||
                  Localizations.localeOf(context).languageCode == 'bn') &&
              contentItem.contentBn.trim().isEmpty &&
              contentItem.contentEn.trim().isNotEmpty;
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
                      color: hasImage
                          ? Colors.black.withValues(alpha: 0.4)
                          : (isDark
                              ? AppColors.surfaceMutedOf(context)
                              : Colors.transparent),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: hasImage
                          ? Colors.white
                          : AppColors.textPrimaryOf(context),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              contentItem.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${contentItem.readTimeMinutes} min read',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMutedOf(context),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF78350F)
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFD97706), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '+${contentItem.pointsValue} Pts',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFF92400E),
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

                      Text(
                        title.isNotEmpty ? title : "Educational Guide",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryOf(context),
                          letterSpacing: -0.4,
                          height: 1.3,
                        ),
                      ),
                      if (showingFallbackEnglish) ...[
                        const SizedBox(height: 8),
                        Text(
                          'বাংলা অনুবাদ শীঘ্রই যুক্ত হবে — ইংরেজি সংস্করণ দেখানো হচ্ছে।',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedOf(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Divider(color: AppColors.borderOf(context), height: 1),
                      const SizedBox(height: 20),

                      Text(
                        content.isNotEmpty
                            ? content
                            : "Detailed guide content will be updated soon.",
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Source Attribution & Clinical Disclaimer Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMutedOf(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderOf(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_outlined,
                                    size: 16, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Reference: ${contentItem.sourceAttribution}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              contentItem.medicalDisclaimer,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(context),
                                height: 1.4,
                              ),
                            ),
                          ],
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
