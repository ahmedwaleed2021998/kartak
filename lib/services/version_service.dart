import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  // في Firebase Realtime DB: /config/app_version = {"latest": "1.0.0+2", "force": true, "url": "https://github.com/ahmedwaleed2021998/kartak/releases"}
  static const _url = 'https://ahmed-hartak-default-rtdb.firebaseio.com/config/app_version.json';

  static Future<Map<String, dynamic>?> fetchRemote() async {
    try {
      final resp = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.body != 'null' && resp.body.isNotEmpty) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return "${info.version}+${info.buildNumber}";
  }

  // مقارنة بسيطة: لو latest != current يعتبر تحديث مطلوب
  static bool needsUpdate(String current, String latest) {
    return current != latest;
  }

  static int compareBuild(String current, String latest) {
    // يأخذ رقم البناء بعد +
    int c = int.tryParse(current.split('+').last) ?? 0;
    int l = int.tryParse(latest.split('+').last) ?? 0;
    return l.compareTo(c);
  }
}
