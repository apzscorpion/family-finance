import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateService {
  static const String currentVersion = '1.8.2';
  static const String githubRepo = 'apzscorpion/family-finance';
  static const String pubspecUrl =
      'https://raw.githubusercontent.com/$githubRepo/main/mobile/pubspec.yaml';
  static const String latestApkUrl =
      'https://github.com/$githubRepo/raw/main/releases/FamilySpendTracker-latest.apk';

  /// The version published on main, or null if GitHub could not be reached.
  ///
  /// Split out from [checkForUpdates] so the v3 sheet can present the result
  /// itself while the version and URLs stay defined in one place — the release
  /// script rewrites [currentVersion] here on every release.
  static Future<String?> fetchLatestVersion() async {
    final response = await http.get(Uri.parse(pubspecUrl));
    if (response.statusCode != 200) return null;
    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(response.body);
    return match?.group(1);
  }

  static bool isNewer(String current, String latest) =>
      _isNewerVersion(current, latest);

  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    try {
      final response = await http.get(Uri.parse(pubspecUrl));

      if (response.statusCode != 200) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App is up to date.')),
          );
        }
        return;
      }

      final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
          .firstMatch(response.body);
      final String latestTag = match?.group(1) ?? currentVersion;

      if (_isNewerVersion(currentVersion, latestTag) && context.mounted) {
        _showUpdateDialog(
          context,
          latestTag,
          'A newer version (v$latestTag) of Family Spend Tracker is available with the latest improvements and fixes.',
          latestApkUrl,
        );
      } else if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Family Spend Tracker is up to date (v$currentVersion).')),
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
