import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  /// حفظ العملية بعد الإرسال - للـ history
  Future<void> saveOrder({
    required String productName,
    required String productId,
    required String sender,
    required String receiver,
    required String status, // success / failed
    required Map<String, dynamic> serverResponse,
  }) async {
    await _db.collection('users').doc(uid).collection('orders').add({
      'productName': productName,
      'productId': productId,
      'sender': sender,
      'receiver': receiver,
      'status': status,
      'serverResponse': serverResponse,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
    });

    // تحديث ملف المستخدم
    await _db.collection('users').doc(uid).set({
      'lastOrderAt': FieldValue.serverTimestamp(),
      'msisdn': sender,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// جلب سجل العمليات
  Stream<QuerySnapshot> ordersStream() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
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
