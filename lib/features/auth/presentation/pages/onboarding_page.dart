// lib/features/auth/presentation/pages/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await AppSettingsService().completeOnboarding();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService();
    final isDark = AppColors.isDark(context);

    final slides = [
      _OnboardingSlideData(
        icon: Icons.emergency_rounded,
        accent: AppColors.primary,
        badge: settings.tr('Emergency Hospital Coordination',
            bn: 'জরুরি হাসপাতাল রক্ত সমন্বয়'),
        title: settings.tr(
          'Fast, Multi-Donor Blood Fulfillment',
          bn: 'দ্রুত ও বহু-রক্তদাতা সমন্বয় ব্যবস্থা',
        ),
        description: settings.tr(
          'Post verified hospital blood requests for Whole Blood, Red Cells, Platelets, or Plasma and track real-time unit fulfillment.',
          bn: 'সম্পূর্ণ রক্ত, লোহিত কণিকা, প্লাটিলেট বা প্লাজমার জরুরি আবেদন করুন এবং রিয়েল-টাইমে ইউনিট পূরণের অগ্রগতি দেখুন।',
        ),
      ),
      _OnboardingSlideData(
        icon: Icons.verified_user_rounded,
        accent: AppColors.secondary,
        badge: settings.tr('Clinical Safety First',
            bn: 'চিকিৎসা নিরাপত্তা সর্বাগ্রে'),
        title: settings.tr(
          'Verified Blood Groups & 90-Day Recovery',
          bn: 'যাচাইকৃত রক্তের গ্রুপ ও ৯০ দিনের সুরক্ষা বিরতি',
        ),
        description: settings.tr(
          'Scan laboratory reports for staff-verified donor badges while automatic WHO 90-day recovery windows protect donor health.',
          bn: 'ল্যাব রিপোর্ট স্ক্যান করে যাচাইকৃত ডোনার ব্যাজ পান এবং ৯০ দিনের স্বয়ংক্রিয় বিরতিতে নিরাপদ থাকুন।',
        ),
      ),
      _OnboardingSlideData(
        icon: Icons.shield_outlined,
        accent: AppColors.success,
        badge: settings.tr('Strict Privacy Protection',
            bn: 'কঠোর গোপনীয়তা সুরক্ষা'),
        title: settings.tr(
          'Protected Contact & Coarse Area Matching',
          bn: 'সুরক্ষিত যোগাযোগ ও এলাকাভিত্তিক ম্যাচিং',
        ),
        description: settings.tr(
          'Exact donor coordinates are never exposed publicly, and direct phone numbers unlock only when a donor offer is accepted.',
          bn: 'রক্তদাতার সুনির্দিষ্ট অবস্থান কখনোই প্রকাশ করা হয় না এবং প্রস্তাব গৃহীত হলেই কেবল যোগাযোগ নম্বর দৃশ্যমান হয়।',
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top bar: Language + Theme + Skip
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      settings.setLanguage(settings.isBengali ? 'en' : 'bn');
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: AppColors.borderOf(context)),
                      foregroundColor: AppColors.textPrimaryOf(context),
                    ),
                    icon: const Icon(Icons.translate_rounded, size: 16),
                    label: Text(
                      settings.isBengali ? 'English' : 'বাংলা',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: settings.tr('Appearance & Theme'),
                    onPressed: () {
                      settings.toggleTheme();
                      setState(() {});
                    },
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      size: 20,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _complete,
                    child: Text(settings.tr('Skip')),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, idx) {
                    final s = slides[idx];
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: s.accent
                                    .withValues(alpha: isDark ? 0.20 : 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: s.accent.withValues(alpha: 0.30),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(s.icon, size: 48, color: s.accent),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: s.accent
                                    .withValues(alpha: isDark ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.badge,
                                style: TextStyle(
                                  color: s.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              s.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryOf(context),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              s.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: AppColors.textSecondaryOf(context),
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final selected = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: selected ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.borderOf(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentIndex < slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      _complete();
                    }
                  },
                  child: Text(
                    _currentIndex < slides.length - 1
                        ? settings.tr('Next')
                        : settings.tr('Get Started'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  final IconData icon;
  final Color accent;
  final String badge;
  final String title;
  final String description;

  const _OnboardingSlideData({
    required this.icon,
    required this.accent,
    required this.badge,
    required this.title,
    required this.description,
  });
}

