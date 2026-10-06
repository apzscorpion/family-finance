import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/notification_bridge.dart';
import '../data/payment_parser.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';

/// Prominent disclosure shown *before* sending anyone to Android's
/// notification-access settings.
///
/// Google Play requires that sensitive access is explained in-app, in context,
/// before the request — not only in a privacy policy. It also requires the app
/// to remain usable when access is declined, which it is: manual entry and
/// every other screen work regardless.
class DetectionSetupV3 extends StatefulWidget {
  const DetectionSetupV3({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DetectionSetupV3()),
      );

  @override
  State<DetectionSetupV3> createState() => _DetectionSetupV3State();
}

class _DetectionSetupV3State extends State<DetectionSetupV3>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Access is granted in system settings, so the result only shows up when
    // the user comes back to the app.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final g = await NotificationBridge.isGranted();
    if (!mounted) return;
    setState(() {
      _granted = g;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(PhRegular.arrowLeft,
                          size: 22, color: Nocturne.text),
                    ),
                  ),
                  const Expanded(
                    child: Text('Detect payments',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.mix(const Color(0xFF67B5E1), 16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(PhRegular.bellRinging,
                          size: 30, color: Color(0xFF67B5E1)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Add expenses automatically',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Nocturne.text),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'With your permission, the app reads the payment alerts '
                    'your bank and UPI apps already show you, and offers them '
                    'for review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: Nocturne.neutral400),
                  ),
                  const SizedBox(height: 22),
                  _Point(
                    icon: PhRegular.checkCircle,
                    color: NocturneSemantic.income,
                    title: 'Nothing is added without you',
                    body:
                        'Every detected payment waits in a review list. You '
                        'confirm or ignore it.',
                  ),
                  _Point(
                    icon: PhRegular.lockSimple,
                    color: Nocturne.accent300,
                    title: 'It stays on this phone',
                    body:
                        'Notification text is read and parsed on your device. '
                        'Only the amount, merchant and category you confirm '
                        'are saved to your workspace.',
                  ),
                  _Point(
                    icon: PhRegular.x,
                    color: Nocturne.neutral400,
                    title: 'Your SMS inbox is never accessed',
                    body:
                        'The app does not request SMS permissions and cannot '
                        'read your messages.',
                  ),
                  _Point(
                    icon: PhRegular.users,
                    color: const Color(0xFF67B5E1),
                    title: 'Only payment apps are watched',
                    body:
                        'Alerts from banking and UPI apps are the only ones '
                        'looked at. Chats, email and everything else are '
                        'ignored.',
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'You can turn this off at any time in Android Settings → '
                      'Notification access, or from Settings in this app. The '
                      'app works normally without it.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Nocturne.neutral500),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_checking)
                    const Center(
                      child: CircularProgressIndicator(
                          color: Nocturne.accent300),
                    )
                  else if (_granted)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Nocturne.mix(NocturneSemantic.income, 10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Nocturne.mix(NocturneSemantic.income, 45),
                            width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(PhFill.checkCircle,
                              size: 18, color: NocturneSemantic.income),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Detection is on. New payment alerts will appear '
                              'for review.',
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: NocturneSemantic.income),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: NotificationBridge.openSettings,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Nocturne.mix(Nocturne.accent, 18),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Nocturne.accent, width: 1),
                        ),
                        child: const Text('Turn on detection',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Nocturne.accent100)),
                      ),
                    ),
                  if (!_checking && !_granted) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'This opens Android settings. Find “Family Spend '
                      'Tracker” in the list and switch it on.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: Nocturne.neutral500),
                    ),
                  ],
                  if (_granted) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final s = context.read<V3State>();
                        final found = await s.importDetected();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(found == 0
                                ? 'No new payment alerts yet'
                                : '$found payment${found == 1 ? '' : 's'} ready to review'),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: Nocturne.neutral800, width: 1),
                        ),
                        child: const Text('Check for new payments now',
                            style: TextStyle(
                                fontSize: 14, color: Nocturne.neutral300)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Point({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Nocturne.mix(color, 14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.text)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Nocturne.neutral500)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Re-exported so the Detected page can show the same confidence wording.
typedef DetectionConfidence = ParseConfidence;
