// lib/core/utils/blood_compatibility.dart

class DonorEligibilityResult {
  final bool isEligible;
  final DateTime? nextEligibleDate;
  final int daysRemaining;
  final String statusMessage;

  const DonorEligibilityResult({
    required this.isEligible,
    required this.nextEligibleDate,
    required this.daysRemaining,
    required this.statusMessage,
  });
}

/// Clinically accurate blood component compatibility, OCR lab-report extraction,
/// and WHO 90-day recovery cooldown utilities.
class BloodCompatibility {
  static const List<String> validBloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const List<String> supportedComponents = [
    'Whole Blood',
    'Red Cells',
    'Platelets',
    'Plasma',
  ];

  static const String medicalCrossMatchDisclaimer =
      'Clinical Notice: In-app compatibility is a preliminary screening aid only. '
      'Hospital blood bank cross-matching and physician clearance are mandatory before any transfusion.';

  static const String preliminaryTriageDisclaimer =
      'Preliminary self-check based on WHO donor guidelines (age 18–60, weight ≥ 50 kg, 90-day whole-blood interval). '
      'Final medical screening (hemoglobin, blood pressure, infectious disease panel) is performed at the hospital or blood center.';

  static String? normalizeBloodGroup(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().toUpperCase().replaceAll(' ', '');
    if (validBloodGroups.contains(cleaned)) return cleaned;
    return null;
  }

  /// Component-aware donor-to-recipient compatibility matching PostgreSQL `private.is_blood_compatible`.
  /// Never returns true when either blood group is null, unset, or unrecognized.
  static bool isCompatible({
    required String? donorBloodType,
    required String? recipientBloodType,
    String componentType = 'Whole Blood',
  }) {
    final donor = normalizeBloodGroup(donorBloodType);
    final recipient = normalizeBloodGroup(recipientBloodType);
    if (donor == null || recipient == null) return false;

    final comp = componentType.trim().toLowerCase();

    // Plasma (FFP) compatibility: ABO antibodies are in plasma (inverted ABO; AB is universal plasma donor).
    if (comp.contains('plasma')) {
      final dAbo = donor.substring(0, donor.length - 1);
      final rAbo = recipient.substring(0, recipient.length - 1);
      switch (rAbo) {
        case 'O':
          return dAbo == 'O' || dAbo == 'A' || dAbo == 'B' || dAbo == 'AB';
        case 'A':
          return dAbo == 'A' || dAbo == 'AB';
        case 'B':
          return dAbo == 'B' || dAbo == 'AB';
        case 'AB':
          return dAbo == 'AB';
        default:
          return false;
      }
    }

    // Platelets compatibility: Rh-negative recipients require Rh-negative donors to prevent RhD alloimmunization;
    // ABO identical preferred, with AB (low anti-A/B plasma) and O accepted per hospital transfusion guidance.
    if (comp.contains('platelet')) {
      final dRh = donor.endsWith('+') ? '+' : '-';
      final rRh = recipient.endsWith('+') ? '+' : '-';
      final dAbo = donor.substring(0, donor.length - 1);
      final rAbo = recipient.substring(0, recipient.length - 1);
      if (rRh == '-' && dRh == '+') return false;
      return dAbo == rAbo || dAbo == 'AB' || dAbo == 'O';
    }

    // Whole Blood & Packed Red Blood Cells (standard RBC compatibility)
    switch (recipient) {
      case 'AB+':
        return true;
      case 'AB-':
        return const ['O-', 'A-', 'B-', 'AB-'].contains(donor);
      case 'A+':
        return const ['O-', 'O+', 'A-', 'A+'].contains(donor);
      case 'A-':
        return const ['O-', 'A-'].contains(donor);
      case 'B+':
        return const ['O-', 'O+', 'B-', 'B+'].contains(donor);
      case 'B-':
        return const ['O-', 'B-'].contains(donor);
      case 'O+':
        return const ['O-', 'O+'].contains(donor);
      case 'O-':
        return donor == 'O-';
      default:
        return false;
    }
  }

  /// Returns all recipient blood groups that [donorBloodType] can donate to for [componentType].
  static List<String> canDonateTo(
    String? donorBloodType, {
    String componentType = 'Whole Blood',
  }) {
    final donor = normalizeBloodGroup(donorBloodType);
    if (donor == null) return const [];
    return validBloodGroups
        .where((rec) => isCompatible(
              donorBloodType: donor,
              recipientBloodType: rec,
              componentType: componentType,
            ))
        .toList();
  }

  /// Returns all donor blood groups that [recipientBloodType] can receive from for [componentType].
  static List<String> canReceiveFrom(
    String? recipientBloodType, {
    String componentType = 'Whole Blood',
  }) {
    final recipient = normalizeBloodGroup(recipientBloodType);
    if (recipient == null) return const [];
    return validBloodGroups
        .where((don) => isCompatible(
              donorBloodType: don,
              recipientBloodType: recipient,
              componentType: componentType,
            ))
        .toList();
  }

  /// Extracts blood group from OCR text of diagnostic laboratory reports.
  /// Fixes the `\b` word-boundary bug after `+` / `-` symbols and supports two-part ABO + Rh(D) lab formats.
  static String? extractBloodTypeFromOcr(String rawText) {
    if (rawText.trim().isEmpty) return null;
    final text = rawText.toUpperCase();

    // Pass 1: Contextual match near "BLOOD GROUP" / "ABO" / "GROUPING"
    final contextualPattern = RegExp(
      r'(?:BLOOD\s*(?:GROUP|TYPE)|ABO\s*(?:GROUP|TYPE)?|GROUPING)[^\n\rA-Z0-9]{0,25}'
      r'(?:"|\x27)?(AB|A|B|O)(?:"|\x27)?\s*'
      r'(\+|-|POSITIVE|POS|NEGATIVE|NEG|RH\s*(?:D)?\s*(?:\+|-|POSITIVE|POS|NEGATIVE|NEG))'
      r'(?=\s|$|[^A-Za-z0-9])',
      multiLine: true,
    );
    final ctxMatch = contextualPattern.firstMatch(text);
    if (ctxMatch != null) {
      return _buildGroup(ctxMatch.group(1)!, ctxMatch.group(2)!);
    }

    // Pass 2: Separate ABO line + Rh(D) line common on hospital pathology sheets
    final aboMatch = RegExp(
      r'(?:ABO\s*(?:GROUP|TYPE)?|BLOOD\s*GROUP)\s*[:\-=]?\s*(?:"|\x27)?(AB|A|B|O)(?:"|\x27)?(?=\s|$|[^A-Z])',
    ).firstMatch(text);
    final rhMatch = RegExp(
      r'RH(?:\s*(?:\(\s*D\s*\)|D|FACTOR|TYPE|GROUP))*(?:[\s:=]+|\s+-\s+(?=POSITIVE|POS|NEGATIVE|NEG)|\s*)(POSITIVE|POS|\+|NEGATIVE|NEG|-)(?=\s|$|[^A-Z0-9])',
    ).firstMatch(text);
    if (aboMatch != null && rhMatch != null) {
      return _buildGroup(aboMatch.group(1)!, rhMatch.group(1)!);
    }

    // Pass 3: Direct standalone blood group token (e.g. "O+", "AB-", "B POSITIVE", "A Rh+")
    // Uses explicit lookahead instead of `\b` because `+` and `-` are non-word characters!
    final standalonePattern = RegExp(
      r'(?:^|[\s:(\[/|,-])(AB|A|B|O)\s*'
      r'(\+|-|POSITIVE|NEGATIVE|RH\s*\+|RH\s*-|RH\s*POSITIVE|RH\s*NEGATIVE)'
      r'(?=\s|$|[^A-Za-z0-9])',
      multiLine: true,
    );
    final directMatch = standalonePattern.firstMatch(text);
    if (directMatch != null) {
      return _buildGroup(directMatch.group(1)!, directMatch.group(2)!);
    }

    return null;
  }

  static String? _buildGroup(String abo, String rhRaw) {
    final cleanAbo = abo.trim().toUpperCase();
    final cleanRh = rhRaw.trim().toUpperCase();
    final bool isNegative = cleanRh.contains('-') || cleanRh.contains('NEG');
    final candidate = '$cleanAbo${isNegative ? '-' : '+'}';
    return validBloodGroups.contains(candidate) ? candidate : null;
  }

  /// Evaluates WHO 90-day whole-blood recovery cooldown without allowing unsafe overrides.
  static DonorEligibilityResult checkEligibility({
    DateTime? lastDonationDate,
    DateTime? nextEligibleDate,
    int cooldownDays = 90,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    DateTime? effectiveNext = nextEligibleDate;
    if (lastDonationDate != null) {
      final computed = lastDonationDate.add(Duration(days: cooldownDays));
      if (effectiveNext == null || computed.isAfter(effectiveNext)) {
        effectiveNext = computed;
      }
    }

    if (effectiveNext != null && effectiveNext.isAfter(current)) {
      final hours = effectiveNext.difference(current).inHours;
      final days = (hours / 24).ceil().clamp(1, 366);
      return DonorEligibilityResult(
        isEligible: false,
        nextEligibleDate: effectiveNext,
        daysRemaining: days,
        statusMessage: 'Recovery cooldown active ($days day${days == 1 ? '' : 's'} remaining)',
      );
    }

    return DonorEligibilityResult(
      isEligible: true,
      nextEligibleDate: effectiveNext,
      daysRemaining: 0,
      statusMessage: 'Medically eligible by recovery window',
    );
  }
}

