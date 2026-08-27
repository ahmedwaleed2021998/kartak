import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class DeviceService {
  static const dbUrl = 'https://ahmed-hartak-default-rtdb.firebaseio.com';
  static String encodeEmail(String email) => email.trim().toLowerCase().replaceAll('.', ',');

  static Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        // androidId ثابت للجهاز (يتغير بعد Factory Reset)
        return android.id ?? android.fingerprint ?? 'unknown';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return ios.identifierForVendor ?? 'unknown';
      }
    } catch (_) {}
    return 'unknown';
  }

  static String hashDevice(String deviceId) {
    return sha256.convert(utf8.encode(deviceId)).toString().substring(0, 16);
  }

  /// يفحص هل الجهاز مربوط، ولو أول مرة يربطه، ولو مربوط بجهاز آخر يرجع false
  static Future<(bool allowed, String message)> checkAndBindDevice(String email) async {
    final deviceId = await getDeviceId();
    final deviceHash = hashDevice(deviceId);
    final key = encodeEmail(email);
    final url = Uri.parse('$dbUrl/users/${Uri.encodeComponent(key)}.json');

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200 || resp.body == 'null' || resp.body.isEmpty) {
        return (true, 'لا يوجد بيانات اشتراك - سماح مؤقت');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final storedDevice = data['deviceId'] as String?;
      final storedHash = data['deviceHash'] as String?;

      // أول مرة: لا يوجد جهاز مربوط -> اربط الحالي
      if (storedDevice == null && storedHash == null) {
        final patch = {"deviceId": deviceId, "deviceHash": deviceHash, "deviceModel": await _model()};
        await http.patch(url, body: jsonEncode(patch)).timeout(const Duration(seconds: 10));
        return (true, 'تم ربط الجهاز');
      }

      // قارن الهاش
      if (storedHash != null) {
        if (storedHash == deviceHash) return (true, 'الجهاز مطابق');
        return (false, 'هذا الإيميل مربوط بجهاز آخر');
      }
      // قديم: مخزن deviceId فقط
      if (storedDevice == deviceId) return (true, 'الجهاز مطابق');
      return (false, 'هذا الإيميل مربوط بجهاز آخر');
    } catch (e) {
      return (true, 'تعذر التحقق - سماح مؤقت: $e');
    }
  }

  static Future<String> _model() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return "${a.manufacturer} ${a.model}";
      }
    } catch (_) {}
    return "unknown";
  }

  /// للأدمن: فك ربط الجهاز
  static Future<bool> resetDevice(String email) async {
    final key = encodeEmail(email);
    final url = Uri.parse('$dbUrl/users/${Uri.encodeComponent(key)}.json');
    try {
      await http.patch(url, body: jsonEncode({"deviceId": null, "deviceHash": null})).timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }
}
