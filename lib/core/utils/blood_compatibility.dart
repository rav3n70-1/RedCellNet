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

  /// Accredited Bangladesh hospitals, diagnostic centers, and voluntary blood banks
  /// recognized by the Zero-Cost Clinical Verification Engine.
  static const List<String> accreditedBangladeshLabs = [
    'Popular Diagnostic Centre',
    'Ibn Sina Diagnostic & Imaging Center',
    'Labaid Diagnostic',
    'Square Hospitals Ltd',
    'Evercare Hospital',
    'United Hospital',
    'BSMMU (PG Hospital)',
    'Dhaka Medical College Hospital (DMCH)',
    'Bangladesh Red Crescent Society',
    'Sandhani Blood Bank',
    'Badhan Voluntary Blood Donors',
    'Quantum Blood Lab',
    'BIRDEM General Hospital',
    'icddr,b Diagnostic Lab',
    'Medinova Medical Services',
    'Padma Diagnostic Centre',
    'Chevron Clinical Laboratory',
    'Epic Health Care',
    'Asgar Ali Hospital',
    'BRB Hospitals',
    'Apollo Imperial Hospital',
    'Kurmitola General Hospital',
    'Shaheed Suhrawardy Medical College',
    'Sir Salimullah Medical College (Mitford)',
    'Chittagong Medical College Hospital (CMCH)',
    'Rajshahi Medical College Hospital (RMCH)',
    'MAG Osmani Medical College Hospital',
    'Mymensingh Medical College Hospital',
    'Combined Military Hospital (CMH)',
    'National Institute of Cardiovascular Diseases (NICVD)',
    'Praava Health',
    'Aalok Healthcare',
  ];

  static const Map<String, String> _labKeywordMatchers = {
    'POPULAR DIAGNOSTIC': 'Popular Diagnostic Centre',
    'POPULAR MEDICAL': 'Popular Diagnostic Centre',
    'IBN SINA': 'Ibn Sina Diagnostic & Imaging Center',
    'LABAID': 'Labaid Diagnostic',
    'SQUARE HOSPITAL': 'Square Hospitals Ltd',
    'EVERCARE': 'Evercare Hospital',
    'APOLLO HOSPITAL': 'Evercare Hospital',
    'UNITED HOSPITAL': 'United Hospital',
    'BSMMU': 'BSMMU (PG Hospital)',
    'BANGABANDHU SHEIKH MUJIB': 'BSMMU (PG Hospital)',
    'PG HOSPITAL': 'BSMMU (PG Hospital)',
    'DHAKA MEDICAL': 'Dhaka Medical College Hospital (DMCH)',
    'DMCH': 'Dhaka Medical College Hospital (DMCH)',
    'RED CRESCENT': 'Bangladesh Red Crescent Society',
    'BDRCS': 'Bangladesh Red Crescent Society',
    'SANDHANI': 'Sandhani Blood Bank',
    'BADHAN': 'Badhan Voluntary Blood Donors',
    'QUANTUM': 'Quantum Blood Lab',
    'BIRDEM': 'BIRDEM General Hospital',
    'ICDDR': 'icddr,b Diagnostic Lab',
    'MEDINOVA': 'Medinova Medical Services',
    'PADMA DIAGNOSTIC': 'Padma Diagnostic Centre',
    'CHEVRON': 'Chevron Clinical Laboratory',
    'EPIC HEALTH': 'Epic Health Care',
    'ASGAR ALI': 'Asgar Ali Hospital',
    'BRB HOSPITAL': 'BRB Hospitals',
    'IMPERIAL HOSPITAL': 'Apollo Imperial Hospital',
    'KURMITOLA': 'Kurmitola General Hospital',
    'SUHRAWARDY': 'Shaheed Suhrawardy Medical College',
    'SALIMULLAH': 'Sir Salimullah Medical College (Mitford)',
    'MITFORD': 'Sir Salimullah Medical College (Mitford)',
    'CHITTAGONG MEDICAL': 'Chittagong Medical College Hospital (CMCH)',
    'CMCH': 'Chittagong Medical College Hospital (CMCH)',
    'RAJSHAHI MEDICAL': 'Rajshahi Medical College Hospital (RMCH)',
    'RMCH': 'Rajshahi Medical College Hospital (RMCH)',
    'OSMANI MEDICAL': 'MAG Osmani Medical College Hospital',
    'MYMENSINGH MEDICAL': 'Mymensingh Medical College Hospital',
    'COMBINED MILITARY': 'Combined Military Hospital (CMH)',
    'CMH': 'Combined Military Hospital (CMH)',
    'NICVD': 'National Institute of Cardiovascular Diseases (NICVD)',
    'PRAAVA': 'Praava Health',
    'AALOK': 'Aalok Healthcare',
    'GREEN LIFE': 'Green Life Hospital',
    'ANWER KHAN': 'Anwer Khan Modern Medical College',
    'COMFORT DIAGNOSTIC': 'Comfort Diagnostic Centre',
  };

  /// Extracts an ABO/Rh blood group (O+, O-, A+, A-, B+, B-, AB+, AB-) from
  /// unstructured clinical report text or donor card text.
  static String? extractBloodGroupFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final upper = text.toUpperCase();

    final explicitPatterns = <RegExp, String Function(RegExpMatch)>{
      RegExp(r'\b(AB|A|B|O)\s*([\+\-])(?!\w)'): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(
        r'\b(AB|A|B|O)\s*(?:RH\s*(?:\(D\))?\s*)?(POSITIVE|POS|\+VE)\b',
      ): (m) => '${m.group(1)}+',
      RegExp(
        r'\b(AB|A|B|O)\s*(?:RH\s*(?:\(D\))?\s*)?(NEGATIVE|NEG|\-VE)\b',
      ): (m) => '${m.group(1)}-',
      RegExp(
        r'ABO(?:\s*GROUP)?\s*[:=\-]?\s*["\x27]?(AB|A|B|O)["\x27]?[\s,;./\-]+RH(?:\s*\(D\)|\s*FACTOR|\s*TYPE)?\s*[:=\-]?\s*(POSITIVE|POS|\+VE|\+|NEGATIVE|NEG|\-VE|\-)',
      ): (m) {
        final abo = m.group(1)!;
        final rhRaw = m.group(2)!;
        final isPos = rhRaw.startsWith('P') || rhRaw.startsWith('+');
        return '$abo${isPos ? '+' : '-'}';
      },
      RegExp(
        r'BLOOD\s*(?:GROUP|TYPE)\s*[:=\-]?\s*(AB|A|B|O)\s*(POSITIVE|POS|\+VE|\+|NEGATIVE|NEG|\-VE|\-)',
      ): (m) {
        final abo = m.group(1)!;
        final rhRaw = m.group(2)!;
        final isPos = rhRaw.startsWith('P') || rhRaw.startsWith('+');
        return '$abo${isPos ? '+' : '-'}';
      },
    };

    for (final entry in explicitPatterns.entries) {
      final match = entry.key.firstMatch(upper);
      if (match != null) {
        final candidate = normalizeBloodGroup(entry.value(match));
        if (candidate != null) return candidate;
      }
    }
    return null;
  }

  /// Multi-factor zero-cost on-device clinical analyzer for lab reports and donor cards.
  static ZeroCostVerificationAnalysis analyzeClinicalVerificationReport({
    required String rawText,
    String? profileBloodGroup,
    String? donorName,
    String? manualLabName,
    String? manualCertId,
  }) {
    final cleanText = rawText.trim();
    final upper = cleanText.toUpperCase();
    final normalizedProfileBg = normalizeBloodGroup(profileBloodGroup);

    // 1. Extract Blood Group
    final extractedBg = extractBloodGroupFromText(cleanText);
    final bool hasBgConflict = extractedBg != null &&
        normalizedProfileBg != null &&
        extractedBg != normalizedProfileBg;
    final bool bgMatchesProfile = extractedBg != null &&
        normalizedProfileBg != null &&
        extractedBg == normalizedProfileBg;

    // 2. Detect Accredited Lab / Hospital / Blood Bank
    String? recognizedLab;
    for (final entry in _labKeywordMatchers.entries) {
      if (upper.contains(entry.key)) {
        recognizedLab = entry.value;
        break;
      }
    }
    if (recognizedLab == null &&
        manualLabName != null &&
        manualLabName.trim().isNotEmpty) {
      final manualUpper = manualLabName.trim().toUpperCase();
      for (final entry in _labKeywordMatchers.entries) {
        if (manualUpper.contains(entry.key)) {
          recognizedLab = entry.value;
          break;
        }
      }
    }

    // 3. Extract Lab Report / Sample / Certificate / Registration ID
    String? extractedCertId;
    final certPatterns = [
      RegExp(
        r'(?:REPORT|SAMPLE|LAB|INVOICE|REG(?:ISTRATION)?|CERTIFICATE|CERT|DONOR|BILL|RECEIPT|MRN|HN|UHID|ID)\s*(?:NO|NUMBER|ID|#)?\s*[:\-=]\s*([A-Z0-9][A-Z0-9\-/]{3,18})',
      ),
      RegExp(r'\b((?:LAB|RPT|SMP|INV|DNR|BDC|BDRCS|SND)[-/:]?[0-9]{4,14})\b'),
    ];
    for (final pattern in certPatterns) {
      final m = pattern.firstMatch(upper);
      if (m != null && m.group(1) != null) {
        final candidate = m.group(1)!.trim();
        if (RegExp(r'\d').hasMatch(candidate)) {
          extractedCertId = candidate;
          break;
        }
      }
    }

    // 4. Extract Hemoglobin (Hb g/dL) if present
    double? extractedHb;
    final hbMatch = RegExp(
      r'(?:HEMOGLOBIN|HAEMOGLOBIN|\bHB\b|\bHGB\b)\s*[:\-=]?\s*(\d{1,2}(?:\.\d{1,2})?)\s*(?:G/DL|GM/DL|G%)?',
    ).firstMatch(upper);
    if (hbMatch != null && hbMatch.group(1) != null) {
      final parsed = double.tryParse(hbMatch.group(1)!);
      if (parsed != null && parsed >= 6.0 && parsed <= 22.0) {
        extractedHb = parsed;
      }
    }

    // 5. Detect Infectious Disease Screening Markers (TTI Panel)
    final List<String> screeningMarkers = [];
    if (upper.contains('HBSAG') || upper.contains('HEPATITIS B')) {
      screeningMarkers.add('HBsAg');
    }
    if (upper.contains('HCV') || upper.contains('HEPATITIS C')) {
      screeningMarkers.add('HCV');
    }
    if (upper.contains('HIV')) {
      screeningMarkers.add('HIV');
    }
    if (upper.contains('VDRL') ||
        upper.contains('TPHA') ||
        upper.contains('SYPHILIS')) {
      screeningMarkers.add('VDRL');
    }
    if (upper.contains('MALARIA') || upper.contains('MP ')) {
      screeningMarkers.add('Malaria');
    }

    // 6. Detect Clinical Pathology / Immunohematology terminology
    final List<String> clinicalTerms = [];
    const termsToCheck = [
      'PATHOLOGY',
      'HEMATOLOGY',
      'HAEMATOLOGY',
      'IMMUNOHEMATOLOGY',
      'BLOOD BANK',
      'TRANSFUSION',
      'AGGLUTINATION',
      'ANTI-D',
      'CROSS MATCH',
      'SPECIMEN',
      'TECHNOLOGIST',
      'PATHOLOGIST',
      'DIAGNOSTIC',
      'DONOR CARD',
    ];
    for (final term in termsToCheck) {
      if (upper.contains(term)) {
        clinicalTerms.add(term);
      }
    }

    // 7. Donor Name Cross-Check
    bool nameMatched = false;
    if (donorName != null && donorName.trim().length >= 3) {
      final tokens = donorName
          .toUpperCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 3)
          .toList();
      for (final token in tokens) {
        if (upper.contains(token)) {
          nameMatched = true;
          break;
        }
      }
    }

    // 8. Calculate Zero-Cost Verification Confidence Score (0 - 100)
    int score = 0;
    if (extractedBg != null) {
      score += 35;
      if (bgMatchesProfile) {
        score += 20;
      } else if (normalizedProfileBg == null) {
        score += 10; // Profile blood group unset; can be synced from report
      } else if (hasBgConflict) {
        score -= 25; // Mismatch penalty
      }
    }

    final effectiveLab = recognizedLab ??
        ((manualLabName != null && manualLabName.trim().isNotEmpty)
            ? manualLabName.trim()
            : null);
    if (recognizedLab != null) {
      score += 20;
    } else if (effectiveLab != null) {
      score += 10;
    }

    final effectiveCertId = extractedCertId ??
        ((manualCertId != null && manualCertId.trim().isNotEmpty)
            ? manualCertId.trim()
            : null);
    if (extractedCertId != null) {
      score += 15;
    } else if (effectiveCertId != null) {
      score += 8;
    }

    if (clinicalTerms.isNotEmpty) {
      score += (clinicalTerms.length * 4).clamp(4, 12);
    }
    if (screeningMarkers.isNotEmpty) {
      score += 6;
    }
    if (extractedHb != null && extractedHb >= 12.5) {
      score += 5;
    }
    if (nameMatched) {
      score += 5;
    }

    final clampedScore = score.clamp(0, 100);
    String tier;
    if (hasBgConflict) {
      tier = 'MISMATCH_ALERT';
    } else if (clampedScore >= 78) {
      tier = 'HIGH_TRUST';
    } else if (clampedScore >= 50) {
      tier = 'MODERATE_TRUST';
    } else {
      tier = 'LOW_TRUST';
    }

    return ZeroCostVerificationAnalysis(
      extractedBloodGroup: extractedBg,
      profileBloodGroup: normalizedProfileBg,
      matchesProfileBloodGroup: bgMatchesProfile,
      hasBloodGroupConflict: hasBgConflict,
      recognizedLabName: recognizedLab,
      effectiveLabName: effectiveLab,
      extractedCertificateId: extractedCertId,
      effectiveCertificateId: effectiveCertId,
      extractedHemoglobin: extractedHb,
      detectedScreeningMarkers: screeningMarkers,
      clinicalKeywordsFound: clinicalTerms,
      donorNameMatched: nameMatched,
      confidenceScore: clampedScore,
      confidenceTier: tier,
    );
  }
}

class ZeroCostVerificationAnalysis {
  final String? extractedBloodGroup;
  final String? profileBloodGroup;
  final bool matchesProfileBloodGroup;
  final bool hasBloodGroupConflict;
  final String? recognizedLabName;
  final String? effectiveLabName;
  final String? extractedCertificateId;
  final String? effectiveCertificateId;
  final double? extractedHemoglobin;
  final List<String> detectedScreeningMarkers;
  final List<String> clinicalKeywordsFound;
  final bool donorNameMatched;
  final int confidenceScore;
  final String confidenceTier;

  const ZeroCostVerificationAnalysis({
    this.extractedBloodGroup,
    this.profileBloodGroup,
    required this.matchesProfileBloodGroup,
    required this.hasBloodGroupConflict,
    this.recognizedLabName,
    this.effectiveLabName,
    this.extractedCertificateId,
    this.effectiveCertificateId,
    this.extractedHemoglobin,
    required this.detectedScreeningMarkers,
    required this.clinicalKeywordsFound,
    required this.donorNameMatched,
    required this.confidenceScore,
    required this.confidenceTier,
  });

  String get tierLabel {
    switch (confidenceTier) {
      case 'HIGH_TRUST':
        return 'High Clinical Trust (Fast-Track Eligible)';
      case 'MODERATE_TRUST':
        return 'Moderate Clinical Confidence';
      case 'MISMATCH_ALERT':
        return 'Blood Group Mismatch Detected';
      default:
        return 'Manual Staff Review Recommended';
    }
  }

  /// Serializes structured metadata into `verification_notes` so App & Web
  /// Admin/Staff consoles can render rich zero-cost verification badges.
  String toStructuredSummaryTag() {
    final bg = extractedBloodGroup ?? 'NONE';
    final match = hasBloodGroupConflict
        ? 'CONFLICT'
        : (matchesProfileBloodGroup ? 'YES' : 'UNSET');
    final lab = (effectiveLabName ?? 'UNSPECIFIED').replaceAll('|', '/');
    final cert = (effectiveCertificateId ?? 'NONE').replaceAll('|', '/');
    final hb = extractedHemoglobin != null
        ? '${extractedHemoglobin!.toStringAsFixed(1)}g/dL'
        : 'NA';
    final screen = detectedScreeningMarkers.isEmpty
        ? 'NONE'
        : detectedScreeningMarkers.join(',');
    return '[ZCV-SCORE:$confidenceScore%|TIER:$confidenceTier|BG:$bg|MATCH:$match|LAB:$lab|CERT:$cert|HB:$hb|SCREEN:$screen]';
  }
}

