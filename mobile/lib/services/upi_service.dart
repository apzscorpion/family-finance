import 'package:url_launcher/url_launcher.dart';

import 'app_log.dart';

/// Helper for standard NPCI UPI Intent linking.
/// Creates `upi://pay` URLs and hands them to the operating system's registered
/// payment applications (Google Pay, PhonePe, Paytm, BHIM, CRED, Navi, etc.).
class UpiService {
  UpiService._();

  /// Builds a standard NPCI UPI URI string.
  static Uri buildUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) {
    final cleanUpi = upiId.trim();
    final cleanName = payeeName.trim();
    final cleanNote = (note == null || note.trim().isEmpty)
        ? 'KinPurse Settlement'
        : note.trim();
    // Round to 2 decimal places as required by NPCI standard
    final formattedAmount = amount.toStringAsFixed(2);

    final params = <String, String>{
      'pa': cleanUpi,
      'pn': cleanName,
      'am': formattedAmount,
      'cu': 'INR',
      'tn': cleanNote,
    };

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: params,
    );
  }

  /// Attempts to launch the system UPI application chooser.
  /// Returns `true` if launched successfully, `false` otherwise.
  static Future<bool> openUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) async {
    final uri = buildUri(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        AppLog.error('UpiService', 'Failed to launch UPI URI: $uri');
      }
      return launched;
    } catch (e, stack) {
      AppLog.error('UpiService.openUpiPayment', e, stack);
      return false;
    }
  }
}

