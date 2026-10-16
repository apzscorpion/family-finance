import 'dart:typed_data';

/// Storage bucket for chat photos, files and voice notes (private, RLS).
const kChatMediaBucket = 'chat-media';

/// Matches the bucket's file_size_limit in the chat_media migration.
const kChatMediaMaxBytes = 25 * 1024 * 1024;

/// A file chosen from the device for sending in chat. [bytes] is null when
/// the file is larger than [kChatMediaMaxBytes] and was not read.
class PickedChatFile {
  const PickedChatFile({
    required this.name,
    required this.mime,
    required this.size,
    this.bytes,
  });

  final String name;
  final String mime;
  final int size;
  final Uint8List? bytes;
}

/// Keeps a file name safe as a storage key: ASCII letters, digits, dot,
/// dash and underscore only, at most 80 characters, extension kept.
String safeChatFileName(String name) {
  var s = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  s = s.replaceAll(RegExp(r'^[._]+'), '');
  if (s.isEmpty) return 'file';
  if (s.length <= 80) return s;
  final dot = s.lastIndexOf('.');
  final ext = dot > 0 && s.length - dot <= 10 ? s.substring(dot) : '';
  return s.substring(0, 80 - ext.length) + ext;
}

/// `<family>/<low>_<high>/<message>/<file>`; the storage policies and the
/// direct_messages check constraint both rely on this exact shape.
String chatMediaPath({
  required String familyId,
  required String userA,
  required String userB,
  required String messageId,
  required String fileName,
}) {
  final pair = userA.compareTo(userB) <= 0 ? '${userA}_$userB' : '${userB}_$userA';
  return '$familyId/$pair/$messageId/${safeChatFileName(fileName)}';
}

String formatChatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// `m:ss`, as voice notes show their length.
String formatChatDuration(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The text body stored with a media message. Chat list previews and
/// notifications show it as-is.
String chatMediaBody({
  required String kind,
  required String name,
  bool viewOnce = false,
  String caption = '',
}) {
  if (viewOnce) return '👁 View once photo';
  final c = caption.trim();
  switch (kind) {
    case 'voice':
      return '🎤 Voice message';
    case 'image':
      return c.isEmpty ? '📷 Photo' : c;
    default:
      return c.isEmpty ? '📎 $name' : c;
  }
}

const _mimeByExt = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'zip': 'application/zip',
  'm4a': 'audio/mp4',
  'webm': 'audio/webm',
  'mp3': 'audio/mpeg',
};

/// Mime from the file extension, for pickers that do not report one.
String chatMimeFor(String name, [String? reported]) {
  if (reported != null && reported.isNotEmpty) return reported;
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _mimeByExt[ext] ?? 'application/octet-stream';
}
