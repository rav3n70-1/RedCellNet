// lib/features/educational_content/presentation/pages/content_list_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';
import 'package:red_cell_net_final/features/educational_content/data/services/content_service.dart';
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_detail_page.dart';

/// Opens the standardized WHO preliminary 60-second donor self-triage bottom sheet.
void showDonorSelfTriageSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBg(context),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: AppColors.isDark(context)
          ? AppColors.borderSideOf(context)
          : BorderSide.none,
    ),
    builder: (_) => const DonorSelfTriageSheet(),
  );
}

class EducationalContentListPage extends StatefulWidget {
  const EducationalContentListPage({super.key});

  @override
  State<EducationalContentListPage> createState() =>
      _EducationalContentListPageState();
}

class _EducationalContentListPageState
    extends State<EducationalContentListPage> {
  final ContentService _contentService = ContentService();
  late final Stream<List<ContentItem>> _contentStream;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = const [
    'All',
    'Eligibility',
    'Preparation',
    'Health Benefits',
    'Myths & Facts',
  ];

  @override
  void initState() {
    super.initState();
    _contentStream = _contentService.getContentStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _localizedTitle(ContentItem item) {
    final isBn = Localizations.localeOf(context).languageCode == 'bn' ||
        AppSettingsService().isBengali;
    if (isBn && item.titleBn.trim().isNotEmpty) {
      return item.titleBn;
    }
    return item.titleEn;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final settings = AppSettingsService();

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(settings.tr('Learn', bn: 'স্বাস্থ্য ও রক্তদান নির্দেশিকা')),
      ),
      body: StreamBuilder<List<ContentItem>>(
        stream: _contentStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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

          final contentItems = rawItems.where((item) {
            if (_selectedCategory != 'All' &&
                !item.category
                    .toLowerCase()
                    .contains(_selectedCategory.toLowerCase())) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final titleEn = item.titleEn.toLowerCase();
              final titleBn = item.titleBn.toLowerCase();
              final cat = item.category.toLowerCase();
              if (!titleEn.contains(_searchQuery) &&
                  !titleBn.contains(_searchQuery) &&
                  !cat.contains(_searchQuery)) {
                return false;
              }
            }
            return true;
          }).toList();

          return ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // 60-Second Preliminary Self-Triage Banner
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
                    onTap: () => showDonorSelfTriageSheet(context),
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
                                Text(
                                  settings.tr(
                                    'Can I Donate Blood Today?',
                                    bn: 'আজ কি আমি রক্ত দিতে পারব?',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  settings.tr(
                                    'Take the WHO-aligned 60-second preliminary check',
                                    bn: '৬০ সেকেন্ডে প্রাথমিক স্বাস্থ্য যোগ্যতা যাচাই করুন',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              settings.tr('Check Now', bn: 'যাচাই করুন'),
                              style: const TextStyle(
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
              const SizedBox(height: 14),

              // Awareness note
              Container(
                padding: const EdgeInsets.all(13.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? AppColors.borderOf(context)
                          : AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.health_and_safety_outlined,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        settings.tr(
                          'Complete 3 verified health guides to unlock the "Health Aware" recognition badge.',
                          bn: '৩টি স্বাস্থ্য নির্দেশিকা সম্পূর্ণ পড়লে "Health Aware" ব্যাজ অর্জিত হবে।',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                style: TextStyle(color: AppColors.textPrimaryOf(context)),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: settings.tr(
                    'Search health guides & articles...',
                    bn: 'নির্দেশিকা ও নিবন্ধ খুঁজুন...',
                  ),
                  hintStyle: TextStyle(color: AppColors.textMutedOf(context)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              size: 18, color: AppColors.textMutedOf(context)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardBg(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Categories Horizontal Filter
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
                        backgroundColor: isDark
                            ? AppColors.surfaceMutedOf(context)
                            : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.borderOf(context),
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
                title:
                    settings.tr('Articles & Guides', bn: 'নিবন্ধ ও নির্দেশিকা'),
                subtitle: _selectedCategory != 'All'
                    ? 'Category: $_selectedCategory (${contentItems.length})'
                    : 'Clinical & preparation guides (${contentItems.length})',
                icon: Icons.auto_stories_rounded,
              ),
              const SizedBox(height: 8),

              if (contentItems.isEmpty)
                const EmptyStateView(
                  icon: Icons.menu_book_rounded,
                  title: 'No Guides Found',
                  message:
                      'No articles match your current category or search criteria.',
                )
              else
                ...contentItems.map((item) {
                  final displayTitle = _localizedTitle(item);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderOf(context)),
                      boxShadow: isDark ? null : AppColors.cardShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContentDetailPage(contentId: item.id),
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
                                  color: isDark
                                      ? AppColors.primary
                                          .withValues(alpha: 0.25)
                                      : AppColors.primaryContainer,
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMutedOf(
                                                context),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.category.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textSecondaryOf(
                                                  context),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${item.readTimeMinutes} min read',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppColors.textMutedOf(context),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      displayTitle.isNotEmpty
                                          ? displayTitle
                                          : "Blood Donation Guide",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimaryOf(context),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF78350F)
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFD97706), size: 14),
                                    const SizedBox(width: 3),
                                    Text(
                                      '+${item.pointsValue}',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFFCD34D)
                                            : const Color(0xFF92400E),
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

/// Interactive 60-Second WHO Preliminary Donor Eligibility Self-Triage Sheet.
/// Checkboxes start unchecked (`false`) so users actively verify every clinical item.
class DonorSelfTriageSheet extends StatefulWidget {
  const DonorSelfTriageSheet({super.key});

  @override
  State<DonorSelfTriageSheet> createState() => _DonorSelfTriageSheetState();
}

class _DonorSelfTriageSheetState extends State<DonorSelfTriageSheet> {
  bool _isAge18to60 = false;
  bool _isWeightAtLeast50 = false;
  bool _isFeelingWell = false;
  bool _noRecentSurgeryOrTattoo = false;
  bool _lastDonationOver90Days = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final int checkedCount = [
      _isAge18to60,
      _isWeightAtLeast50,
      _isFeelingWell,
      _noRecentSurgeryOrTattoo,
      _lastDonationOver90Days,
    ].where((v) => v).length;
    final bool allConfirmed = checkedCount == 5;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.health_and_safety_rounded,
                          color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Preliminary Donor Self-Check',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textPrimaryOf(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Confirm each statement below ($checkedCount/5 confirmed):',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 12),
            _buildQuestionTile(
              title: 'I am between 18 and 60 years of age.',
              value: _isAge18to60,
              onChanged: (v) => setState(() => _isAge18to60 = v),
            ),
            _buildQuestionTile(
              title: 'I weigh at least 50 kg (110 lbs).',
              value: _isWeightAtLeast50,
              onChanged: (v) => setState(() => _isWeightAtLeast50 = v),
            ),
            _buildQuestionTile(
              title:
                  'I feel healthy today with no fever, infection, or active antibiotics.',
              value: _isFeelingWell,
              onChanged: (v) => setState(() => _isFeelingWell = v),
            ),
            _buildQuestionTile(
              title:
                  'No major surgery, blood transfusion, tattoo, or piercing in the past 6 months.',
              value: _noRecentSurgeryOrTattoo,
              onChanged: (v) => setState(() => _noRecentSurgeryOrTattoo = v),
            ),
            _buildQuestionTile(
              title:
                  'At least 90 days have passed since my last whole-blood donation.',
              value: _lastDonationOver90Days,
              onChanged: (v) => setState(() => _lastDonationOver90Days = v),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: allConfirmed
                    ? (isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                        : const Color(0xFFF0FDF4))
                    : AppColors.surfaceMutedOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: allConfirmed
                      ? AppColors.success
                      : AppColors.borderOf(context),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    allConfirmed
                        ? Icons.check_circle_rounded
                        : Icons.fact_check_outlined,
                    color:
                        allConfirmed ? AppColors.success : AppColors.secondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allConfirmed
                              ? 'Preliminary Check Passed (5/5)'
                              : 'Confirm All 5 Safety Criteria',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: allConfirmed
                                ? (isDark
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFF166534))
                                : AppColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allConfirmed
                              ? 'You meet preliminary self-screening criteria. Proceed to a licensed hospital blood bank for hemoglobin & physician clearance.'
                              : 'Toggle each item that applies to you. If any criterion is not met, please wait or consult a physician before donating.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              BloodCompatibility.preliminaryTriageDisclaimer,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMutedOf(context),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.success,
      value: value,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryOf(context),
        ),
      ),
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}
