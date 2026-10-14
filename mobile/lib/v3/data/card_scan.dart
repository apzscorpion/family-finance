import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// What a card photo yielded. Only [last4] is ever saved; the full number is
/// dropped with the photo.
typedef CardScan = ({String? last4, String? expiry});

/// Opens the camera, reads the front of a card on-device, then deletes the
/// photo. Returns null if the user cancels. The CVV (on the back) is never
/// looked for.
Future<CardScan?> scanCard() async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
  );
  if (shot == null) return null;
  // The photo shows the full card number; don't leave it in the cache.
  return parseCardText(await readImageText(shot.path, deleteAfter: true));
}

/// On-device OCR of the image at [path].
Future<String> readImageText(String path, {bool deleteAfter = false}) async =>
    (await _recognize(path, deleteAfter)).text;

/// A line of OCR text and where it sits: the height tells the big headline
/// amount from small print, the position what is under a label (OCR returns
/// blocks, not top-to-bottom order).
typedef OcrLine = ({String text, double height, double top, double left});

/// OCR lines, block by block. Used for shared payment screenshots.
Future<List<OcrLine>> readImageLines(
  String path, {
  void Function()? onWaiting,
}) async => [
  for (final block in (await _recognize(path, false, onWaiting)).blocks)
    for (final line in block.lines)
      (
        text: line.text,
        height: line.boundingBox.height,
        top: line.boundingBox.top,
        left: line.boundingBox.left,
      ),
];

/// One reader for the app's lifetime: loading the engine is most of the
/// cost of a read (seconds cold, well under one warm).
final _reader = TextRecognizer(script: TextRecognitionScript.latin);

/// Loads the reader in the background at launch, so a receipt shared later
/// reads in a fraction of a second. Failures are ignored.
Future<void> warmUpTextReader() async {
  try {
    final f = File('${(await getTemporaryDirectory()).path}/ocr_warmup.png');
    await f.writeAsBytes(base64Decode(_blankPng));
    await _reader.processImage(InputImage.fromFilePath(f.path));
  } catch (_) {}
}

// A 64×64 white PNG; ML Kit rejects images under 32 px.
const _blankPng =
    'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAAAAACPAi4CAAAAK0lEQVR42u3MMREAAAgE'
    'oNf+nTWEmwcBqMlNRyAQCAQCgUAgEAgEAsHzYAFQLQF/OJ8+2wAAAABJRU5ErkJggg==';

Future<RecognizedText> _recognize(
  String path,
  bool deleteAfter, [
  void Function()? onWaiting,
]) async {
  final reader = _reader;
  try {
    // The Play Services reader throws "Waiting for the text optional module
    // to be downloaded" until its model arrives (first use after an APK
    // install). Retry for up to a minute instead of failing that first read.
    for (var attempt = 0; ; attempt++) {
      try {
        return await reader.processImage(InputImage.fromFilePath(path));
      } catch (e) {
        if (!'$e'.toLowerCase().contains('download') || attempt >= 20) rethrow;
        if (attempt == 0) onWaiting?.call();
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  } finally {
    if (deleteAfter) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}

/// Finds a Luhn-valid 13–19 digit number and the latest MM/YY date (cards
/// with "valid from" and "valid thru" show two; thru is the later one).
CardScan parseCardText(String text) {
  String? last4;
  for (final m in RegExp(r'\d[\d \-]{11,24}\d').allMatches(text)) {
    final d = m[0]!.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 13 && d.length <= 19 && _luhn(d)) {
      last4 = d.substring(d.length - 4);
      break;
    }
  }

  String? expiry;
  var best = -1;
  for (final m in RegExp(
    r'(?<!\d)(0[1-9]|1[0-2]) ?/ ?(\d{4}|\d{2})(?!\d)',
  ).allMatches(text)) {
    final yy = int.parse(m[2]!) % 100;
    final rank = yy * 100 + int.parse(m[1]!);
    if (rank > best) {
      best = rank;
      expiry = '${m[1]}/${yy.toString().padLeft(2, '0')}';
    }
  }
  return (last4: last4, expiry: expiry);
}

bool _luhn(String digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var n = int.parse(digits[digits.length - 1 - i]);
    if (i.isOdd) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 == 0;
}
