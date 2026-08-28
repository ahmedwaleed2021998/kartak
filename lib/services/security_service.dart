import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();

  static Future<bool> isEmulator() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        final fingerprint = android.fingerprint.toLowerCase();
        final model = android.model.toLowerCase();
        final brand = android.brand.toLowerCase();
        // علامات المحاكي الشائعة
        if (fingerprint.contains('generic') || fingerprint.contains('emulator') || fingerprint.contains('sdk_gphone')) return true;
        if (model.contains('emulator') || model.contains('sdk_gphone') || brand.contains('generic')) return true;
        if (android.hardware.toLowerCase().contains('ranchu') || android.hardware.toLowerCase().contains('goldfish')) return true;
        // خصائص المحاكي
        if (!android.isPhysicalDevice) return true;
      }
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        if (!ios.isPhysicalDevice) return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> isRooted() async {
    // فحص بسيط بدون صلاحيات إضافية
    try {
      if (Platform.isAndroid) {
        // وجود ملفات su
        final suPaths = ['/system/bin/su', '/system/xbin/su', '/sbin/su', '/system/su'];
        for (final p in suPaths) {
          if (await File(p).exists()) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<void> saveSecure(String key, String value) async => await _storage.write(key: key, value: value);
  static Future<String?> readSecure(String key) async => await _storage.read(key: key);
  static Future<void> deleteSecure(String key) async => await _storage.delete(key: key);
}
