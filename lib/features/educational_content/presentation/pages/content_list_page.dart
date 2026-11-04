// lib/features/educational_content/presentation/pages/content_list_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';
import 'package:red_cell_net_final/features/educational_content/data/services/content_service.dart';
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
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Eligibility',
    'Preparation',
    'Health Benefits',
    'Myths & Facts',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String getLocalizedTitle(ContentItem item) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'bn' ? item.titleBn : item.titleEn;
  }

  void _showEligibilityChecker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const _EligibilityQuizSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Learn & Awareness'),
      ),
      body: StreamBuilder<List<ContentItem>>(
        stream: _contentService.getContentStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading guides: ${snapshot.error}',
                style: const TextStyle(color: AppColors.critical),
              ),
            );
          }

          final rawItems = snapshot.data ?? [];

          // Filter by category and search query
          final contentItems = rawItems.where((item) {
            if (_selectedCategory != 'All' &&
                !item.category.toLowerCase().contains(_selectedCategory.toLowerCase())) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final title = getLocalizedTitle(item).toLowerCase();
              final cat = item.category.toLowerCase();
              if (!title.contains(_searchQuery) && !cat.contains(_searchQuery)) {
                return false;
              }
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // --- 60-Second Eligibility Quiz Banner Card ---
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.glowPrimary,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showEligibilityChecker,
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.checklist_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Can I Donate Blood Today?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Take the 60-second donor eligibility check',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Check Now',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Reward Highlight Pill ---
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Earn Life Points as You Read',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Each guide you read automatically awards you +1 Life Point towards badges!',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- Search Bar ---
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: 'Search health guides & articles...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Categories Horizontal Filter ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              SectionHeader(
                title: 'Articles & Guides',
                subtitle: _selectedCategory != 'All'
                    ? 'Category: $_selectedCategory (${contentItems.length})'
                    : 'Essential donor knowledge (${contentItems.length})',
                icon: Icons.auto_stories_rounded,
              ),
              const SizedBox(height: 8),

              if (contentItems.isEmpty)
                const EmptyStateView(
                  icon: Icons.menu_book_rounded,
                  title: 'No Guides Found',
                  message: 'No articles match your current category or search criteria.',
                )
              else
                ...contentItems.map((item) {
                  final displayTitle = getLocalizedTitle(item);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContentDetailPage(contentId: item.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.category.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          '• 3 min read',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      displayTitle.isNotEmpty ? displayTitle : "Blood Donation Guide",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                                    SizedBox(width: 3),
                                    Text(
                                      '+1 Pt',
                                      style: TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// --- Interactive 60-Second Eligibility Quiz Bottom Sheet ---
class _EligibilityQuizSheet extends StatefulWidget {
  const _EligibilityQuizSheet();

  @override
  State<_EligibilityQuizSheet> createState() => _EligibilityQuizSheetState();
}

class _EligibilityQuizSheetState extends State<_EligibilityQuizSheet> {
  bool _isAge18to65 = true;
  bool _isWeightAbove50 = true;
  bool _isFeelingWell = true;
  bool _noRecentSurgery = true;
  bool _lastDonationOver90Days = true;

  @override
  Widget build(BuildContext context) {
    final bool isEligible = _isAge18to65 &&
        _isWeightAbove50 &&
        _isFeelingWell &&
        _noRecentSurgery &&
        _lastDonationOver90Days;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Donor Eligibility Check',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Check these criteria to see if you can safely donate blood today:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          _buildQuestionTile(
            title: 'Are you between 18 and 65 years old?',
            value: _isAge18to65,
            onChanged: (v) => setState(() => _isAge18to65 = v),
          ),
          _buildQuestionTile(
            title: 'Do you weigh at least 50 kg (110 lbs)?',
            value: _isWeightAbove50,
            onChanged: (v) => setState(() => _isWeightAbove50 = v),
          ),
          _buildQuestionTile(
            title: 'Are you feeling healthy and symptom-free today?',
            value: _isFeelingWell,
            onChanged: (v) => setState(() => _isFeelingWell = v),
          ),
          _buildQuestionTile(
            title: 'No recent major surgery, tattoo or piercing in the last 6 months?',
            value: _noRecentSurgery,
            onChanged: (v) => setState(() => _noRecentSurgery = v),
          ),
          _buildQuestionTile(
            title: 'Has it been at least 90 days (3 months) since your last donation?',
            value: _lastDonationOver90Days,
            onChanged: (v) => setState(() => _lastDonationOver90Days = v),
          ),
          const SizedBox(height: 16),

          // Result Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEligible ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEligible ? AppColors.success : const Color(0xFFF59E0B),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEligible ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isEligible ? AppColors.success : const Color(0xFFD97706),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEligible ? 'You Are Eligible to Donate!' : 'You May Need to Wait',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isEligible ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEligible
                            ? 'You meet the fundamental medical criteria for whole blood donation. Thank you for being a lifesaver!'
                            : 'Based on standard safety guidelines, you may temporarily not be eligible to donate today.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isEligible ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuestionTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
