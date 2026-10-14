import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateService {
  static const String currentVersion = '1.10.11';
  static const String githubRepo = 'apzscorpion/family-finance';
  // APKs live on GitHub Releases, not in the repo, so clones stay small. The
  // version comes from the same release, so it always matches the download.
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';
  static const String latestApkUrl =
      'https://github.com/$githubRepo/releases/latest/download/Sampio-latest.apk';

  /// The newer release this build could update to, or null when up to date
  /// or not checked yet. Settings listens to it to show the update button.
  static final available =
      ValueNotifier<({String version, String notes})?>(null);

  /// The latest published release (version + release notes), or null if
  /// GitHub could not be reached. Also refreshes [available].
  ///
  /// The release script rewrites [currentVersion] above on every release.
  static Future<({String version, String notes})?> fetchLatestRelease() async {
    final response = await http.get(Uri.parse(latestReleaseUrl));
    if (response.statusCode != 200) return null;
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final m = RegExp(r'(\d+\.\d+\.\d+)')
        .firstMatch(j['tag_name']?.toString() ?? '');
    if (m == null) return null;
    final release = (
      version: m.group(1)!,
      notes: (j['body'] ?? '').toString().trim(),
    );
    available.value =
        _isNewerVersion(currentVersion, release.version) ? release : null;
    return release;
  }

  static Future<String?> fetchLatestVersion() async =>
      (await fetchLatestRelease())?.version;

  static bool isNewer(String current, String latest) =>
      _isNewerVersion(current, latest);

  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    try {
      final latest = await fetchLatestVersion();

      if (latest == null) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App is up to date.')),
          );
        }
        return;
      }

      final String latestTag = latest;

      if (_isNewerVersion(currentVersion, latestTag) && context.mounted) {
        _showUpdateDialog(
          context,
          latestTag,
          'A newer version (v$latestTag) of Sampio is available with the latest improvements and fixes.',
          latestApkUrl,
        );
      } else if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sampio is up to date (v$currentVersion).')),
        );
      }
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to check for updates: $e')),
        );
      }
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < c.length && i < l.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String notes, String downloadUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppTheme.accent900,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.system_update_alt,
                        color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Available (v$version)',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text)),
                        Text('Current version: v$currentVersion',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSubtle)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Release Notes:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text(notes,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.text)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3F424D)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Later',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final uri = Uri.parse(downloadUrl);
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.bg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Download Update',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
