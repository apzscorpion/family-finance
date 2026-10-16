import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service interfacing with native Android speech recognition.
/// Falls back safely when running on unsupported platforms or when speech is cancelled.
class VoiceService {
  VoiceService._();

  static const MethodChannel _channel = MethodChannel('com.familyfinance/voice');

  /// What has been heard so far in the current turn, live.
  static final partial = ValueNotifier<String>('');

  /// Loudness of the voice right now, 0..1, for the level meter.
  static final level = ValueNotifier<double>(0);

  static bool _wired = false;

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'partial':
          partial.value = '${call.arguments}';
        case 'level':
          // Android reports about -2..10 dB.
          final db = (call.arguments as num?)?.toDouble() ?? 0;
          level.value = ((db + 2) / 12).clamp(0.0, 1.0);
      }
    });
  }

  /// Listens inside the app (no popup), in Indian English by default, with
  /// [hints] — names the app expects — to help it catch them. Falls back to
  /// the system speech popup when in-app listening isn't possible (no
  /// microphone permission, no recognizer). Null if nothing was heard.
  static Future<String?> listen({
    String? prompt,
    List<String> hints = const [],
    String lang = 'en-IN',
    bool mixed = false,
  }) async {
    _wire();
    partial.value = '';
    level.value = 0;
    try {
      final text = await _channel.invokeMethod<String>(
          'listenInApp', {'lang': lang, 'hints': hints, 'mixed': mixed});
      level.value = 0;
      if (text == null || text.trim().isEmpty) return null;
      return text.trim();
    } on PlatformException catch (e) {
      level.value = 0;
      if (e.code == 'UNAVAILABLE' || e.code == 'NO_PERMISSION') {
        return promptVoiceInput(prompt: prompt);
      }
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Ends the current turn now, keeping what was heard.
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
  }

  /// Ends the current turn and drops it.
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancelListening');
    } catch (_) {}
  }

  /// Prompts the native Android speech dialog and returns the transcribed text.
  /// Returns null if cancelled or voice service is unavailable. [prompt] is
  /// the hint shown in the speech dialog.
  static Future<String?> promptVoiceInput({String? prompt}) async {
    try {
      final text = await _channel.invokeMethod<String>(
        'listen',
        prompt == null ? null : {'prompt': prompt},
      );
      if (text == null || text.trim().isEmpty) return null;
      return text.trim();
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }
}
