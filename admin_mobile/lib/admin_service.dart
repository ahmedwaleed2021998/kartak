import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AdminService {
  static const dbUrl = 'https://ahmed-hartak-default-rtdb.firebaseio.com';
  static const usersPath = 'users';

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<int> getGoogleTimestamp() async {
    try {
      final req = await http.head(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 10));
      final dateStr = req.headers['date'];
      if (dateStr != null) {
        return DateTime.parse(dateStr).millisecondsSinceEpoch ~/ 1000;
      }
    } catch (_) {}
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static Future<Map<String, dynamic>?> getAllUsers() async {
    final url = Uri.parse('$dbUrl/$usersPath.json');
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.body == 'null' || resp.body.isEmpty) return {};
      return jsonDecode(resp.body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<(bool, String)> registerUser(String username, String password, int days, int hours, int minutes) async {
    final total = days * 86400 + hours * 3600 + minutes * 60;
    final now = await getGoogleTimestamp();
    final data = {"password": hashPassword(password), "created": now, "expires": now + total};
    final url = Uri.parse('$dbUrl/$usersPath/$username.json');
    try {
      final resp = await http.put(url, body: jsonEncode(data)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم إنشاء الحساب بنجاح!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال بقاعدة البيانات');
    }
  }

  static Future<(bool, String)> renewUser(String username, int days, int hours, int minutes) async {
    final users = await getAllUsers();
    if (users == null) return (false, 'تعذر الاتصال');
    if (!users.containsKey(username)) return (false, 'المستخدم غير موجود');
    final now = await getGoogleTimestamp();
    final extra = days * 86400 + hours * 3600 + minutes * 60;
    final user = users[username] is Map ? Map<String, dynamic>.from(users[username]) : {"password": users[username].toString()};
    final currentExpires = user['expires'] as int?;
    final base = (currentExpires != null && currentExpires > now) ? currentExpires : now;
    user['expires'] = base + extra;
    final url = Uri.parse('$dbUrl/$usersPath/$username.json');
    try {
      final resp = await http.put(url, body: jsonEncode(user)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم تمديد الاشتراك بنجاح!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال');
    }
  }

  static Future<(bool, String)> changePassword(String username, String newPassword) async {
    final users = await getAllUsers();
    if (users == null) return (false, 'تعذر الاتصال');
    if (!users.containsKey(username)) return (false, 'المستخدم غير موجود');
    final user = users[username] is Map ? Map<String, dynamic>.from(users[username]) : <String, dynamic>{};
    user['password'] = hashPassword(newPassword);
    final url = Uri.parse('$dbUrl/$usersPath/$username.json');
    try {
      final resp = await http.put(url, body: jsonEncode(user)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم تغيير كلمة السر!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال');
    }
  }

  static Future<(bool, String)> deleteUser(String username) async {
    final url = Uri.parse('$dbUrl/$usersPath/$username.json');
    try {
      final resp = await http.delete(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم حذف المستخدم!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال');
    }
  }
}
