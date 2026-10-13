import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../services/app_log.dart';
import 'card_scan.dart';

/// What a payment screenshot (GPay, PhonePe, CRED, supermoney…) yielded.
/// Every field is a guess for the user to confirm in the add sheet.
/// [income] is true for "received from" screens.
typedef BillScan = ({
  double? amount,
  String? payee,
  DateTime? date,
  bool income,
});

const _channel = MethodChannel('com.familyfinance/file_import');

/// Reads an image shared into the app (Android "Share → Sampio"), if one
/// arrived since the last call. The cached copy is deleted after reading.
/// [onWaiting] fires if the text reader is still being downloaded.
Future<BillScan?> consumeSharedBill({VoidCallback? onWaiting}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  String? path;
  try {
    path = await _channel.invokeMethod<String>('consumeSharedImage');
    if (path == null) return null;
    return parseBill(await readImageLines(path, onWaiting: onWaiting));
  } on MissingPluginException {
    return null; // tests / hosts without the channel
  } catch (e, st) {
    AppLog.error('consumeSharedBill', e, st);
    // Still open the sheet: the user shared a bill and expects to add it.
    return (amount: null, payee: null, date: null, income: false);
  } finally {
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}


/// Plain-text form, every line the same height.
BillScan parseBillText(String text, {DateTime? now}) => parseBill([
  for (final l in text.split('\n')) (text: l, height: 10.0),
], now: now);

BillScan parseBill(List<OcrLine> raw, {DateTime? now}) {
  final lines = [
    for (final l in raw)
      if (l.text.trim().isNotEmpty) (text: l.text.trim(), height: l.height),
  ];
  final texts = [for (final l in lines) l.text];
  final income = texts.any(
    (t) => RegExp(
      r'\b(received from|money received|credited to your|you received)\b',
      caseSensitive: false,
    ).hasMatch(t),
  );
  return (
    amount: _amount(lines),
    payee: _payee(texts, income),
    date: _date(texts, now ?? DateTime.now()),
    income: income,
  );
}

double? _amount(List<OcrLine> lines) {
  final money = RegExp(
    r'(?:₹|rs\.?|inr)\s*(\d[\d,]*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  // OCR often misreads a bold ₹ ("T81" on supermoney, "?500", "*500") or
  // drops it, so a line that is only an amount also counts, after one stray
  // symbol or T/Z/R/F. Up to 7 digits, so the 12-digit UPI reference and
  // phone numbers never match.
  final bare = RegExp(
    r'^(?:[^\w\s]|[TZRF])?\s*(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)$',
  );
  final found = <({double value, double height, bool rupee})>[];
  for (final l in lines) {
    final m = money.firstMatch(l.text);
    final b = m == null ? bare.firstMatch(l.text) : null;
    final v = double.tryParse((m ?? b)?[1]?.replaceAll(',', '') ?? '');
    if (v != null && v > 0) {
      found.add((value: v, height: l.height, rupee: m != null));
    }
  }
  if (found.isEmpty) return null;
  // The paid amount is the headline: the biggest text on every UPI receipt.
  // That rules out the status-bar battery %, cashback and fee lines. Among
  // near-equal sizes, a ₹-marked one wins, then the first.
  final tallest = found.map((f) => f.height).reduce((a, b) => a > b ? a : b);
  final pool = found.where((f) => f.height >= tallest * 0.85);
  return (pool.where((f) => f.rupee).firstOrNull ?? pool.first).value;
}

String? _payee(List<String> lines, bool income) {
  final label = RegExp(
    income
        ? r'^(?:received from|from)\b[:\s]*(.*)$'
        : r'^(?:paid to|sent to|payment to|transferred to|to)\b[:\s]*(.*)$',
    caseSensitive: false,
  );
  // A name, not a UPI id, amount, phone or reference number.
  bool isName(String s) =>
      s.isNotEmpty &&
      !s.contains('@') &&
      !s.contains('₹') &&
      RegExp(r'[A-Za-z]{2}').hasMatch(s) &&
      !RegExp(r'\d{5}').hasMatch(s);

  for (var i = 0; i < lines.length; i++) {
    final m = label.firstMatch(lines[i]);
    if (m == null) continue;
    final rest = m[1]!.trim();
    final name = isName(rest)
        ? rest
        : [
            for (final l in lines.skip(i + 1).take(2))
              if (isName(l)) l,
          ].firstOrNull;
    if (name != null) return _tidy(name);
  }
  return null;
}

/// "RAHUL KUMAR" → "Rahul Kumar"; mixed case is left alone.
String _tidy(String s) => s != s.toUpperCase()
    ? s
    : s
          .toLowerCase()
          .split(' ')
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const _mon = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';
final _dmy = RegExp(
  '(?<!\\d)(\\d{1,2})(?:st|nd|rd|th)?[ -]($_mon)[a-z]*\\.?(?:,?[ -](\\d{4}))?',
  caseSensitive: false,
);
final _mdy = RegExp(
  '\\b($_mon)[a-z]*\\.? (\\d{1,2})\\b(?:,? (\\d{4}))?',
  caseSensitive: false,
);
final _numeric = RegExp(r'(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?!\d)');
final _time = RegExp(
  r'(?<!\d)(\d{1,2}):(\d{2})(?::\d{2})?\s*([ap])?\.?\s*m?\b',
  caseSensitive: false,
);

/// The payment date, with the time only if it sits on the same or the next
/// line: the first time in a screenshot is usually the status-bar clock.
DateTime? _date(List<String> lines, DateTime now) {
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    int? y, mo, d;
    final a = _dmy.firstMatch(l), b = _mdy.firstMatch(l);
    final c = _numeric.firstMatch(l);
    if (a != null) {
      (d, mo, y) = (int.parse(a[1]!), _months[a[2]!.toLowerCase()], _year(a[3]));
    } else if (b != null) {
      (mo, d, y) = (_months[b[1]!.toLowerCase()], int.parse(b[2]!), _year(b[3]));
    } else if (c != null) {
      // Indian apps write day first.
      (d, mo, y) = (int.parse(c[1]!), int.parse(c[2]!), int.parse(c[3]!));
    } else {
      continue;
    }
    if (mo == null || mo > 12 || d < 1 || d > 31) continue;
    // "12 Oct, 9:52 pm" without a year: this year, unless that's ahead.
    final year = y ?? (DateTime(now.year, mo, d).isAfter(now) ? now.year - 1 : now.year);

    var h = 0, min = 0;
    final t = _time.firstMatch(l) ??
        (i + 1 < lines.length ? _time.firstMatch(lines[i + 1]) : null);
    if (t != null && int.parse(t[1]!) < 24 && int.parse(t[2]!) < 60) {
      h = int.parse(t[1]!);
      min = int.parse(t[2]!);
      final ampm = t[3]?.toLowerCase();
      if (ampm == 'p' && h < 12) h += 12;
      if (ampm == 'a' && h == 12) h = 0;
    }
    final at = DateTime(year, mo, d, h, min);
    if (at.day != d) continue; // 31 Feb rolled into March
    if (at.isAfter(now.add(const Duration(days: 1)))) continue;
    return at;
  }
  return null;
}

int? _year(String? s) => s == null ? null : int.parse(s);
