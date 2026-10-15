import '../v3/data/v3_models.dart';

/// Result of evaluating a message or transaction through Guardian Mode heuristics.
class GuardianRiskAssessment {
  final bool isSuspicious;
  final String riskLevel; // 'none', 'warning', 'critical'
  final String? scamType; // 'power_disconnection', 'kyc_suspension', 'remote_tool', 'lottery_gift', 'unusual_debit'
  final String? title;
  final String? reason;
  final String? safetyAdvice;

  const GuardianRiskAssessment({
    required this.isSuspicious,
    this.riskLevel = 'none',
    this.scamType,
    this.title,
    this.reason,
    this.safetyAdvice,
  });

  static const safe = GuardianRiskAssessment(isSuspicious: false);
}

/// On-device scam, phishing, and fraudulent debit protection service for elderly & family members.
class GuardianService {
  GuardianService._();

  // ──────────────────────────────────────────────────────────────────────────
  // HEURISTIC SCAM PATTERNS (Indian UPI & Banking specific)
  // ──────────────────────────────────────────────────────────────────────────

  // 1. Electricity / Power cut fraud
  static final _powerCutRegex = RegExp(
    r'(power|electricity|bijli)\s*(will be|bill)\s*(disconnected|cut|suspended|updated|due tonight|tonight at)',
    caseSensitive: false,
  );

  // 2. Bank / KYC / PAN suspension fraud
  static final _kycRegex = RegExp(
    r'(kyc|pan card|aadhaar|account|yono|netbanking|sim)\s*(has been|is)?\s*(suspended|blocked|deactivated|expire|expired|update immediately|verify now)',
    caseSensitive: false,
  );

  // 3. Remote access malware/screen-sharing tools
  static final _remoteAccessRegex = RegExp(
    r'(anydesk|rustdesk|teamviewer|quicksupport|screen share|airdroid)',
    caseSensitive: false,
  );

  // 4. Fake Lottery / Cashback / Scratch card claim
  static final _lotteryRegex = RegExp(
    r'(congratulations|won|claimed?)\s*(₹|rs\.?|inr)?\s*([0-9,]+)?\s*(cashback|lottery|prize|gift card|bonus)\s*(click|claim|link)',
    caseSensitive: false,
  );

  // 5. Malicious APK download links
  static final _apkRegex = RegExp(
    r'(download|install)\s*(app|apk|file)?.*(\.apk|bit\.ly|tinyurl|is\.gd|cutt\.ly)',
    caseSensitive: false,
  );

  /// Evaluates SMS, notification, or clipboard text for known fraudulent patterns.
  static GuardianRiskAssessment analyzeText(String text) {
    if (text.trim().isEmpty) return GuardianRiskAssessment.safe;

    // Check remote access tools (Highest criticality)
    if (_remoteAccessRegex.hasMatch(text)) {
      return const GuardianRiskAssessment(
        isSuspicious: true,
        riskLevel: 'critical',
        scamType: 'remote_tool',
        title: 'Critical: Screen-Sharing App Request Detected',
        reason: 'This message asks to install AnyDesk, RustDesk, or TeamViewer. Scammers use this to view OTPs and control bank accounts.',
        safetyAdvice: 'NEVER install these apps on advice of strangers or callers claiming to be bank executives.',
      );
    }

    // Check electricity disconnection scam
    if (_powerCutRegex.hasMatch(text)) {
      return const GuardianRiskAssessment(
        isSuspicious: true,
        riskLevel: 'critical',
        scamType: 'power_disconnection',
        title: 'Alert: Electricity Disconnection Scam',
        reason: 'Power utility companies NEVER send SMS threatening to disconnect electricity tonight with a personal phone number.',
        safetyAdvice: 'Do not call the number in the SMS. Pay only via official electricity board websites or consumer portals.',
      );
    }

    // Check KYC / PAN blocked scam
    if (_kycRegex.hasMatch(text)) {
      return const GuardianRiskAssessment(
        isSuspicious: true,
        riskLevel: 'critical',
        scamType: 'kyc_suspension',
        title: 'Alert: Fake Bank KYC / PAN Suspension',
        reason: 'Banks NEVER ask you to click links or download files to update KYC or unblock YONO/Netbanking.',
        safetyAdvice: 'Visit your official bank branch or use official netbanking. Never tap unknown SMS links.',
      );
    }

    // Check malicious APK
    if (_apkRegex.hasMatch(text)) {
      return const GuardianRiskAssessment(
        isSuspicious: true,
        riskLevel: 'critical',
        scamType: 'apk_risk',
        title: 'Warning: Unverified APK Download Link',
        reason: 'Message contains an APK or shortened link. Sideloading apps can secretly forward your SMS OTPs to fraudsters.',
        safetyAdvice: 'Install apps exclusively from Google Play Store. Never download APK files sent via WhatsApp or SMS.',
      );
    }

    // Check Lottery / Cashback claim
    if (_lotteryRegex.hasMatch(text)) {
      return const GuardianRiskAssessment(
        isSuspicious: true,
        riskLevel: 'warning',
        scamType: 'lottery_gift',
        title: 'Warning: Fake Lottery / Cashback Trap',
        reason: 'Receiving money NEVER requires entering your UPI PIN or scanning a QR code.',
        safetyAdvice: 'Remember: UPI PIN is ONLY entered to SEND money, never to receive money or cashback.',
      );
    }

    return GuardianRiskAssessment.safe;
  }

  /// Inspects a transaction made by a protected member (parent).
  static GuardianRiskAssessment analyzeTransaction({
    required double amount,
    required String? payeeOrMerchant,
    required MemberRow member,
    required List<TxnRow> familyHistory,
  }) {
    if (!member.isProtectedMember) return GuardianRiskAssessment.safe;

    // Abnormal debit on protected account (e.g. ₹3,500+)
    const unusualThreshold = 3000.0;
    if (amount >= unusualThreshold) {
      final cleanPayee = (payeeOrMerchant ?? 'Unknown Payee').trim();
      final hasPreviousHistory = familyHistory.any((t) =>
          t.title.toLowerCase().contains(cleanPayee.toLowerCase()) && t.occurredAt.isBefore(DateTime.now().subtract(const Duration(days: 7))));

      if (!hasPreviousHistory) {
        return GuardianRiskAssessment(
          isSuspicious: true,
          riskLevel: 'critical',
          scamType: 'unusual_debit',
          title: 'Guardian Alert: Large Debit to Unfamiliar Payee',
          reason: '${member.name} made an unusual debit of ₹${amount.toStringAsFixed(0)} to "$cleanPayee", who has no prior payment history.',
          safetyAdvice: 'Check in with ${member.name} to confirm this was an intentional purchase and not made under pressure or deceit.',
        );
      }
    }

    return GuardianRiskAssessment.safe;
  }
}
