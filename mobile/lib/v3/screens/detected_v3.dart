import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../data/notification_bridge.dart';
import '../v3_state.dart';
import 'detection_setup_v3.dart';
import '../widgets/v3_primitives.dart';
import '../widgets/v3_motion.dart';

/// Detected payments awaiting review.
///
/// The privacy note is part of the design and is accurate here: parsing happens
/// on the device, and only the reviewed fields are stored.
class DetectedV3 extends StatelessWidget {
  const DetectedV3({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Only shown where the listener actually exists; in the standard
        // build it would describe something the app cannot do.
        FutureBuilder<bool>(
          future: NotificationBridge.isAvailable(),
          builder: (context, snap) => snap.data == true
              ? const _DetectionBanner()
              : const SizedBox.shrink(),
        ),
        const _DetectionStatus(),
        if (s.detected.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56, horizontal: 16),
            child: Column(
              children: [
                Icon(PhRegular.tray, size: 38, color: Nocturne.neutral600),
                SizedBox(height: 8),
                Text('All reviewed',
                    style:
                        TextStyle(fontSize: 14, color: Nocturne.neutral300)),
                SizedBox(height: 4),
                Text('New payment notifications will appear here',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: Nocturne.neutral500)),
              ],
            ),
          )
        else
          for (var i = 0; i < s.detected.length; i++)
            V3Rise(index: i, child: _DetectedCard(detected: s.detected[i])),
      ],
    );
  }
}

class _DetectedCard extends StatelessWidget {
  final dynamic detected;
  const _DetectedCard({required this.detected});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final d = detected;
    final style = s.catStyle(d.categoryKey ?? 'shopping');

    final (confColor, confIcon) = switch (d.confidence) {
      'high' => (NocturneSemantic.income, PhFill.checkCircle),
      'duplicate' => (NocturneSemantic.expense, PhRegular.warning),
      _ => (NocturneSemantic.warning, PhRegular.info),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: d.confidence == 'high'
              ? Nocturne.neutral900
              : Nocturne.mix(confColor, 40),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhRegular.bellRinging,
                  size: 14, color: Nocturne.neutral400),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${d.sourceApp ?? 'Bank app'} · ${_when(d.detectedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Nocturne.neutral400)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Nocturne.mix(confColor, 18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(confIcon, size: 11, color: confColor),
                    const SizedBox(width: 4),
                    Text(_confLabel(d.confidence),
                        style:
                            TextStyle(fontSize: 10.5, color: confColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              V3IconTile(
                  icon: style.icon,
                  color: style.color,
                  size: 40,
                  radius: 12,
                  iconSize: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text)),
                    Text('${style.name} · ${d.method ?? 'UPI'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Nocturne.neutral400)),
                  ],
                ),
              ),
              V3Num(V3Design.inr(d.amount),
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text)),
            ],
          ),
          if (d.snippet != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(PhRegular.quotes,
                        size: 12, color: Nocturne.neutral600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(d.snippet,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: Nocturne.neutral400)),
                  ),
                ],
              ),
            ),
          ],
          if (d.note != null) ...[
            const SizedBox(height: 8),
            Text(d.note,
                style: TextStyle(fontSize: 11.5, color: confColor)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Action(
                  label: 'Ignore',
                  border: Nocturne.neutral800,
                  color: Nocturne.neutral400,
                  onTap: () => s.resolveDetected(d, 'ignored'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _Action(
                  label: 'Add ${V3Design.inrShort(d.amount)}',
                  border: Nocturne.accent,
                  color: Nocturne.accent100,
                  fill: Nocturne.mix(Nocturne.accent, 14),
                  onTap: () => s.resolveDetected(d, 'added'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _confLabel(String c) => switch (c) {
        'high' => 'High',
        'duplicate' => 'Duplicate?',
        _ => 'Check',
      };

  static String _when(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final time = '$h:${d.minute.toString().padLeft(2, '0')} '
        '${d.hour >= 12 ? 'PM' : 'AM'}';
    if (days == 0) return 'Today, $time';
    if (days == 1) return 'Yesterday, $time';
    return '${d.day}/${d.month}, $time';
  }
}

class _Action extends StatelessWidget {
  final String label;
  final Color border;
  final Color color;
  final Color? fill;
  final VoidCallback onTap;

  const _Action({
    required this.label,
    required this.border,
    required this.color,
    this.fill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: color)),
        ),
      );
}


/// Explains where detected payments come from, and opens the setup page.
class _DetectionBanner extends StatelessWidget {
  const _DetectionBanner();

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => DetectionSetupV3.open(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Nocturne.accent900,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhRegular.bellRinging, size: 17, color: Nocturne.accent200),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Read from bank & UPI app notifications on this phone. '
                  'Your SMS inbox is never accessed.',
                  style: TextStyle(
                      fontSize: 12, height: 1.45, color: Nocturne.accent200),
                ),
              ),
              SizedBox(width: 8),
              Icon(PhRegular.caretRight, size: 14, color: Nocturne.accent300),
            ],
          ),
        ),
      );
}

/// Shows whether detection is on, and offers a manual sweep when it is.
class _DetectionStatus extends StatefulWidget {
  const _DetectionStatus();

  @override
  State<_DetectionStatus> createState() => _DetectionStatusState();
}

class _DetectionStatusState extends State<_DetectionStatus>
    with WidgetsBindingObserver {
  bool? _granted;
  bool _available = true;
  bool _busy = false;

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
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!NotificationBridge.isSupported) {
      if (mounted) setState(() => _granted = false);
      return;
    }
    if (!await NotificationBridge.isAvailable()) {
      if (mounted) setState(() => _available = false);
      return;
    }
    final g = await NotificationBridge.isGranted();
    if (!mounted) return;
    setState(() => _granted = g);
    // Anything captured while the app was closed is imported on return.
    if (g) await _sweep(silent: true);
  }

  Future<void> _sweep({bool silent = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final found = await context.read<V3State>().importDetected();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(found == 0
              ? 'No new payment alerts yet'
              : '$found payment${found == 1 ? '' : 's'} added for review'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This build has no listener, so there is nothing to switch on. Say so
    // rather than showing a "Turn on" button that could never succeed.
    if (!_available) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Nocturne.neutral800, width: 1),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(PhRegular.info, size: 17, color: Nocturne.neutral400),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Automatic detection is not part of this build. Android blocks '
                'installing an app that reads notifications unless it comes '
                'from the Play Store. Add payments here by hand, or install '
                'the detection build over USB.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.45, color: Nocturne.neutral400),
              ),
            ),
          ],
        ),
      );
    }

    if (_granted == null) return const SizedBox.shrink();

    if (_granted == false) {
      return GestureDetector(
        onTap: () => DetectionSetupV3.open(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Nocturne.neutral800, width: 1),
          ),
          child: Row(
            children: [
              const Icon(PhRegular.warning,
                  size: 17, color: NocturneSemantic.warning),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Detection is off — payments will not be added automatically',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.4, color: Nocturne.neutral300),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Nocturne.accent, width: 1),
                ),
                child: const Text('Turn on',
                    style:
                        TextStyle(fontSize: 11.5, color: Nocturne.accent200)),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _busy ? null : _sweep,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(_busy ? PhRegular.arrowsClockwise : PhFill.checkCircle,
                size: 14,
                color: _busy
                    ? Nocturne.neutral400
                    : NocturneSemantic.income),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _busy ? 'Checking…' : 'Detection is on · tap to check now',
                style: const TextStyle(
                    fontSize: 12, color: Nocturne.neutral500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
