import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_log.dart';
import '../../services/update_service.dart';
import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../widgets/v3_motion.dart';

/// Checking for a new build, in the v3 styling.
///
/// The version number and the URLs come from UpdateService, which the release
/// script rewrites on every release — duplicating them here would mean a
/// second place to forget.
///
/// The old UpdateService dialog is left alone: it is painted with the previous
/// theme and is only reachable from the v2 settings screen, which no longer
/// runs.
class UpdateSheetV3 {
  UpdateSheetV3._();

  /// Looks up the published version and reports back.
  ///
  /// [silent] suppresses the "you are up to date" message, for checks the user
  /// did not ask for. A newer version is always shown.
  static Future<void> check(BuildContext context, {bool silent = false}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    String? latest;
    try {
      latest = await UpdateService.fetchLatestVersion();
    } catch (err, stack) {
      AppLog.error('UpdateSheetV3.check', err, stack);
    }

    if (!context.mounted) return;

    if (latest == null) {
      if (!silent) {
        messenger?.showSnackBar(const SnackBar(
          content: Text('Could not reach GitHub to check for updates'),
        ));
      }
      return;
    }

    if (!UpdateService.isNewer(UpdateService.currentVersion, latest)) {
      if (!silent) {
        messenger?.showSnackBar(SnackBar(
          content: Text('You are on the latest version '
              '(v${UpdateService.currentVersion})'),
        ));
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpdateSheet(latest: latest!),
    );
  }
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({required this.latest});

  final String latest;

  Future<void> _download(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      await launchUrl(
        Uri.parse(UpdateService.latestApkUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (err, stack) {
      AppLog.error('UpdateSheetV3.download', err, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 18 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            top: BorderSide(color: Nocturne.neutral800, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Nocturne.neutral700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Nocturne.accent900,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(PhRegular.arrowCircleDown,
                    size: 21, color: Nocturne.accent200),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version $latest is available',
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.text)),
                    const SizedBox(height: 2),
                    Text('You have v${UpdateService.currentVersion}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Nocturne.neutral400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'The download opens in your browser. Tap the file when it '
              'finishes to install over the current version — your data stays '
              'where it is, since it lives in your account.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: Nocturne.neutral300),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: V3Press(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border:
                          Border.all(color: Nocturne.neutral700, width: 1),
                    ),
                    child: const Text('Later',
                        style: TextStyle(
                            fontSize: 14.5, color: Nocturne.neutral300)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: V3Press(
                  onTap: () => _download(context),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Nocturne.accent600, Nocturne.accent800],
                      ),
                      border: Border.all(color: Nocturne.accent400, width: 1),
                    ),
                    child: const Text('Download update',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.accent100)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
