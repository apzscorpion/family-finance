import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../../services/app_log.dart';

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
