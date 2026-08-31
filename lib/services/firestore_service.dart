import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  static const _rtdbUrl = 'https://ahmed-hartak-default-rtdb.firebaseio.com';

  /// حفظ العملية بعد الإرسال - للـ history (Firestore + RealtimeDB fallback)
  Future<void> saveOrder({
    required String productName,
    required String productId,
    required String sender,
    required String receiver,
    required String status, // success / failed
    required Map<String, dynamic> serverResponse,
  }) async {
    final data = {
      'productName': productName,
      'productId': productId,
      'sender': sender,
      'receiver': receiver,
      'status': status,
      'serverResponse': serverResponse,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
    };
    final plain = {
      'productName': productName,
      'productId': productId,
      'sender': sender,
      'receiver': receiver,
      'status': status,
      'createdAtLocal': DateTime.now().toIso8601String(),
    };
    // حاول Firestore أولاً
    try {
      await _db.collection('users').doc(uid).collection('orders').add(data);
      await _db.collection('users').doc(uid).set({
        'lastOrderAt': FieldValue.serverTimestamp(),
        'msisdn': sender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // تجاهل خطأ الصلاحيات - سيتم الحفظ في RTDB
    }
    // حفظ احتياطي في Realtime Database (يعمل حتى لو Firestore مقفول)
    try {
      final rtdbUrl = Uri.parse('$_rtdbUrl/history/$uid.json');
      await http.post(rtdbUrl, body: jsonEncode(plain)).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// جلب سجل العمليات - مرتب بـ createdAtLocal لضمان الظهور حتى قبل اكتمال serverTimestamp
  Stream<QuerySnapshot> ordersStream() {
    try {
      return _db.collection('users').doc(uid).collection('orders').orderBy('createdAtLocal', descending: true).limit(50).snapshots();
    } catch (_) {
      return _db.collection('users').doc(uid).collection('orders').orderBy('createdAt', descending: true).limit(50).snapshots();
    }
  }

  /// جلب مرة واحدة (fallback) - Firestore
  Future<List<QueryDocumentSnapshot>> getOrdersOnce() async {
    try {
      final snap = await _db.collection('users').doc(uid).collection('orders').orderBy('createdAtLocal', descending: true).limit(50).get();
      if (snap.docs.isNotEmpty) return snap.docs;
    } catch (_) {}
    try {
      final snap = await _db.collection('users').doc(uid).collection('orders').orderBy('createdAt', descending: true).limit(50).get();
      return snap.docs;
    } catch (_) {
      try {
        final snap = await _db.collection('users').doc(uid).collection('orders').limit(50).get();
        return snap.docs;
      } catch (e) {
        // لو permission-denied، سيتم التجربة عبر RTDB في history_screen
        rethrow;
      }
    }
  }

  /// جلب من Realtime Database كـ fallback (يعمل حتى لو Firestore مقفول)
  Future<List<Map<String, dynamic>>> getOrdersRtdb() async {
    try {
      final url = Uri.parse('$_rtdbUrl/history/$uid.json');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200 || resp.body == 'null' || resp.body.isEmpty) return [];
      final data = jsonDecode(resp.body);
      if (data is! Map) return [];
      final list = <Map<String, dynamic>>[];
      (data as Map).forEach((k, v) {
        if (v is Map) list.add(Map<String, dynamic>.from(v));
      });
      // رتب حسب createdAtLocal تنازلي
      list.sort((a, b) => (b['createdAtLocal']?.toString() ?? '').compareTo(a['createdAtLocal']?.toString() ?? ''));
      return list.take(50).toList();
    } catch (_) {
      return [];
    }
  }

  /// إنشاء بروفايل عند أول تسجيل
  Future<void> ensureUserDoc({String? displayName, String? phone}) async {
    final user = _auth.currentUser!;
    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? '',
        'phone': phone ?? user.phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
