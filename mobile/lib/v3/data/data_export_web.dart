import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../services/app_log.dart';

Future<bool> shareExportedContent(
  String content,
  String fileName, {
  String? subject,
}) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final mime = fileName.endsWith('.csv') ? 'text/csv' : 'text/markdown';
    final result = await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName, mimeType: mime)],
      subject: subject ?? fileName,
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (err, stack) {
    AppLog.error('DataExport.share (web)', err, stack);
    return false;
  }
}
