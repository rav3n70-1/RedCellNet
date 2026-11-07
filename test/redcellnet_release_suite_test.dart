// test/redcellnet_release_suite_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/utils/blood_compatibility.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/onboarding_page.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Component-Aware Blood Compatibility & Medical Safety', () {
    test('Returns false whenever donor or recipient blood group is null, empty, or Unset', () {
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: null,
          recipientBloodType: 'O+',
        ),
        isFalse,
      );
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: '',
          recipientBloodType: 'AB+',
        ),
        isFalse,
      );
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'UNSET',
          recipientBloodType: 'A+',
        ),
        isFalse,
      );
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'O-',
          recipientBloodType: null,
        ),
        isFalse,
      );
      expect(BloodCompatibility.canDonateTo(null), isEmpty);
      expect(BloodCompatibility.canReceiveFrom(''), isEmpty);
    });

    test('Whole Blood & Red Cells follow standard RBC ABO/RhD rules', () {
      // O- is universal RBC donor; AB+ is universal RBC recipient
      expect(BloodCompatibility.canDonateTo('O-').length, 8);
      expect(BloodCompatibility.canReceiveFrom('AB+').length, 8);

      // O- recipient can only receive O-
      expect(BloodCompatibility.canReceiveFrom('O-'), ['O-']);
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'O+',
          recipientBloodType: 'O-',
          componentType: 'Red Cells',
        ),
        isFalse,
      );
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'A-',
          recipientBloodType: 'AB-',
          componentType: 'Whole Blood',
        ),
        isTrue,
      );
    });

    test('Plasma follows inverted ABO antibody compatibility (AB universal plasma donor)', () {
      // AB plasma has neither anti-A nor anti-B -> compatible with O, A, B, AB recipients
      expect(
        BloodCompatibility.canDonateTo('AB+', componentType: 'Plasma').length,
        8,
      );
      expect(
        BloodCompatibility.canDonateTo('AB-', componentType: 'Plasma').length,
        8,
      );

      // O plasma contains both anti-A and anti-B -> only O recipients can receive O plasma
      final oPlasmaRecipients =
          BloodCompatibility.canDonateTo('O-', componentType: 'Plasma');
      expect(oPlasmaRecipients, containsAll(['O+', 'O-']));
      expect(oPlasmaRecipients, isNot(contains('A+')));
      expect(oPlasmaRecipients, isNot(contains('AB+')));
    });

    test('Platelets enforce RhD alloimmunization protection for Rh-negative recipients', () {
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'A+',
          recipientBloodType: 'A-',
          componentType: 'Platelets',
        ),
        isFalse,
      );
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'A-',
          recipientBloodType: 'A-',
          componentType: 'Platelets',
        ),
        isTrue,
      );
      expect(
        BloodCompatibility.isCompatible(
          donorBloodType: 'A-',
          recipientBloodType: 'A+',
          componentType: 'Platelets',
        ),
        isTrue,
      );
    });

    test('Mandatory clinical cross-match & preliminary triage disclaimers are present', () {
      expect(
        BloodCompatibility.medicalCrossMatchDisclaimer,
        contains('cross-matching'),
      );
      expect(
        BloodCompatibility.preliminaryTriageDisclaimer,
        contains('90-day'),
      );
    });
  });

  group('2. OCR Blood Group Extraction from Lab Reports', () {
    test('Extracts symbol-suffixed groups (O+, AB-, A+) without word-boundary failure', () {
      expect(
        BloodCompatibility.extractBloodTypeFromOcr(
          'DIAGNOSTIC LAB REPORT\nPatient Blood Group: O+\nVerified Pathologist',
        ),
        'O+',
      );
      expect(
        BloodCompatibility.extractBloodTypeFromOcr('Result: AB- (Confirmed)'),
        'AB-',
      );
      expect(
        BloodCompatibility.extractBloodTypeFromOcr('Blood Type : B POSITIVE'),
        'B+',
      );
    });

    test('Extracts two-line pathology reports (ABO Group + Rh(D) Factor)', () {
      const pathologyReport = '''
        POPULAR DIAGNOSTIC CENTRE LTD.
        Test: ABO & Rh Grouping
        ABO Group : "A"
        Rh (D) Factor : Negative
      ''';
      expect(BloodCompatibility.extractBloodTypeFromOcr(pathologyReport), 'A-');
    });

    test('Returns null when OCR text contains no valid blood group', () {
      expect(BloodCompatibility.extractBloodTypeFromOcr(''), isNull);
      expect(
        BloodCompatibility.extractBloodTypeFromOcr(
          'Complete Blood Count: Hemoglobin 13.8 g/dL, WBC 7,200/uL',
        ),
        isNull,
      );
    });
  });

  group('3. WHO 90-Day Donor Recovery Cooldown', () {
    test('Enforces strict 90-day cooldown and computes exact remaining days', () {
      final now = DateTime.utc(2026, 11, 7, 12, 0);
      final recentDonation = now.subtract(const Duration(days: 30));

      final cooldown = BloodCompatibility.checkEligibility(
        lastDonationDate: recentDonation,
        now: now,
      );
      expect(cooldown.isEligible, isFalse);
      expect(cooldown.daysRemaining, 60);
      expect(cooldown.nextEligibleDate, recentDonation.add(const Duration(days: 90)));

      final completedCooldown = BloodCompatibility.checkEligibility(
        lastDonationDate: now.subtract(const Duration(days: 91)),
        now: now,
      );
      expect(completedCooldown.isEligible, isTrue);
      expect(completedCooldown.daysRemaining, 0);
    });
  });

  group('4. AppSettingsService Persistence, Localization & Drafts', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Persists ThemeMode (system default), EN/BN translations, drafts, and bookmarks', () async {
      final settings = AppSettingsService();
      await settings.init();

      expect(settings.themeModeNotifier.value, ThemeMode.system);
      await settings.setThemeMode(ThemeMode.dark);
      expect(settings.themeModeNotifier.value, ThemeMode.dark);

      await settings.setLanguage('en');
      expect(settings.tr('Emergency', bn: 'জরুরি'), 'Emergency');
      await settings.setLanguage('bn');
      expect(settings.isBengali, isTrue);
      expect(settings.tr('Emergency', bn: 'জরুরি'), 'জরুরি');

      await settings.saveRequestDraft({
        'patientName': 'Rahim Uddin',
        'bloodType': 'B+',
      });
      final draft = await settings.loadRequestDraft();
      expect(draft?['patientName'], 'Rahim Uddin');
      await settings.clearRequestDraft();
      expect(await settings.loadRequestDraft(), isNull);

      final added = await settings.toggleBookmarkedRequest('req-101');
      expect(added, isTrue);
      expect(settings.bookmarkedRequestsNotifier.value, contains('req-101'));
      final removed = await settings.toggleBookmarkedRequest('req-101');
      expect(removed, isFalse);

      // Reset to English & Light for subsequent widget tests
      await settings.setLanguage('en');
      await settings.setThemeMode(ThemeMode.light);
    });
  });

  group('5. DonationCenter Model Null-Safe Parsing', () {
    test('Validates coordinate bounds and parses operational status & inventory', () {
      final valid = DonationCenter.fromMap(
        {
          'name': 'DMCH Blood Bank',
          'address': 'Secretariat Rd',
          'city': 'Dhaka',
          'latitude': 23.7258,
          'longitude': 90.3976,
          'facility_type': 'Hospital Blood Bank',
          'operational_status': 'Open',
          'is_verified': true,
          'blood_inventory': {'O-': 4, 'A+': 12},
        },
        id: 'center-1',
      );

      expect(valid.hasValidCoordinates, isTrue);
      expect(valid.bloodInventory?['O-'], 4);
      expect(valid.isVerified, isTrue);

      final zeroCoords = DonationCenter.fromMap(
        {
          'name': 'Unmapped Center',
          'address': 'Unknown',
          'latitude': 0,
          'longitude': 0,
        },
        id: 'center-2',
      );
      expect(zeroCoords.hasValidCoordinates, isFalse);
    });
  });

  group('6. Clinical & Bilingual UI Widgets (Light + Dark Modes)', () {
    testWidgets(
        'DigitalPassCard displays Unset instead of O+ when bloodType is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: DigitalPassCard(
                donorName: 'Nusrat Jahan',
                bloodType: '',
                donorId: 'USR-1234',
                isVerified: false,
                totalDonations: 0,
                livesSaved: 0,
                lastDonationDate: '',
                nextEligibleDate: '',
                emergencyContact: '',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Unset'), findsOneWidget);
      expect(find.text('O+'), findsNothing);
    });

    testWidgets(
        'DonorSelfTriageSheet starts with 0/5 unchecked items and renders clinical disclaimer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: DonorSelfTriageSheet(),
          ),
        ),
      );

      expect(find.textContaining('0/5 confirmed'), findsOneWidget);
      expect(
        find.textContaining('Final medical screening'),
        findsOneWidget,
      );
    });

    testWidgets('OnboardingPage renders in Bengali and Dark Mode without overflow',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettingsService();
      await settings.init();
      await settings.setLanguage('bn');

      bool finished = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: OnboardingPage(
            onFinished: () {
              finished = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('দ্রুত ও বহু-রক্তদাতা'), findsOneWidget);
      expect(finished, isFalse);

      await settings.setLanguage('en');
    });
  });

  group('7. Zero-Cost Features, Upgraded Flip Pass & Brand Logo', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Donor streak preserves count when Medical Freeze is active', () async {
      final settings = AppSettingsService();
      await settings.init();

      final oldHistory = [
        {
          'date': DateTime.now()
              .subtract(const Duration(days: 260))
              .toIso8601String(),
        },
        {
          'date': DateTime.now()
              .subtract(const Duration(days: 380))
              .toIso8601String(),
        },
      ];

      // Without freeze, >210 days since last donation resets streak to 0
      expect(
        settings.computeDonorStreak(oldHistory, isFrozenOverride: false),
        0,
      );

      // With Medical Freeze active, donor is never penalized for medical deferral
      expect(
        settings.computeDonorStreak(oldHistory, isFrozenOverride: true),
        2,
      );
    });

    test('Offline emergency cache, health journal, .ics calendar & fuzzy search work',
        () async {
      final settings = AppSettingsService();
      await settings.init();

      await settings.cacheEmergencyRequests([
        {
          'id': 'req-1',
          'blood_type': 'O-',
          'hospital_name': 'Dhaka Medical College Hospital',
          'city': 'Dhaka',
        }
      ]);
      final cached = await settings.loadCachedEmergencyRequests();
      expect(cached.length, 1);
      expect(cached.first['blood_type'], 'O-');

      await settings.addHealthJournalEntry({
        'id': 'hj-1',
        'hemoglobin_g_dl': '14.4',
        'blood_pressure': '120/80',
        'notes': 'Feeling great',
      });
      final journal = await settings.getHealthJournalEntries();
      expect(journal.length, 1);
      expect(journal.first['hemoglobin_g_dl'], '14.4');

      final ics = settings.generateBloodCampIcs(
        title: 'DMCH Blood Drive',
        location: 'Dhaka',
        description: 'Community drive',
        startTime: DateTime.utc(2026, 11, 10, 9),
        endTime: DateTime.utc(2026, 11, 10, 15),
      );
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('SUMMARY:DMCH Blood Drive'));

      expect(
        AppSettingsService.fuzzyMatchScore(
            'Dhaka Medical College Hospital', 'dhka med'),
        greaterThan(0.30),
      );
    });

    testWidgets(
        'Upgraded DigitalPassCard renders Gold Guardian tier, Action Dock, and flips cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DigitalPassCard(
                donorName: 'Tanvir Hasan',
                bloodType: 'O-',
                donorId: 'RCN-99887766',
                isVerified: true,
                totalDonations: 6,
                livesSaved: 18,
                lastDonationDate: 'Oct 1, 2026',
                nextEligibleDate: 'Dec 30, 2026',
                emergencyContact: '01711000000',
                points: 650,
                streakCount: 4,
                isEligible: false,
                daysUntilEligible: 22,
                showActionDock: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('GOLD GUARDIAN'), findsOneWidget);
      expect(find.text('O-'), findsOneWidget);
      expect(find.text('Share PNG'), findsOneWidget);
      expect(find.text('Hospital QR'), findsOneWidget);
      expect(find.byType(RedCellNetLogo), findsOneWidget);
    });
  });
}
