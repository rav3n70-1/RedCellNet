// lib/core/services/app_settings_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const String _keyThemeMode = 'rcn_theme_mode';
  static const String _keyLanguage = 'rcn_language';
  static const String _keyOnboardingDone = 'rcn_onboarding_completed';
  static const String _keyRequestDraft = 'rcn_blood_request_draft';
  static const String _keyBookmarkedRequests = 'rcn_bookmarked_requests';
  static const String _keyStaffWorkspaceMode = 'rcn_staff_workspace_mode';

  SharedPreferences? _prefs;
  bool _initialized = false;

  /// Defaults to ThemeMode.system per RedCellNet design specification.
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>('en');
  final ValueNotifier<bool> onboardingCompletedNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> bookmarkedRequestsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  /// Staff ('admin' / 'moderator') can switch between 'admin' console and 'donor' app.
  final ValueNotifier<String> staffWorkspaceModeNotifier =
      ValueNotifier<String>('admin');

  Future<void> init() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedTheme = _prefs?.getString(_keyThemeMode);
      if (savedTheme == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else {
        themeModeNotifier.value = ThemeMode.system;
      }

      final savedLang = _prefs?.getString(_keyLanguage);
      if (savedLang == 'en' || savedLang == 'bn') {
        languageNotifier.value = savedLang!;
      }

      onboardingCompletedNotifier.value =
          _prefs?.getBool(_keyOnboardingDone) ?? false;

      final savedBookmarks =
          _prefs?.getStringList(_keyBookmarkedRequests) ?? const <String>[];
      bookmarkedRequestsNotifier.value = savedBookmarks.toSet();

      final savedStaffMode = _prefs?.getString(_keyStaffWorkspaceMode);
      if (savedStaffMode == 'donor' || savedStaffMode == 'admin') {
        staffWorkspaceModeNotifier.value = savedStaffMode!;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('AppSettingsService.init notice: $e');
    }
  }

  Future<SharedPreferences?> _ensurePrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs;
    } catch (_) {
      return null;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final serialized = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
            ? 'light'
            : 'system';
    final prefs = await _ensurePrefs();
    await prefs?.setString(_keyThemeMode, serialized);
  }

  void toggleTheme() {
    if (themeModeNotifier.value == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  bool isDarkMode(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    if (themeModeNotifier.value == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  Future<void> setLanguage(String lang) async {
    if (lang == 'en' || lang == 'bn') {
      languageNotifier.value = lang;
      final prefs = await _ensurePrefs();
      await prefs?.setString(_keyLanguage, lang);
    }
  }

  bool get isBengali => languageNotifier.value == 'bn';

  bool get onboardingCompleted => onboardingCompletedNotifier.value;

  Future<void> completeOnboarding() async {
    onboardingCompletedNotifier.value = true;
    final prefs = await _ensurePrefs();
    await prefs?.setBool(_keyOnboardingDone, true);
  }

  Future<void> setStaffWorkspaceMode(String mode) async {
    if (mode != 'admin' && mode != 'donor') return;
    staffWorkspaceModeNotifier.value = mode;
    final prefs = await _ensurePrefs();
    await prefs?.setString(_keyStaffWorkspaceMode, mode);
  }

  // --- Request Draft Persistence ---
  Future<void> saveRequestDraft(Map<String, dynamic> draft) async {
    final prefs = await _ensurePrefs();
    await prefs?.setString(_keyRequestDraft, jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> loadRequestDraft() async {
    final prefs = await _ensurePrefs();
    final raw = prefs?.getString(_keyRequestDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> clearRequestDraft() async {
    final prefs = await _ensurePrefs();
    await prefs?.remove(_keyRequestDraft);
  }

  // --- Bookmarked Requests Sync ---
  Future<void> syncBookmarkedRequests(Iterable<String> ids) async {
    final next = ids.where((e) => e.trim().isNotEmpty).toSet();
    bookmarkedRequestsNotifier.value = next;
    final prefs = await _ensurePrefs();
    await prefs?.setStringList(_keyBookmarkedRequests, next.toList());
  }

  Future<bool> toggleBookmarkedRequest(String requestId) async {
    final current = Set<String>.from(bookmarkedRequestsNotifier.value);
    final bool added;
    if (current.contains(requestId)) {
      current.remove(requestId);
      added = false;
    } else {
      current.add(requestId);
      added = true;
    }
    bookmarkedRequestsNotifier.value = current;
    final prefs = await _ensurePrefs();
    await prefs?.setStringList(_keyBookmarkedRequests, current.toList());
    return added;
  }

  // --- English & Bengali Dictionary ---
  static const Map<String, String> _bnDictionary = {
    // Navigation
    'Home': 'হোম',
    'Requests': 'রক্তের আবেদন',
    'Nearby': 'কাছাকাছি',
    'Learn': 'স্বাস্থ্য জ্ঞান',
    'Profile': 'প্রোফাইল',
    'Notifications': 'বিজ্ঞপ্তি',
    'Admin Console': 'অ্যাডমিন কনসোল',
    'Switch to Donor View': 'ডোনার মোডে যান',
    'Switch to Admin Console': 'অ্যাডমিন কনসোলে যান',

    // Auth & Onboarding
    'Sign In': 'সাইন ইন',
    'Sign Up': 'নিবন্ধন করুন',
    'Create Account': 'অ্যাকাউন্ট তৈরি করুন',
    'Sign Out': 'সাইন আউট',
    'Email Address': 'ইমেইল ঠিকানা',
    'Password': 'পাসওয়ার্ড',
    'Confirm Password': 'পাসওয়ার্ড নিশ্চিত করুন',
    'Forgot Password?': 'পাসওয়ার্ড ভুলে গেছেন?',
    'Reset Password': 'পাসওয়ার্ড রিসেট করুন',
    'Set New Password': 'নতুন পাসওয়ার্ড সেট করুন',
    'Sign in with Google': 'গুগল দিয়ে সাইন ইন করুন',
    'Connecting Donors • Saving Lives': 'রক্তদাতা সংযোগ • জীবন রক্ষা',
    'Become a Life Saver': 'জীবন রক্ষাকারী হোন',
    'Full Name': 'পূর্ণ নাম',
    'Phone Number': 'মোবাইল নম্বর',
    'Blood Group': 'রক্তের গ্রুপ',
    'City / Area': 'শহর / এলাকা',
    'Skip': 'এড়িয়ে যান',
    'Next': 'পরবর্তী',
    'Get Started': 'শুরু করুন',

    // Home & Availability
    'Post Blood Request': 'রক্তের আবেদন করুন',
    'Request Blood': 'রক্ত চান',
    'Available to Donate': 'রক্তদানে প্রস্তুত',
    'Currently Unavailable': 'বর্তমানে অনুপস্থিত',
    'Recovery Cooldown Active': 'বিশ্রাম কাল চলছে',
    'Schedule Availability': 'সম্ভাব্য সময়সূচি',
    'Available Now': 'এখনই প্রস্তুত',
    'Snooze 24 Hours': '২৪ ঘণ্টার জন্য বিরতি',
    'Snooze 72 Hours': '৭২ ঘণ্টার জন্য বিরতি',
    'Pause Alerts 24h': '২৪ ঘণ্টা অ্যালার্ট বন্ধ',
    '60s Self-Triage': '৬০ সেকেন্ড স্বাস্থ্য যাচাই',
    'Compatibility': 'রক্তের সামঞ্জস্যতা',
    'Emergency Feed': 'জরুরি আবেদনসমূহ',
    'See All': 'সব দেখুন',

    // Blood Requests & Fulfillment
    'Blood Requests': 'রক্তের আবেদনসমূহ',
    'All': 'সব',
    'Critical': 'অতি জরুরি',
    'High': 'জরুরি',
    'Medium': 'মাঝারি',
    'Low': 'সাধারণ',
    'Saved': 'সংরক্ষিত',
    'My Requests': 'আমার আবেদন',
    'Open': 'চলমান',
    'Partially Fulfilled': 'আংশিক পূর্ণ',
    'Fulfilled': 'সম্পন্ন',
    'Cancelled': 'বাতিল',
    'Expired': 'মেয়াদোত্তীর্ণ',
    'Whole Blood': 'সম্পূর্ণ রক্ত (Whole Blood)',
    'Red Cells': 'লোহিত কণিকা (RBC)',
    'Platelets': 'প্লাটিলেট (Platelets)',
    'Plasma': 'প্লাজমা (Plasma)',
    'Offer to Donate': 'রক্তদানের প্রস্তাব দিন',
    'Withdraw Offer': 'প্রস্তাব প্রত্যাহার করুন',
    'Accept': 'গ্রহণ করুন',
    'Decline': 'প্রত্যাখ্যান',
    'Mark Donation Completed': 'রক্তদান সম্পন্ন নিশ্চিত করুন',
    'Release Slot': 'স্লট উন্মুক্ত করুন',
    'Cancel Request': 'আবেদন বাতিল করুন',
    'Edit Request': 'আবেদন সম্পাদনা করুন',
    'Share Request': 'শেয়ার করুন',
    'Call Contact': 'কল করুন',
    'Hospital Cross-Match Required': 'হাসপাতালে ক্রস-ম্যাচিং আবশ্যক',

    // Profile, Verification & Settings
    'Edit Profile': 'প্রোফাইল সম্পাদনা',
    'Verified Donor': 'যাচাইকৃত রক্তদাতা',
    'Pending Verification': 'যাচাইয়ের অপেক্ষায়',
    'Unverified': 'অযাচাইকৃত',
    'Unset / Unknown': 'নির্ধারিত নয়',
    'Upload Blood Report': 'রক্তের রিপোর্ট আপলোড করুন',
    'Verify Phone Number': 'ফোন নম্বর যাচাই করুন',
    'Log Past Donation': 'পূর্ববর্তী রক্তদান যোগ করুন',
    'Donation History': 'রক্তদানের ইতিহাস',
    'Appearance & Theme': 'থিম ও প্রদর্শন',
    'System Default': 'সিস্টেম ডিফল্ট',
    'Light Mode': 'লাইট মোড',
    'Dark Mode': 'ডার্ক মোড',
    'Language': 'ভাষা',
    'Notification Preferences': 'বিজ্ঞপ্তি সেটিংস',
    'Privacy Settings': 'গোপনীয়তা সেটিংস',
    'Change Password': 'পাসওয়ার্ড পরিবর্তন করুন',
    'Delete Account': 'অ্যাকাউন্ট মুছে ফেলুন',
  };

  String tr(String englishKey, {String? bn}) {
    if (isBengali) {
      if (bn != null && bn.isNotEmpty) return bn;
      final mapped = _bnDictionary[englishKey];
      if (mapped != null && mapped.isNotEmpty) return mapped;
    }
    return englishKey;
  }
}
