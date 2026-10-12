import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prayer/prayer_config.dart';
import '../phosphor_icons.dart';

/// Full-screen prayer alert: just the prayer's name, high contrast, on black.
///
/// Opened by the prayer notification's full-screen intent, so it can appear
/// over the lock screen. Closing it sends the app back behind the lock screen
/// rather than revealing the finance screens.
class PrayerAlertV3 extends StatelessWidget {
  final PrayerSlot slot;
  const PrayerAlertV3({super.key, required this.slot});

  static const _native = MethodChannel('com.familyfinance/notifications');

  static Route<void> route(String slotName) {
    final slot = PrayerSlot.values.asNameMap()[slotName] ?? PrayerSlot.fajr;
    return PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => PrayerAlertV3(slot: slot),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  Future<void> _close(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      await _native.invokeMethod('leaveLockScreen');
    } catch (_) {
      // Not on Android (or an old build): popping the page is enough.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          slot.label,
                          style: const TextStyle(
                            fontSize: 88,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slot.arabic,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                            fontSize: 34, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: () => _close(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1.5),
                        ),
                        child: const Icon(PhRegular.x,
                            size: 28, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
