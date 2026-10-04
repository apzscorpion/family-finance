import 'package:flutter/services.dart';

/// Service that bridges Android NotificationListenerService to Flutter
/// for automatic bank transaction detection from notifications.
class NotificationParserService {
  static const _methodChannel = MethodChannel('com.familyfinance/notifications');
  static const _eventChannel = EventChannel('com.familyfinance/transaction_stream');

  /// Check if notification listener access is granted
  static Future<bool> isNotificationAccessGranted() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isNotificationAccessGranted');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open Android notification listener settings for user to grant access
  static Future<void> openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      // Silently fail if settings can't be opened
    }
  }

  /// Stream of detected bank transactions from notifications
  static Stream<Map<String, dynamic>> get transactionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }

  /// Categorize a transaction based on merchant/UPI reference keywords
  static String suggestCategory(String snippet) {
    final lower = snippet.toLowerCase();

    if (lower.contains('swiggy') || lower.contains('zomato') ||
        lower.contains('food') || lower.contains('restaurant') ||
        lower.contains('cafe') || lower.contains('dominos') ||
        lower.contains('mcdonald') || lower.contains('kfc')) {
      return 'dining';
    }
    if (lower.contains('uber') || lower.contains('ola') ||
        lower.contains('rapido') || lower.contains('metro') ||
        lower.contains('irctc') || lower.contains('railway')) {
      return 'transport';
    }
    if (lower.contains('petrol') || lower.contains('fuel') ||
        lower.contains('iocl') || lower.contains('bpcl') ||
        lower.contains('hpcl') || lower.contains('shell')) {
      return 'fuel';
    }
    if (lower.contains('amazon') || lower.contains('flipkart') ||
        lower.contains('myntra') || lower.contains('ajio') ||
        lower.contains('meesho') || lower.contains('shopping')) {
      return 'shopping';
    }
    if (lower.contains('electricity') || lower.contains('water') ||
        lower.contains('gas') || lower.contains('broadband') ||
        lower.contains('jio') || lower.contains('airtel') ||
        lower.contains('vi ') || lower.contains('bsnl') ||
        lower.contains('recharge') || lower.contains('bill')) {
      return 'bills';
    }
    if (lower.contains('hospital') || lower.contains('pharmacy') ||
        lower.contains('medical') || lower.contains('apollo') ||
        lower.contains('doctor') || lower.contains('clinic') ||
        lower.contains('medplus') || lower.contains('netmeds')) {
      return 'health';
    }
    if (lower.contains('grocer') || lower.contains('bigbasket') ||
        lower.contains('blinkit') || lower.contains('dmart') ||
        lower.contains('reliance fresh') || lower.contains('zepto') ||
        lower.contains('instamart') || lower.contains('supermarket')) {
      return 'groceries';
    }
    if (lower.contains('salary') || lower.contains('payroll') ||
        lower.contains('stipend')) {
      return 'salary';
    }
    if (lower.contains('refund') || lower.contains('cashback')) {
      return 'refund';
    }

    return 'shopping';
  }

  /// Extract merchant name from notification snippet
  static String extractMerchant(String snippet) {
    final lower = snippet.toLowerCase();

    final upiMatch = RegExp(r'(?:to|at|upi[:/])\s*([\w.@]+)', caseSensitive: false).firstMatch(snippet);
    if (upiMatch != null) {
      final merchant = upiMatch.group(1) ?? '';
      if (merchant.length > 2 && merchant.length < 40) {
        return merchant
            .replaceAll(RegExp(r'@.*'), '')
            .split('.')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ')
            .trim();
      }
    }

    final merchants = {
      'swiggy': 'Swiggy', 'zomato': 'Zomato', 'amazon': 'Amazon',
      'flipkart': 'Flipkart', 'uber': 'Uber', 'ola': 'Ola',
      'rapido': 'Rapido', 'bigbasket': 'BigBasket', 'blinkit': 'Blinkit',
      'zepto': 'Zepto', 'myntra': 'Myntra', 'ajio': 'AJIO',
      'dominos': 'Dominos', 'mcdonald': 'McDonald\'s', 'kfc': 'KFC',
      'reliance': 'Reliance', 'dmart': 'DMart', 'jio': 'Jio',
      'airtel': 'Airtel', 'phonepe': 'PhonePe', 'paytm': 'Paytm',
    };

    for (final entry in merchants.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    return 'Transaction';
  }
}
