/// A lightweight, safe calculator engine for expense tracking.
/// Supports standard arithmetic: +, -, *, / (or ×, ÷), floating point numbers,
/// and live expression evaluation.
class CalcEngine {
  CalcEngine._();

  /// Evaluates an arithmetic expression string like "250 + 120" or "500 - 50 * 2".
  /// Returns 0.0 if empty or invalid. Handles incomplete expressions gracefully
  /// (e.g. "250 +" evaluates to 250.0).
  static double evaluate(String input) {
    if (input.trim().isEmpty) return 0.0;

    // Normalize characters: replace unicode multiplication and division
    var sanitized = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(' ', '')
        .trim();

    // Strip trailing operators (e.g. "250+" -> "250")
    while (sanitized.isNotEmpty &&
        (sanitized.endsWith('+') ||
            sanitized.endsWith('-') ||
            sanitized.endsWith('*') ||
            sanitized.endsWith('/') ||
            sanitized.endsWith('.'))) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    if (sanitized.isEmpty) return 0.0;

    try {
      final tokens = _tokenize(sanitized);
      if (tokens.isEmpty) return 0.0;
      return _evaluateTokens(tokens);
    } catch (_) {
      // Fallback: try parsing as a plain double
      return double.tryParse(sanitized) ?? 0.0;
    }
  }

  /// Formats a number cleanly: e.g. 250.0 -> "250", 250.5 -> "250.50" or "250.5".
  static String format(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Up to 2 decimal places, trimming trailing zeros
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  /// Checks if the expression contains any active operator.
  static bool hasOperator(String input) {
    final s = input.trim();
    // Ignore leading minus for negative numbers
    final rest = s.startsWith('-') ? s.substring(1) : s;
    return rest.contains('+') ||
        rest.contains('-') ||
        rest.contains('*') ||
        rest.contains('/') ||
        rest.contains('×') ||
        rest.contains('÷');
  }

  static List<String> _tokenize(String s) {
    final tokens = <String>[];
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '+' || ch == '*' || ch == '/') {
        tokens.add(ch);
        i++;
      } else if (ch == '-') {
        // Unary minus if at start or immediately following an operator
        if (tokens.isEmpty || ['+', '-', '*', '/'].contains(tokens.last)) {
          // Read number with negative sign
          var numStr = '-';
          i++;
          while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
            numStr += s[i];
            i++;
          }
          tokens.add(numStr);
        } else {
          tokens.add('-');
          i++;
        }
      } else if (_isDigit(ch) || ch == '.') {
        var numStr = '';
        while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
          numStr += s[i];
          i++;
        }
        tokens.add(numStr);
      } else {
        i++;
      }
    }
    return tokens;
  }

  static bool _isDigit(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static double _evaluateTokens(List<String> tokens) {
    if (tokens.isEmpty) return 0.0;

    // First pass: perform multiplication and division (*, /)
    final pass1 = <String>[];
    var i = 0;
    while (i < tokens.length) {
      final t = tokens[i];
      if (t == '*' || t == '/') {
        if (pass1.isEmpty || i + 1 >= tokens.length) break;
        final left = double.tryParse(pass1.removeLast()) ?? 0.0;
        final right = double.tryParse(tokens[i + 1]) ?? 0.0;
        final res = t == '*' ? left * right : (right != 0 ? left / right : 0.0);
        pass1.add(res.toString());
        i += 2;
      } else {
        pass1.add(t);
        i++;
      }
    }

    // Second pass: perform addition and subtraction (+, -)
    if (pass1.isEmpty) return 0.0;
    var result = double.tryParse(pass1[0]) ?? 0.0;
    var j = 1;
    while (j < pass1.length) {
      final op = pass1[j];
      if (j + 1 < pass1.length) {
        final next = double.tryParse(pass1[j + 1]) ?? 0.0;
        if (op == '+') {
          result += next;
        } else if (op == '-') {
          result -= next;
        }
        j += 2;
      } else {
        break;
      }
    }

    return result;
  }
}
