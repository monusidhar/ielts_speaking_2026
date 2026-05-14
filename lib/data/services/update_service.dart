import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/update_service.dart
//
// Google Play In-App Update + remote config for per-release force/flexible
// control. Fetches a JSON from GitHub Pages to decide update behaviour:
//
//   https://monusidhar.github.io/ielts-speaking-update.json
//
//   {
//     "min_force_version": "1.0.0"   ← versions BELOW this get forced update
//   }
//
// Workflow:
//   1. Publish new APK to Play Store
//   2. To FORCE update → change min_force_version in JSON, push to GitHub
//   3. For OPTIONAL update → just publish to Play Store, leave JSON as-is
//
// All errors are caught silently — update check never crashes the app.
// ─────────────────────────────────────────────────────────────────────────────

class UpdateService {
  UpdateService._();

  static const String _configUrl =
      'https://monusidhar.github.io/ielts-speaking-update.json';

  /// Prevents checking more than once per app session
  static bool _checked = false;

  /// Call from HomeScreen initState. Safe to fire-and-forget.
  static Future<void> checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      // 1. Ask Play Store if an update is available
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return; // No update on Play Store — nothing to do
      }

      // 2. Fetch remote config to decide force vs flexible
      final forceUpdate = await _shouldForceUpdate();

      if (forceUpdate && updateInfo.immediateUpdateAllowed) {
        // ── Force update: full-screen, blocks app until updated ────────────
        await InAppUpdate.performImmediateUpdate();
      } else if (updateInfo.flexibleUpdateAllowed) {
        // ── Flexible update: bottom banner, user can dismiss ───────────────
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          // Download complete → install silently on next app restart
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      // Silently ignore — update check is non-critical
      debugPrint('UpdateService: $e');
    }
  }

  /// Fetches the remote JSON config and compares current app version
  /// against min_force_version. Returns true if current < min_force_version.
  static Future<bool> _shouldForceUpdate() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse(_configUrl));
      final response = await request.close();

      if (response.statusCode != 200) return false;

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final minForceVersion = json['min_force_version'] as String? ?? '0.0.0';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      return _compareVersions(currentVersion, minForceVersion) < 0;
    } catch (e) {
      debugPrint('UpdateService config fetch: $e');
      return false; // On error, default to flexible (non-blocking)
    }
  }

  /// Compares two semantic version strings (e.g. "1.2.3" vs "1.3.0").
  /// Returns negative if a < b, 0 if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }
}
