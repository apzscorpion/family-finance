import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import '../theme/app_theme.dart';

class UpdateService {
  static const String currentVersion = '1.0.0';
  static const String githubRepo = 'apzscorpion/family-finance';
  static const String latestReleaseUrl = 'https://api.github.com/repos/$githubRepo/releases/latest';

  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    try {
      final response = await http.get(
        Uri.parse(latestReleaseUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App is up to date (no releases found yet).')),
          );
        }
        return;
      }

      final data = json.decode(response.body);
      final String latestTag = (data['tag_name'] as String? ?? '1.0.0').replaceAll('v', '');
      final String releaseNotes = data['body'] as String? ?? 'New improvements and bug fixes.';
      final List assets = data['assets'] as List? ?? [];

      String? downloadUrl;
      for (var asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (_isNewerVersion(currentVersion, latestTag) && downloadUrl != null && context.mounted) {
        _showUpdateDialog(context, latestTag, releaseNotes, downloadUrl);
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

  static void _showUpdateDialog(BuildContext context, String version, String notes, String downloadUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String statusText = '';
        double progress = 0.0;
        bool isDownloading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            void startDownload() {
              setState(() {
                isDownloading = true;
                statusText = 'Starting download...';
              });

              try {
                OtaUpdate().execute(downloadUrl, destinationFilename: 'family_finance_v$version.apk').listen(
                  (OtaEvent event) {
                    setState(() {
                      if (event.status == OtaStatus.DOWNLOADING) {
                        progress = (double.tryParse(event.value ?? '0') ?? 0.0) / 100.0;
                        statusText = 'Downloading... ${(progress * 100).toInt()}%';
                      } else if (event.status == OtaStatus.INSTALLING) {
                        statusText = 'Opening installer...';
                      } else if (event.status == OtaStatus.ALREADY_RUNNING_ERROR) {
                        statusText = 'Download already in progress';
                      } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
                        statusText = 'Storage permission required to update.';
                        isDownloading = false;
                      } else {
                        statusText = 'Update event: ${event.status}';
                      }
                    });
                  },
                  onError: (error) {
                    setState(() {
                      statusText = 'Download failed: $error';
                      isDownloading = false;
                    });
                  },
                );
              } catch (e) {
                setState(() {
                  statusText = 'Error starting update: $e';
                  isDownloading = false;
                });
              }
            }

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
                        decoration: BoxDecoration(color: AppTheme.accent900, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.system_update_alt, color: AppTheme.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Update Available (v$version)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text)),
                            Text('Current version: v$currentVersion', style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Release Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                        const SizedBox(height: 4),
                        Text(notes, style: const TextStyle(fontSize: 12.5, color: AppTheme.text)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isDownloading) ...[
                    LinearProgressIndicator(value: progress > 0 ? progress : null, backgroundColor: AppTheme.bg, color: AppTheme.accent),
                    const SizedBox(height: 8),
                    Text(statusText, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 16),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF3F424D)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text('Later', style: TextStyle(color: AppTheme.textMuted)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: startDownload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: AppTheme.bg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

