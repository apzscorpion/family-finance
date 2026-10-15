import 'dart:typed_data';

import 'package:gal/gal.dart';

import '../../services/app_log.dart';

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
