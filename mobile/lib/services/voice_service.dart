import 'package:flutter/services.dart';

/// Service interfacing with native Android speech recognition.
/// Falls back safely when running on unsupported platforms or when speech is cancelled.
class VoiceService {
  VoiceService._();

  static const MethodChannel _channel = MethodChannel('com.familyfinance/voice');

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

