import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../services/app_log.dart';

/// A file chosen through Android's document picker.
class PickedDocument {
  const PickedDocument({
    required this.kind,
    required this.fileName,
    required this.text,
    this.bytes,
  });

  /// One of `csv`, `md`, `txt`, `xlsx` or `pdf`.
  final String kind;
  final String fileName;

  /// Extracted text. Empty for a workbook, which arrives as [bytes].
  final String text;
  final Uint8List? bytes;

  bool get isSpreadsheet => kind == 'xlsx';
}

/// Picks a document for the expense importer.
///
/// Deliberately separate from NoteImportService: that one reformats what it
/// reads into note content, while importing expenses needs the text exactly as
/// it was written, plus the raw bytes of a workbook.
class ImportPicker {
  ImportPicker._();

  static const _channel = MethodChannel('com.familyfinance/file_import');

  /// Returns null when the user backs out of the picker.
  static Future<PickedDocument?> pick({String type = 'any'}) async {
    try {
      final raw =
          await _channel.invokeMethod<dynamic>('pickDocument', {'type': type});
      if (raw == null || raw is! Map) return null;

      final map = Map<String, dynamic>.from(raw);
      final name = (map['fileName'] ?? 'document').toString();

      // The native side labels plain text generically, so the extension is a
      // better signal of how to parse it.
      final lower = name.toLowerCase();
      var kind = (map['kind'] ?? 'txt').toString();
      if (lower.endsWith('.csv')) {
        kind = 'csv';
      } else if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
        kind = 'md';
      } else if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
        kind = 'xlsx';
      }

      Uint8List? bytes;
      final rawBytes = map['bytes'];
      if (rawBytes is Uint8List) {
        bytes = rawBytes;
      } else if (rawBytes is List<int>) {
        bytes = Uint8List.fromList(rawBytes);
      }

      return PickedDocument(
        kind: kind,
        fileName: name,
        text: (map['text'] ?? '').toString(),
        bytes: bytes,
      );
    } catch (err, stack) {
      AppLog.error('ImportPicker.pick', err, stack);
      return null;
    }
  }
}
