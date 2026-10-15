import '../v3/data/v3_models.dart';

/// Recommendation for optimal credit card choice.
class CardRecommendation {
  final CreditCardRow card;
  final double cashbackRate; // e.g. 5.0%
  final double estimatedSavings; // e.g. ₹75 on ₹1,500
  final String perkReason;

  const CardRecommendation({
    required this.card,
    required this.cashbackRate,
    required this.estimatedSavings,
    required this.perkReason,
  });
}

/// Service that matches purchases to the highest-earning credit card in the family.
class CardOptimizerService {
  CardOptimizerService._();

  /// Known popular Indian cards and default preset cashback rules.
  static const List<Map<String, dynamic>> cardPresets = [
    {
      'name': 'HDFC Swiggy Card',
      'bank': 'HDFC',
      'network': 'Mastercard',
      'rules': {
        'swiggy': 10.0,
        'online': 5.0,
        'grocery': 5.0,
        'dining': 10.0,
        'general': 1.0,
      },
    },
    {
      'name': 'SBI Cashback Card',
      'bank': 'SBI',
      'network': 'Visa',
      'rules': {
        'online': 5.0,
        'amazon': 5.0,
        'flipkart': 5.0,
        'myntra': 5.0,
        'swiggy': 5.0,
        'zomato': 5.0,
        'general': 1.0,
      },
    },
    {
      'name': 'ICICI Amazon Pay',
      'bank': 'ICICI',
      'network': 'Visa',
      'rules': {
        'amazon': 5.0,
        'utilities': 2.0,
        'flights': 2.0,
        'general': 1.0,
      },
    },
    {
      'name': 'Axis Airtel Card',
      'bank': 'Axis',
      'network': 'Mastercard',
      'rules': {
        'airtel': 25.0,
        'utilities': 10.0,
        'bigbasket': 10.0,
        'swiggy': 10.0,
        'zomato': 10.0,
        'general': 1.0,
      },
    },
    {
      'name': 'Flipkart Axis Bank',
      'bank': 'Axis',
      'network': 'Visa',
      'rules': {
        'flipkart': 5.0,
        'myntra': 5.0,
        'swiggy': 4.0,
        'uber': 4.0,
        'pvr': 4.0,
        'cleartrip': 4.0,
        'general': 1.0,
      },
    },
    {
      'name': 'Tata Neu Infinity',
      'bank': 'HDFC',
      'network': 'RuPay',
      'rules': {
        'bigbasket': 10.0,
        'croma': 10.0,
        'tata': 10.0,
        '1mg': 10.0,
        'upi': 1.5,
        'general': 1.5,
      },
    },
  ];

  /// Finds the best credit card in the family for a given merchant or category spend.
  static CardRecommendation? findBestCard({
    required List<CreditCardRow> familyCards,
    required String merchantOrCategory,
    double amount = 1000.0,
  }) {
    if (familyCards.isEmpty) return null;

    final target = merchantOrCategory.toLowerCase();
    CreditCardRow? bestCard;
    double maxRate = -1.0;

    for (final card in familyCards) {
      final rate = card.cashbackFor(target);
      if (rate > maxRate) {
        maxRate = rate;
        bestCard = card;
      }
    }

    if (bestCard == null) return null;

    final savings = (amount * maxRate) / 100.0;
    final perk = '$maxRate% Cashback on ${_capitalize(merchantOrCategory)}';

    return CardRecommendation(
      card: bestCard,
      cashbackRate: maxRate,
      estimatedSavings: savings,
      perkReason: perk,
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return 'Spends';
    return s[0].toUpperCase() + s.substring(1);
  }
}

