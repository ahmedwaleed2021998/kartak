import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PointsService {
  static const _rtdbUrl = 'https://ahmed-hartak-default-rtdb.firebaseio.com';
  final _auth = FirebaseAuth.instance;

  String? get _emailKey {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    return email.trim().toLowerCase().replaceAll('.', ',');
  }

  // جلب النقاط مرة واحدة
  Future<int> getPoints() async {
    final key = _emailKey;
    if (key == null) return 0;
    try {
      final url = Uri.parse('$_rtdbUrl/users/${Uri.encodeComponent(key)}.json');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.body != 'null' && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        if (data is Map) return (data['points'] as int?) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // Stream للنقاط يتحدث كل 3 ثواني (polling) - آمن بدون Firestore rules
  Stream<int> pointsStream() async* {
    while (true) {
      yield await getPoints();
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // إضافة نقاط بعد كل عملية ناجحة
  Future<void> addPointsForCurrentUser(int amount) async {
    final key = _emailKey;
    if (key == null) return;
    try {
      final url = Uri.parse('$_rtdbUrl/users/${Uri.encodeComponent(key)}/points.json');
      final cur = await getPoints();
      final next = cur + amount;
      await http.put(url, body: jsonEncode(next)).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // هل معاه نقاط كافية؟
  Future<bool> hasEnough(int required) async => await getPoints() >= required;

  // خصم نقاط (للشحن) - يرجع false لو مفيش كفاية
  Future<bool> deductPoints(int amount) async {
    final key = _emailKey;
    if (key == null) return false;
    try {
      final cur = await getPoints();
      if (cur < amount) return false;
      final next = cur - amount;
      final url = Uri.parse('$_rtdbUrl/users/${Uri.encodeComponent(key)}/points.json');
      await http.put(url, body: jsonEncode(next)).timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  // النقاط المطلوبة لكل كارت (تقدر تغيرها)
  static int requiredForProduct(String productId) {
    // فكة صغيرة 5، كبيرة 10، مارد 8
    if (productId.contains("2.5") || productId.contains("4.25") || productId.contains("5")) return 5;
    if (productId.contains("Mared") || productId.contains("مارد")) return 8;
    return 10;
  }
}
