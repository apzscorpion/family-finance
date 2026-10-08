import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/app_log.dart';

Future<bool> shareExportedContent(
  String content,
  String fileName, {
  String? subject,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);

    final result = await Share.shareXFiles(
      [XFile(file.path, name: fileName)],
      subject: subject ?? fileName,
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (err, stack) {
    AppLog.error('DataExport.share', err, stack);
    return false;
  }
}
