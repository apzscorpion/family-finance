import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/supabase_service.dart';
import 'v3/v3_app.dart';

/// The v3 shell is the app.
///
/// Until now this file still built the previous UI and v3 was reachable only
/// through `lib/main_v3.dart`, which meant released builds never actually
/// contained the redesign.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // V3App reads Supabase.instance.client while building its providers, so
  // unlike the old entry point this one has to wait for initialisation.
  // Failures are swallowed inside init(); the auth screen reports them.
  await SupabaseService.ready;

  runApp(const V3App());
}
