import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance/v3/sheets/calc_engine.dart';

void main() {
  group('CalcEngine', () {
    test('handles simple numbers', () {
      expect(CalcEngine.evaluate(''), 0.0);
      expect(CalcEngine.evaluate('0'), 0.0);
      expect(CalcEngine.evaluate('250'), 250.0);
      expect(CalcEngine.evaluate('12.5'), 12.5);
    });

    test('handles addition and subtraction', () {
      expect(CalcEngine.evaluate('250 + 120'), 370.0);
      expect(CalcEngine.evaluate('500 - 150'), 350.0);
      expect(CalcEngine.evaluate('100 + 50 - 25'), 125.0);
    });

    test('handles multiplication and division with precedence', () {
      expect(CalcEngine.evaluate('10 * 5'), 50.0);
      expect(CalcEngine.evaluate('100 / 4'), 25.0);
      expect(CalcEngine.evaluate('10 + 5 * 2'), 20.0); // 5*2=10, 10+10=20
      expect(CalcEngine.evaluate('50 - 20 / 2'), 40.0); // 20/2=10, 50-10=40
    });

    test('handles unicode operators × and ÷', () {
      expect(CalcEngine.evaluate('15 × 4'), 60.0);
      expect(CalcEngine.evaluate('100 ÷ 5'), 20.0);
    });

    test('handles incomplete expressions gracefully', () {
      expect(CalcEngine.evaluate('250 +'), 250.0);
      expect(CalcEngine.evaluate('500 -'), 500.0);
      expect(CalcEngine.evaluate('100 *'), 100.0);
      expect(CalcEngine.evaluate('50.'), 50.0);
    });

    test('handles division by zero safely', () {
      expect(CalcEngine.evaluate('100 / 0'), 0.0);
    });

    test('format produces clean currency strings', () {
      expect(CalcEngine.format(250.0), '250');
      expect(CalcEngine.format(12.5), '12.5');
      expect(CalcEngine.format(99.99), '99.99');
      expect(CalcEngine.format(0.0), '0');
    });

    test('detects operators correctly', () {
      expect(CalcEngine.hasOperator('250'), isFalse);
      expect(CalcEngine.hasOperator('-50'), isFalse);
      expect(CalcEngine.hasOperator('250 + 50'), isTrue);
      expect(CalcEngine.hasOperator('100 - 20'), isTrue);
      expect(CalcEngine.hasOperator('10 × 2'), isTrue);
    });
  });
}
