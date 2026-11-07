// lib/core/services/app_settings_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.redcellnet.lifepulse/native_bridge');

  static const String _keyThemeMode = 'rcn_theme_mode';
  static const String _keyLanguage = 'rcn_language';
  static const String _keyOnboardingDone = 'rcn_onboarding_completed';
  static const String _keyRequestDraft = 'rcn_blood_request_draft';
  static const String _keyBookmarkedRequests = 'rcn_bookmarked_requests';
  static const String _keyStaffWorkspaceMode = 'rcn_staff_workspace_mode';
  static const String _keyBiometricLockEnabled = 'rcn_biometric_lock_enabled';

  // Zero-Cost Offline & Health Keys
  static const String _keyCachedEmergencyRequests = 'rcn_cached_emergency_requests';
  static const String _keyCachedUserProfile = 'rcn_cached_user_profile';
  static const String _keyOfflineActionQueue = 'rcn_offline_action_queue';
  static const String _keyStreakFrozen = 'rcn_donor_streak_frozen';
  static const String _keyStreakFreezeReason = 'rcn_donor_streak_freeze_reason';
  static const String _keyHealthJournal = 'rcn_donor_health_journal';

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

  /// Tracks whether the donor's streak is currently protected by Medical Freeze.
  final ValueNotifier<bool> streakFrozenNotifier = ValueNotifier<bool>(false);
  String? _streakFreezeReason;

  /// Tracks whether Biometric App Lock (Face / Fingerprint) is enabled.
  final ValueNotifier<bool> biometricLockEnabledNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> biometricSessionUnlockedNotifier =
      ValueNotifier<bool>(false);

  /// Post-login / Post-signup interactive greeting state (`'login'` or `'signup'`).
  final ValueNotifier<String?> pendingInteractiveGreetingNotifier =
      ValueNotifier<String?>(null);

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

      streakFrozenNotifier.value = _prefs?.getBool(_keyStreakFrozen) ?? false;
      _streakFreezeReason = _prefs?.getString(_keyStreakFreezeReason);

      final bioEnabled = _prefs?.getBool(_keyBiometricLockEnabled) ?? false;
      biometricLockEnabledNotifier.value = bioEnabled;
      biometricSessionUnlockedNotifier.value = !bioEnabled;

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

  // --- Zero-Cost Feature 1: Offline Emergency Cache ---
  Future<void> cacheEmergencyRequests(
      List<Map<String, dynamic>> requests) async {
    try {
      final prefs = await _ensurePrefs();
      final trimmed = requests.take(25).map((r) {
        final copy = Map<String, dynamic>.from(r);
        return copy;
      }).toList();
      await prefs?.setString(_keyCachedEmergencyRequests, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('cacheEmergencyRequests notice: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadCachedEmergencyRequests() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs?.getString(_keyCachedEmergencyRequests);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await _ensurePrefs();
      await prefs?.setString(_keyCachedUserProfile, jsonEncode(profile));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadCachedUserProfile() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs?.getString(_keyCachedUserProfile);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  // --- Zero-Cost Feature 2: Queued Offline Mutations ---
  Future<void> enqueueOfflineAction(Map<String, dynamic> action) async {
    final prefs = await _ensurePrefs();
    final current = await loadOfflineActionQueue();
    final nextAction = <String, dynamic>{
      ...action,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    };
    current.add(nextAction);
    await prefs?.setString(_keyOfflineActionQueue, jsonEncode(current));
  }

  Future<List<Map<String, dynamic>>> loadOfflineActionQueue() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs?.getString(_keyOfflineActionQueue);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> clearOfflineActionQueue() async {
    final prefs = await _ensurePrefs();
    await prefs?.remove(_keyOfflineActionQueue);
  }

  // --- Zero-Cost Feature 3: Donor Streaks with Medical Freeze ---
  bool get isStreakFrozen => streakFrozenNotifier.value;
  String? get streakFreezeReason => _streakFreezeReason;

  Future<void> setStreakFreezeState(bool frozen, {String? reason}) async {
    streakFrozenNotifier.value = frozen;
    _streakFreezeReason = frozen ? (reason?.trim().isNotEmpty == true ? reason!.trim() : 'Medical Deferral') : null;
    final prefs = await _ensurePrefs();
    await prefs?.setBool(_keyStreakFrozen, frozen);
    if (_streakFreezeReason != null) {
      await prefs?.setString(_keyStreakFreezeReason, _streakFreezeReason!);
    } else {
      await prefs?.remove(_keyStreakFreezeReason);
    }
  }

  /// Calculates the donor's active donation streak.
  /// Each donation within ~180 days (twice a year) extends the streak.
  /// When [isFrozenOverride] or [isStreakFrozen] is true (e.g. temporary medical
  /// deferral, low hemoglobin, travel, pregnancy), the streak never resets to 0.
  int computeDonorStreak(
    List<dynamic> donationHistory, {
    bool? isFrozenOverride,
    int? fallbackDonationsCount,
  }) {
    final frozen = isFrozenOverride ?? streakFrozenNotifier.value;
    final dates = <DateTime>[];
    for (final item in donationHistory) {
      if (item is Map) {
        final rawDate = (item['date'] ?? item['donated_at'] ?? item['created_at'] ?? '').toString();
        final parsed = DateTime.tryParse(rawDate);
        if (parsed != null) {
          dates.add(parsed.toUtc());
        }
      }
    }

    if (dates.isEmpty) {
      final count = fallbackDonationsCount ?? donationHistory.length;
      return count > 0 ? 1 : 0;
    }

    dates.sort((a, b) => b.compareTo(a)); // newest first
    final now = DateTime.now().toUtc();
    final daysSinceLatest = now.difference(dates.first).inDays;

    // Without medical freeze, if the last donation was more than 210 days ago, streak resets.
    if (!frozen && daysSinceLatest > 210) {
      return 0;
    }

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final gapDays = dates[i].difference(dates[i + 1]).inDays.abs();
      if (gapDays <= 210 || frozen) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // --- Zero-Cost Feature 4: Personal Donation & Hemoglobin Journal ---
  Future<List<Map<String, dynamic>>> getHealthJournalEntries() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs?.getString(_keyHealthJournal);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        list.sort((a, b) {
          final da = DateTime.tryParse((a['recorded_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse((b['recorded_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        return list;
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> addHealthJournalEntry(Map<String, dynamic> entry) async {
    final prefs = await _ensurePrefs();
    final current = await getHealthJournalEntries();
    final newEntry = <String, dynamic>{
      'id': entry['id'] ?? 'hj_${DateTime.now().millisecondsSinceEpoch}',
      'recorded_at': entry['recorded_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'hemoglobin_g_dl': entry['hemoglobin_g_dl'],
      'blood_pressure': entry['blood_pressure'] ?? '',
      'weight_kg': entry['weight_kg'],
      'pulse_bpm': entry['pulse_bpm'],
      'feeling_rating': entry['feeling_rating'] ?? 5,
      'iron_supplement': entry['iron_supplement'] == true,
      'notes': entry['notes'] ?? '',
    };
    current.insert(0, newEntry);
    await prefs?.setString(_keyHealthJournal, jsonEncode(current));
  }

  Future<void> deleteHealthJournalEntry(String entryId) async {
    final prefs = await _ensurePrefs();
    final current = await getHealthJournalEntries();
    current.removeWhere((e) => e['id']?.toString() == entryId);
    await prefs?.setString(_keyHealthJournal, jsonEncode(current));
  }

  // --- Zero-Cost Feature 5: Blood Camp Calendar & .ics / Google Calendar Export ---
  List<Map<String, dynamic>> getUpcomingBloodCamps() {
    final now = DateTime.now();
    return <Map<String, dynamic>>[
      {
        'id': 'camp_dmch_drive',
        'title': 'DMCH Emergency Red Cell & Platelet Drive',
        'organizer': 'Dhaka Medical College Transfusion Dept',
        'location': 'DMCH Blood Bank Auditorium, Ramna, Dhaka',
        'city': 'Dhaka',
        'start_time': now.add(const Duration(days: 3, hours: 2)).toIso8601String(),
        'end_time': now.add(const Duration(days: 3, hours: 8)).toIso8601String(),
        'target_units': 150,
        'description':
            'Walk-in whole blood & apheresis platelet drive with free Hemoglobin, Blood Grouping & Hepatitis screening.',
      },
      {
        'id': 'camp_red_crescent_youth',
        'title': 'BDRCS Thalassemia Support Blood Camp',
        'organizer': 'Bangladesh Red Crescent Society',
        'location': '7/5 Aurongzeb Road, Mohammadpur, Dhaka',
        'city': 'Dhaka',
        'start_time': now.add(const Duration(days: 7, hours: 3)).toIso8601String(),
        'end_time': now.add(const Duration(days: 7, hours: 9)).toIso8601String(),
        'target_units': 200,
        'description':
            'Dedicated blood drive supporting pediatric Thalassemia patients requiring regular packed red cell transfusions.',
      },
      {
        'id': 'camp_cmc_lifepulse',
        'title': 'Chattogram LifePulse Community Blood Drive',
        'organizer': 'Chittagong Medical College & Sandhani',
        'location': 'CMC Academic Building Ground Floor, Chattogram',
        'city': 'Chattogram',
        'start_time': now.add(const Duration(days: 11, hours: 2)).toIso8601String(),
        'end_time': now.add(const Duration(days: 11, hours: 7)).toIso8601String(),
        'target_units': 120,
        'description':
            'Community donor registration, free iron/hemoglobin consultation, and emergency O- / AB- registry drive.',
      },
      {
        'id': 'camp_somc_sylhet',
        'title': 'Sylhet Maternal & Trauma Blood Reserve Camp',
        'organizer': 'MAG Osmani Medical College Hospital',
        'location': 'Medical College Road, Sylhet',
        'city': 'Sylhet',
        'start_time': now.add(const Duration(days: 15, hours: 1)).toIso8601String(),
        'end_time': now.add(const Duration(days: 15, hours: 6)).toIso8601String(),
        'target_units': 100,
        'description':
            'Regional emergency blood reserve camp with digital donor pass verification and wellness checkup.',
      },
    ];
  }

  String _formatIcsUtc(DateTime dt) {
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  String generateBloodCampIcs({
    required String title,
    required String location,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final nowStamp = _formatIcsUtc(DateTime.now());
    final startStamp = _formatIcsUtc(startTime);
    final endStamp = _formatIcsUtc(endTime);
    final safeTitle = title.replaceAll('\n', ' ').trim();
    final safeLocation = location.replaceAll('\n', ' ').trim();
    final safeDesc = description.replaceAll('\n', '\\n').trim();

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//RedCellNet//LifePulse Blood Network//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:rcn-${startTime.millisecondsSinceEpoch}@redcellnet.org',
      'DTSTAMP:$nowStamp',
      'DTSTART:$startStamp',
      'DTEND:$endStamp',
      'SUMMARY:$safeTitle',
      'LOCATION:$safeLocation',
      'DESCRIPTION:$safeDesc',
      'STATUS:CONFIRMED',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  String buildGoogleCalendarUrl({
    required String title,
    required String location,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final dates = '${_formatIcsUtc(startTime)}/${_formatIcsUtc(endTime)}';
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': dates,
      'details': description,
      'location': location,
    });
    return uri.toString();
  }

  // --- Zero-Cost Feature 6: Rich WhatsApp / SMS Emergency Card Formatter ---
  String formatEmergencyShareMessage(Map<String, dynamic> req) {
    final bg = (req['blood_type'] ?? 'Urgent').toString();
    final comp = (req['blood_component'] ?? 'Whole Blood').toString();
    final hospital = (req['hospital_name'] ?? 'Hospital').toString();
    final city = (req['city'] ?? '').toString();
    final urgency = (req['urgency'] ?? 'High').toString().toUpperCase();
    final units = (req['units'] ?? 1).toString();
    final fulfilled = (req['units_fulfilled'] ?? 0).toString();
    final patient = (req['patient_name'] ?? 'Emergency Patient').toString();
    final phone = (req['contact_phone'] ?? '').toString();
    final reqId = (req['id'] ?? '').toString();

    return '🚨 *URGENT $bg ($comp) BLOOD NEEDED* 🚨\n'
        '━━━━━━━━━━━━━━━━━━━━\n'
        '🩸 *Blood Group:* $bg ($comp)\n'
        '⚡ *Priority:* $urgency ($fulfilled/$units Units Fulfilled)\n'
        '🏥 *Hospital:* $hospital${city.isNotEmpty ? ', $city' : ''}\n'
        '👤 *Patient:* $patient\n'
        '${phone.isNotEmpty ? '📞 *Contact:* $phone\n' : ''}'
        '⚕️ *Note:* Hospital cross-matching required before transfusion.\n'
        '━━━━━━━━━━━━━━━━━━━━\n'
        '🔗 Respond on *RedCellNet LifePulse*${reqId.isNotEmpty ? ' (Ref: #${reqId.substring(0, reqId.length > 8 ? 8 : reqId.length)})' : ''}';
  }

  // --- Zero-Cost Feature 7: Client-Side Trigram / Fuzzy Search ---
  /// Returns a similarity score between 0.0 and 1.0 for typo-tolerant search.
  static double fuzzyMatchScore(String source, String query) {
    final s = source.toLowerCase().trim();
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return 1.0;
    if (s.isEmpty) return 0.0;
    if (s == q) return 1.0;
    if (s.contains(q)) return 0.92;

    // Token prefix / substring match
    final qTokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (qTokens.length > 1 && qTokens.every((t) => s.contains(t))) {
      return 0.88;
    }

    // Character 3-gram (trigram) Jaccard similarity (mirrors Postgres pg_trgm)
    Set<String> trigrams(String input) {
      final padded = '  $input ';
      final out = <String>{};
      for (int i = 0; i <= padded.length - 3; i++) {
        out.add(padded.substring(i, i + 3));
      }
      return out;
    }

    final sTri = trigrams(s);
    final qTri = trigrams(q);
    if (sTri.isEmpty || qTri.isEmpty) return 0.0;
    final intersection = sTri.intersection(qTri).length;
    final union = sTri.union(qTri).length;
    final jaccard = union == 0 ? 0.0 : intersection / union;
    final queryCoverage = intersection / qTri.length;
    return jaccard > queryCoverage * 0.75 ? jaccard : queryCoverage * 0.75;
  }

  // --- Zero-Cost Feature 8: Deterministic Referral Code ---
  static String generateReferralCode({
    String? userId,
    String? fullName,
    String? bloodGroup,
  }) {
    final cleanBg = (bloodGroup ?? '')
        .toUpperCase()
        .replaceAll('+', 'P')
        .replaceAll('-', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final rawSeed = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim().replaceAll('-', '').toUpperCase()
        : (fullName ?? 'DONOR').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = rawSeed.length >= 4
        ? rawSeed.substring(0, 4)
        : rawSeed.padRight(4, 'X');
    return 'RCN-${cleanBg.isNotEmpty ? '$cleanBg-' : ''}$suffix';
  }

  // --- Biometric Security (Face + Fingerprint) & Native Home Screen Widget Bridge ---
  bool get isBiometricLockEnabled => biometricLockEnabledNotifier.value;
  bool get biometricLockEnabled => biometricLockEnabledNotifier.value;

  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final supported =
          await _nativeChannel.invokeMethod<bool>('canCheckBiometrics');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricAvailable() => canCheckBiometrics();

  Future<bool> authenticateBiometric({
    String reason = 'Unlock RedCellNet LifePulse with Face or Fingerprint',
  }) async {
    if (kIsWeb) {
      biometricSessionUnlockedNotifier.value = true;
      return true;
    }
    try {
      final ok = await _nativeChannel.invokeMethod<bool>(
        'authenticateBiometric',
        {'reason': reason},
      );
      if (ok == true) {
        biometricSessionUnlockedNotifier.value = true;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Unlock RedCellNet LifePulse with Face or Fingerprint',
  }) =>
      authenticateBiometric(reason: reason);

  Future<void> setBiometricLockEnabled(bool enabled) async {
    biometricLockEnabledNotifier.value = enabled;
    biometricSessionUnlockedNotifier.value = true;
    final prefs = await _ensurePrefs();
    await prefs?.setBool(_keyBiometricLockEnabled, enabled);
  }

  void triggerInteractiveGreeting(String mode) {
    pendingInteractiveGreetingNotifier.value = mode;
  }

  String? consumeInteractiveGreeting() {
    final val = pendingInteractiveGreetingNotifier.value;
    pendingInteractiveGreetingNotifier.value = null;
    return val;
  }

  Future<void> syncHomeScreenWidget({
    required String donorName,
    String? bloodType,
    String? bloodGroup,
    String? donorId,
    bool? isVerified,
    String? verificationStatus,
    String? verifiedText,
    String? eligibilityText,
    String? statusText,
    String? nextEligibleText,
    bool? isEligible,
    String? statsText,
    String? donationsText,
    String? city,
    int? totalDonations,
    int? points,
  }) async {
    if (kIsWeb) return;
    final resolvedBlood = (bloodType ?? bloodGroup ?? 'UNSET').trim();
    final resolvedVerified = isVerified ??
        ((verifiedText ?? verificationStatus ?? '')
            .toLowerCase()
            .contains('verified by redcellnet'));
    final resolvedVerificationStatus = verifiedText ??
        verificationStatus ??
        (resolvedVerified ? 'Verified by RedCellNet' : 'Verification Pending');
    final resolvedEligibility = eligibilityText ??
        statusText ??
        nextEligibleText ??
        ((isEligible ?? true)
            ? 'Ready to Save Lives'
            : 'Recovery Cooldown Active');
    final resolvedStats = statsText ??
        donationsText ??
        '${totalDonations ?? 0} Donations${city != null && city.isNotEmpty ? ' • $city' : ''}${points != null ? ' • $points Pts' : ''}';
    try {
      await _nativeChannel.invokeMethod('updateHomeWidget', {
        'donorName': donorName,
        'bloodType': resolvedBlood.isEmpty ? 'UNSET' : resolvedBlood,
        'donorId': donorId ?? '',
        'isVerified': resolvedVerified,
        'verificationStatus': resolvedVerificationStatus,
        'eligibilityText': resolvedEligibility,
        'isEligible': isEligible ?? true,
        'statsText': resolvedStats,
      });
    } catch (_) {}
  }

  Future<bool> requestPinHomeScreenWidget() async {
    if (kIsWeb) return false;
    try {
      final pinned =
          await _nativeChannel.invokeMethod<bool>('requestPinHomeWidget');
      return pinned ?? false;
    } catch (_) {
      return false;
    }
  }

  // --- English Key Aliases (resolves snake_case keys like nav_profile) ---
  static const Map<String, String> _enAliases = {
    'nav_profile': 'Donor Profile',
    'nav_home': 'Home',
    'nav_requests': 'Blood Requests',
    'nav_nearby': 'Nearby Map',
    'nav_learn': 'Health Guide',
    'nav_settings': 'Settings',
  };

  // --- English & Bengali Dictionary ---
  static const Map<String, String> _bnDictionary = {
    // Navigation & Aliases
    'nav_profile': 'রক্তদাতা প্রোফাইল',
    'Donor Profile': 'রক্তদাতা প্রোফাইল',
    'nav_home': 'হোম',
    'nav_requests': 'রক্তের আবেদন',
    'nav_nearby': 'কাছাকাছি',
    'nav_learn': 'স্বাস্থ্য জ্ঞান',
    'nav_settings': 'সেটিংস',
    'Settings': 'সেটিংস',
    'Recognition & Milestones': 'স্বীকৃতি ও মাইলফলক',
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
    'Nickname / Last Name': 'ডাকনাম / শেষ নাম',
    'Phone Number': 'মোবাইল নম্বর',
    'Blood Group': 'রক্তের গ্রুপ',
    'City / Area': 'শহর / এলাকা',
    'Referral Code (Optional)': 'রেফারেল কোড (ঐচ্ছিক)',
    'Skip': 'এড়িয়ে যান',
    'Next': 'পরবর্তী',
    'Get Started': 'শুরু করুন',
    'Browse Emergency Feed as Guest': 'গেস্ট হিসেবে জরুরি আবেদন দেখুন',

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
    'Compatible with Me': 'আমার রক্তের সাথে সামঞ্জস্যপূর্ণ',
    'Blood Camps': 'রক্তদান ক্যাম্প',
    'Health Journal': 'হিমোগ্লোবিন ও স্বাস্থ্য ডায়েরি',
    'Top Heroes': 'সেরা রক্তদাতা',

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
    'Verified by RedCellNet': 'RedCellNet দ্বারা যাচাইকৃত',
    'Verification Pending': 'যাচাইয়ের অপেক্ষায়',
    'Donor Verification': 'রক্তদাতা যাচাইকরণ',
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
    final resolvedEn = _enAliases[englishKey] ?? englishKey;
    if (isBengali) {
      if (bn != null && bn.isNotEmpty) return bn;
      final mapped = _bnDictionary[englishKey] ?? _bnDictionary[resolvedEn];
      if (mapped != null && mapped.isNotEmpty) return mapped;
    }
    return resolvedEn;
  }
}
