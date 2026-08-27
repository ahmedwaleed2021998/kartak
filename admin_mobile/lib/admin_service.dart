import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AdminService {
  static const dbUrl = 'https://ahmed-hartak-default-rtdb.firebaseio.com';
  static const usersPath = 'users';
  static const apiKey = 'AIzaSyBUzyV0L-0e-EW9egYcagSzrP_ke2dcGhg';

  static String encodeEmail(String email) => email.trim().toLowerCase().replaceAll('.', ',');
  static String decodeEmail(String key) => key.replaceAll(',', '.');
  static bool isValidEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

  static Future<(bool, String)> createAuthUser(String email, String password) async {
    final url = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    try {
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({"email": email, "password": password, "returnSecureToken": true})).timeout(const Duration(seconds: 15));
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) return (true, data['localId'] ?? '');
      final msg = data['error']?['message'] ?? resp.body;
      if (msg.contains('EMAIL_EXISTS')) return (false, 'البريد موجود بالفعل في Authentication');
      if (msg.contains('WEAK_PASSWORD')) return (false, 'كلمة السر ضعيفة');
      if (msg.contains('INVALID_EMAIL')) return (false, 'البريد غير صحيح');
      return (false, 'Auth: $msg');
    } catch (_) {
      return (false, 'تعذر الاتصال بـ Auth');
    }
  }

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

  static Future<(bool, String)> registerUser(String email, String password, int days, int hours, int minutes) async {
    if (!isValidEmail(email)) return (false, 'البريد غير صحيح');
    // 1) إنشاء في Authentication (يظهر في console.firebase.google.com/project/ahmed-hartak/authentication/users)
    final (okAuth, msgAuth) = await createAuthUser(email.trim().toLowerCase(), password);
    if (!okAuth) return (false, msgAuth);
    // 2) إنشاء في Realtime Database مع الانتهاء
    final total = days * 86400 + hours * 3600 + minutes * 60;
    final now = await getGoogleTimestamp();
    final data = {"email": email.trim().toLowerCase(), "password": hashPassword(password), "created": now, "expires": now + total, "authUid": msgAuth};
    final key = encodeEmail(email);
    final url = Uri.parse('$dbUrl/$usersPath/${Uri.encodeComponent(key)}.json');
    try {
      final resp = await http.put(url, body: jsonEncode(data)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم في Authentication و Database!');
      return (false, 'تم في Auth لكن فشل Database (${resp.statusCode})');
    } catch (_) {
      return (false, 'تم في Auth لكن تعذر Database');
    }
  }

  static Future<(bool, String)> renewUser(String email, int days, int hours, int minutes) async {
    final users = await getAllUsers();
    if (users == null) return (false, 'تعذر الاتصال');
    final key = encodeEmail(email);
    var actualKey = key;
    if (!users.containsKey(key) && users.containsKey(email.trim())) actualKey = email.trim();
    else if (!users.containsKey(key)) return (false, 'البريد غير موجود');
    final now = await getGoogleTimestamp();
    final extra = days * 86400 + hours * 3600 + minutes * 60;
    final user = users[actualKey] is Map ? Map<String, dynamic>.from(users[actualKey]) : {"password": users[actualKey].toString(), "email": email.trim().toLowerCase()};
    final currentExpires = user['expires'] as int?;
    final base = (currentExpires != null && currentExpires > now) ? currentExpires : now;
    user['expires'] = base + extra;
    user['email'] = email.trim().toLowerCase();
    final url = Uri.parse('$dbUrl/$usersPath/${Uri.encodeComponent(actualKey)}.json');
    try {
      final resp = await http.put(url, body: jsonEncode(user)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم تمديد الاشتراك بنجاح!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال');
    }
  }

  static Future<(bool, String)> changePassword(String email, String newPassword) async {
    final users = await getAllUsers();
    if (users == null) return (false, 'تعذر الاتصال');
    final key = encodeEmail(email);
    var actualKey = key;
    if (!users.containsKey(key) && users.containsKey(email.trim())) actualKey = email.trim();
    else if (!users.containsKey(key)) return (false, 'البريد غير موجود');
    final user = users[actualKey] is Map ? Map<String, dynamic>.from(users[actualKey]) : <String, dynamic>{};
    user['password'] = hashPassword(newPassword);
    user['email'] = email.trim().toLowerCase();
    final url = Uri.parse('$dbUrl/$usersPath/${Uri.encodeComponent(actualKey)}.json');
    try {
      final resp = await http.put(url, body: jsonEncode(user)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم تغيير كلمة السر!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال');
    }
  }

  static Future<(bool, String)> deleteUser(String email) async {
    final users = await getAllUsers();
    final key = encodeEmail(email);
    var actualKey = key;
    if (users != null && !users.containsKey(key) && users.containsKey(email.trim())) actualKey = email.trim();
    final url = Uri.parse('$dbUrl/$usersPath/${Uri.encodeComponent(actualKey)}.json');
    try {
      final resp = await http.delete(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return (true, 'تم حذف المستخدم!');
      return (false, 'خطأ سيرفر (${resp.statusCode})');
    } catch (_) {
      return (false, 'تعذر الاتصال');
    }
  }
}
