import 'package:flutter/foundation.dart';

/// Central sink for failures that used to be swallowed by bare `catch (_) {}`.
///
/// Those empty catches were the main reason problems in this app looked like
/// "the button does nothing": the failure happened, nobody saw it, and there
/// was no trace left to debug from. Anything non-fatal that we recover from
/// should still be reported here so it is visible in the console and in the
/// in-app developer support screen.
class AppLog {
  AppLog._();

  static const int _maxEntries = 200;
  static final List<AppLogEntry> _entries = <AppLogEntry>[];

  /// Most recent entries, newest last.
  static List<AppLogEntry> get entries => List.unmodifiable(_entries);

  static bool get hasEntries => _entries.isNotEmpty;

  /// Records a recovered failure. [context] should name the operation that
  /// failed, e.g. `'SupabaseService.signOut'`.
  static void error(String context, Object error, [StackTrace? stack]) {
    final entry = AppLogEntry(
      context: context,
      message: error.toString(),
      time: DateTime.now(),
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    debugPrint('FF-ERROR $context: $error');
    if (stack != null && kDebugMode) debugPrint(stack.toString());
  }

  static void clear() => _entries.clear();

  /// Plain-text dump, for attaching to a bug report.
  static String dump() => _entries.map((e) => e.toString()).join('\n');
}

class AppLogEntry {
  final String context;
  final String message;
  final DateTime time;

  const AppLogEntry({
    required this.context,
    required this.message,
    required this.time,
  });

  @override
  String toString() =>
      '[${time.toIso8601String()}] $context: $message';
}
