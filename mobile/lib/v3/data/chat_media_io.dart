import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/app_log.dart';
import 'chat_media.dart';

const _files = MethodChannel('com.familyfinance/file_import');
const _downloads = MethodChannel('com.familyfinance/downloads');

/// Saves a chat photo into the phone's gallery (Pictures/KinPurse), where it
/// shows up in Photos. Android 10+ writes through MediaStore with no
/// permission. The manifest strips WRITE_EXTERNAL_STORAGE on purpose, so on
/// Android 9 and older this returns false and the viewer's Share remains.
Future<bool> saveChatImage(Uint8List bytes, String fileName) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      return false;
    }
    final dot = fileName.lastIndexOf('.');
    await Gal.putImageBytes(
      bytes,
      album: 'KinPurse',
      name: dot > 0 ? fileName.substring(0, dot) : fileName,
    );
    return true;
  } catch (err, stack) {
    AppLog.error('saveChatImage', err, stack);
    return false;
  }
}

/// Downloads a chat file from its signed [url] and saves it: photos to the
/// gallery, everything else to Downloads/KinPurse through MediaStore (no
/// permission on Android 10+). Older Android falls back to the share sheet.
Future<bool> saveChatDownload(String url, String name, String mime) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return false;
    final bytes = res.bodyBytes;
    if (mime.startsWith('image/') && await saveChatImage(bytes, name)) {
      return true;
    }
    final saved = await _downloads.invokeMethod<bool>(
      'save',
      {'bytes': bytes, 'name': name, 'mime': mime},
    );
    if (saved == true) return true;
    await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: mime)]);
    return true;
  } catch (err, stack) {
    AppLog.error('saveChatDownload', err, stack);
    return false;
  }
}

/// Any file through Android's document picker. Null when cancelled.
Future<PickedChatFile?> pickChatFile() async {
  final raw = await _files.invokeMethod<dynamic>(
    'pickDocument',
    {'type': 'raw', 'maxBytes': kChatMediaMaxBytes},
  );
  if (raw is! Map) return null;
  final name = (raw['fileName'] ?? 'file').toString();
  final bytes = raw['bytes'];
  return PickedChatFile(
    name: name,
    mime: chatMimeFor(name, raw['mime']?.toString()),
    size: (raw['size'] as num?)?.toInt() ?? 0,
    bytes: bytes is Uint8List ? bytes : null,
  );
}

/// Where the recorder writes a voice note before it is uploaded.
Future<String> voiceRecordingPath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

/// Reads a finished recording and deletes the temp file.
Future<Uint8List> readVoiceRecording(String path) async {
  final f = File(path);
  final bytes = await f.readAsBytes();
  try {
    await f.delete();
  } catch (_) {}
  return bytes;
}
