import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../services/app_log.dart';
import 'chat_media.dart';

/// Triggers a normal browser download of a chat photo via a temporary
/// `<a download>` element.
Future<bool> saveChatImage(Uint8List bytes, String fileName) async {
  try {
    final ext = fileName.split('.').last.toLowerCase();
    final mime = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
    final doc = globalContext['document'] as JSObject;
    final a = doc.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
    a['href'] = 'data:$mime;base64,${base64Encode(bytes)}'.toJS;
    a['download'] = fileName.toJS;
    final body = doc['body'] as JSObject;
    body.callMethod('appendChild'.toJS, a);
    a.callMethod('click'.toJS);
    body.callMethod('removeChild'.toJS, a);
    return true;
  } catch (err, stack) {
    AppLog.error('saveChatImage (web)', err, stack);
    return false;
  }
}

JSObject get _doc => globalContext['document'] as JSObject;

/// Browser download straight from the signed [url]; `download=` makes
/// Storage send Content-Disposition: attachment with [name].
Future<bool> saveChatDownload(String url, String name, String mime) async {
  try {
    final a = _doc.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
    a['href'] = '$url&download=${Uri.encodeQueryComponent(name)}'.toJS;
    a['download'] = name.toJS;
    final body = _doc['body'] as JSObject;
    body.callMethod('appendChild'.toJS, a);
    a.callMethod('click'.toJS);
    body.callMethod('removeChild'.toJS, a);
    return true;
  } catch (err, stack) {
    AppLog.error('saveChatDownload (web)', err, stack);
    return false;
  }
}

/// Any file through a hidden `<input type=file>`. Null when cancelled.
Future<PickedChatFile?> pickChatFile() async {
  final input = _doc.callMethod<JSObject>('createElement'.toJS, 'input'.toJS);
  input['type'] = 'file'.toJS;
  final picked = Completer<JSObject?>();
  input['onchange'] = ((JSAny _) {
    final files = input['files'] as JSObject?;
    final count = (files?['length'] as JSNumber?)?.toDartInt ?? 0;
    if (!picked.isCompleted) {
      picked.complete(
        count == 0 ? null : files!.callMethod<JSObject>('item'.toJS, 0.toJS),
      );
    }
  }).toJS;
  input['oncancel'] = ((JSAny _) {
    if (!picked.isCompleted) picked.complete(null);
  }).toJS;
  input.callMethod('click'.toJS);
  final file = await picked.future;
  if (file == null) return null;
  final name = (file['name'] as JSString).toDart;
  final size = (file['size'] as JSNumber).toDartInt;
  Uint8List? bytes;
  if (size <= kChatMediaMaxBytes) {
    final buf = await file
        .callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS)
        .toDart;
    bytes = buf.toDart.asUint8List();
  }
  return PickedChatFile(
    name: name,
    mime: chatMimeFor(name, (file['type'] as JSString?)?.toDart),
    size: size,
    bytes: bytes,
  );
}

/// The web recorder ignores the path and returns a blob: URL on stop.
Future<String> voiceRecordingPath() async => '';

Future<Uint8List> readVoiceRecording(String blobUrl) async {
  final res = await http.get(Uri.parse(blobUrl));
  final url = globalContext['URL'] as JSObject;
  url.callMethod('revokeObjectURL'.toJS, blobUrl.toJS);
  return res.bodyBytes;
}
