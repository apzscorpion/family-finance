import 'package:flutter/material.dart';

import 'services/supabase_service.dart';
import 'v3/sheets/v3_sheets.dart';
import 'web/web_app.dart';

/// Browser entry point (`flutter build web --target lib/main_web.dart`).
///
/// Composes only web-safe providers and leaves the local notification /
/// astronomy stack out of the web bundle.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  V3Sheets.readOnly = true;
  await SupabaseService.ready;
  runApp(const WebApp());
}
