import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/firestore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
        await FirestoreService().ensureUserDoc(displayName: cred.user?.email?.split('@').first);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mapError(e.code)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) return;
      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(accessToken: gAuth.accessToken, idToken: gAuth.idToken);
      final res = await FirebaseAuth.instance.signInWithCredential(cred);
      await FirestoreService().ensureUserDoc(displayName: res.user?.displayName);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ جوجل: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found': return 'المستخدم غير موجود';
      case 'wrong-password': return 'كلمة السر خطأ';
      case 'email-already-in-use': return 'الإيميل مستخدم بالفعل';
      case 'weak-password': return 'كلمة السر ضعيفة';
      default: return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', width: 120, height: 120, errorBuilder: (_,__,___)=> const Icon(Icons.sim_card, size: 64, color: Color(0xFFE11D48))),
                    const SizedBox(height: 12),
                    const Text('كروت وشحن', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Text('كروت جميع الشبكات - شحن رصيد فودافون', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'الإيميل', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                      validator: (v) => v!=null && v.contains('@') ? null : 'إيميل غير صحيح',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'كلمة السر',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: ()=>setState(()=>_obscure=!_obscure)),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!=null && v.length>=6 ? null : '6 أحرف على الأقل',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(_isLogin ? 'دخول' : 'إنشاء حساب', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    TextButton(onPressed: ()=>setState(()=>_isLogin=!_isLogin), child: Text(_isLogin ? 'ليس لديك حساب؟ سجل الآن' : 'لديك حساب؟ ادخل')),
                    const Divider(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(onPressed: _loading ? null : _google, icon: const Icon(Icons.login), label: const Text('دخول بجوجل')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
