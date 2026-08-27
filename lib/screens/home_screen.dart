import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/vodafone_service.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final vodafone = VodafoneService();
  final firestore = FirestoreService();

  String? msisdn;
  String? token;
  String? seamless;
  bool connecting = false;
  bool checkingSub = true;
  bool expired = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      setState(() { checkingSub = false; });
      return;
    }
    try {
      final key = email.trim().toLowerCase().replaceAll('.', ',');
      final url = Uri.parse('https://ahmed-hartak-default-rtdb.firebaseio.com/users/${Uri.encodeComponent(key)}.json');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.body != 'null' && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        final expires = data is Map ? data['expires'] as int? : null;
        if (expires != null) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          // جرب وقت جوجل لو أمكن
          int nowTs = now;
          try {
            final g = await http.head(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
            final d = g.headers['date'];
            if (d != null) nowTs = DateTime.parse(d).millisecondsSinceEpoch ~/ 1000;
          } catch (_) {}
          if (expires <= nowTs) {
            setState(() { expired = true; checkingSub = false; });
            if (mounted) _showExpiredDialog();
            return;
          }
        }
      } else {
        // لو المستخدم مش موجود في DB اعتبره منتهي
        // لكن نسمح للأدمن يجرب - فقط لو فيه users
      }
    } catch (_) {}
    if (mounted) setState(() { checkingSub = false; });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('اشتراكك انتهي')]),
          content: const Text('اشتراكك انتهي تواصل مع المطور لتجديد الاشتراك', style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('خروج'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
              onPressed: () async {
                final uri = Uri.parse('https://wa.me/201098969844?text=مرحبا%20مطور%20كروت%20وشحن%20اشتراكي%20انتهى%20-%20${FirebaseAuth.instance.currentUser?.email ?? ''}');
                try {
                  if (await canLaunchUrl(uri)) {
                    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (ok) return;
                  }
                } catch (_) {}
                // fallback Chrome
                await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true));
              },
              icon: const Icon(Icons.chat),
              label: const Text('تواصل مع المطور'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactExpired() async {
    final uri = Uri.parse('https://wa.me/201098969844?text=مرحبا%20مطور%20كروت%20وشحن%20اشتراكي%20انتهى');
    try {
      if (await canLaunchUrl(uri)) {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      }
    } catch (_) {}
    await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true));
  }
  String selectedProductLabel = VodafoneService.products.first.$2; // اسم أول منتج
  String get selectedProductId {
    final e = VodafoneService.products.firstWhere((p) => p.$2 == selectedProductLabel, orElse: () => VodafoneService.products.first);
    return e.$3;
  }
  String get selectedProductDisplay {
    final e = VodafoneService.products.firstWhere((p) => p.$2 == selectedProductLabel);
    return "${e.$1} - ${e.$2}";
  }

  bool toSelf = true;
  final receiverCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool showPin = false;
  bool agree = false;
  bool sending = false;
  List<String> logs = [];

  void addLog(String m) => setState(()=> logs.insert(0, "[${TimeOfDay.now().format(context)}] $m"));

  Future<void> connect() async {
    setState(()=> connecting = true);
    addLog("↻ الاتصال بمحفظة فودافون...");
    try {
      final res = await vodafone.getSeamless();
      addLog("✓ seamless OK");
      final t = await vodafone.getToken(res.seamless);
      setState((){ msisdn = res.msisdn; token = t; seamless = res.seamless; });
      addLog("✓ تم الاتصال: $msisdn - الجلسة نشطة");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الاتصال: $msisdn"), backgroundColor: Colors.green));
    } catch (e) {
      addLog("✗ فشل: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: Colors.red));
    } finally {
      setState(()=> connecting = false);
    }
  }

  Future<void> send() async {
    final receiver = toSelf ? msisdn! : receiverCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (msisdn==null || token==null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اتصل بالمحفظة أولاً"))); return; }
    if (!toSelf && !(receiver.startsWith("01") && receiver.length==11)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رقم المستلم خطأ"))); return; }
    if (pin.length!=6 || int.tryParse(pin)==null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN لازم 6 أرقام"))); return; }
    if (!agree) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لازم توافق أولاً"))); return; }

    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text("تأكيد التحويل"),
      content: Text("الكارت: $selectedProductDisplay\nالمرسل: $msisdn\nالمستلم: $receiver\n\nسيتم الخصم فوراً"),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context,false), child: const Text("إلغاء")), ElevatedButton(onPressed: ()=> Navigator.pop(context,true), child: const Text("أوافق"))],
    ));
    if (ok != true) return;

    setState(()=> sending = true);
    addLog("↻ إرسال $selectedProductDisplay إلى $receiver ...");
    try {
      final resp = await vodafone.sendOrder(productId: selectedProductId, receiver: receiver, pin: pin, msisdn: msisdn!, token: token!);
      final code = resp['code'];
      final status = resp['_httpStatus'];
      final isSuccess = status==200 && (code=="0000" || resp['orderTotalPrice']!=null);
      final statusStr = isSuccess ? "success" : "failed";
      await firestore.saveOrder(productName: selectedProductDisplay, productId: selectedProductId, sender: msisdn!, receiver: receiver, status: statusStr, serverResponse: resp);
      if (isSuccess) {
        addLog("✓✓✓ تم التحويل بنجاح! المبلغ: ${resp['orderTotalPrice'] ?? '-'} جنيه");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم بنجاح! ${resp['orderTotalPrice'] ?? ''} جنيه"), backgroundColor: Colors.green));
      } else {
        final err = resp['reason'] ?? resp['message'] ?? 'غير معروف';
        addLog("✗ فشل: $err (كود $code)");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل: $err"), backgroundColor: Colors.red));
      }
    } catch (e) {
      addLog("✗ خطأ: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
    } finally {
      setState(()=> sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = msisdn!=null && token!=null;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(children: [
          Image.asset('assets/images/logo.png', width: 36, height: 36, errorBuilder: (_,__,___)=> const Icon(Icons.sim_card, color: Colors.white)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("كروت وشحن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("كروت جميع الشبكات", style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(onPressed: () async { await FirebaseAuth.instance.signOut(); }, icon: const Icon(Icons.logout)),
        ],
      ),
      body: checkingSub
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : expired
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.block, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('اشتراكك انتهي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 8),
                          const Text('تواصل مع المطور لتجديد الاشتراك', textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                              onPressed: _contactExpired,
                              icon: const Icon(Icons.chat),
                              label: const Text('تواصل مع المطور - واتساب'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(onPressed: () async => await FirebaseAuth.instance.signOut(), child: const Text('تسجيل خروج')),
                        ]),
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
            // 1 اتصال
            _card(children: [
              _title("① الاتصال بالمحفظة", "لازم داتا فودافون أو VPN"),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(connected ? "✓ $msisdn" : "● غير متصل", style: TextStyle(color: connected? Colors.green : Colors.grey, fontWeight: FontWeight.bold))),
                ElevatedButton(onPressed: connecting? null : connect, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: connecting? const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth:2,color: Colors.white)) : const Text("↻ اتصال")),
              ]),
              if (connected) Container(margin: const EdgeInsets.only(top:8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size:16), const SizedBox(width:6), Expanded(child: Text("رقم المحفظة: $msisdn - الجلسة نشطة", style: const TextStyle(color: Colors.green)))])),
            ]),
            _card(children: [
              _title("② اختيار الكارت", "25 خدمة متاحة"),
              DropdownButtonFormField<String>(
                value: selectedProductLabel,
                isExpanded: true,
                items: VodafoneService.products.map((p) => DropdownMenuItem(value: p.$2, child: Text("${p.$1} - ${p.$2}", style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v)=> setState(()=> selectedProductLabel = v!),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ]),
            _card(children: [
              _title("③ المستلم", null),
              RadioListTile(value: true, groupValue: toSelf, onChanged: (v)=> setState(()=> toSelf=v!), title: const Text("لنفسي (نفس المحفظة)"), dense: true),
              RadioListTile(value: false, groupValue: toSelf, onChanged: (v)=> setState(()=> toSelf=v!), title: const Text("لرقم آخر"), dense: true),
              if (!toSelf) TextField(controller: receiverCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "01xxxxxxxxx", border: OutlineInputBorder(), hintText: "11 رقم يبدأ بـ 01")),
            ]),
            _card(children: [
              _title("④ الرقم السري", "6 أرقام"),
              TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 6, obscureText: !showPin, decoration: InputDecoration(labelText: "PIN", border: const OutlineInputBorder(), counterText: "", suffixIcon: IconButton(icon: Icon(showPin? Icons.visibility_off: Icons.visibility), onPressed: ()=> setState(()=> showPin=!showPin)))),
            ]),
            _card(children: [
              _title("⑤ التأكيد والإرسال", null),
              CheckboxListTile(value: agree, onChanged: (v)=> setState(()=> agree=v!), title: const Text("أوافق على الإرسال وأتحمل المسؤولية", style: TextStyle(fontSize: 12)), dense: true, controlAffinity: ListTileControlAffinity.leading),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: (!connected || sending || !agree)? null : send, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: sending? const CircularProgressIndicator(color: Colors.white) : const Text("⚡ إرسال الطلب الآن", style: TextStyle(fontWeight: FontWeight.bold)))),
            ]),
            // سجل محلي
            _card(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("سجل العمليات", style: TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: ()=> setState(()=> logs.clear()), child: const Text("مسح"))]),
              Container(height: 120, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)), child: logs.isEmpty? const Center(child: Text("لا يوجد سجل", style: TextStyle(color: Colors.white54))) : ListView.builder(itemCount: logs.length, itemBuilder: (_,i)=> Text(logs[i], style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11), textDirection: TextDirection.rtl))),
            ]),
            // سجل Firebase
            _card(children: [
              const Text("سجلك المحفوظ (Firebase)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: firestore.ordersStream(),
                builder: (context, snap){
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  if (snap.data!.docs.isEmpty) return const Text("لا توجد عمليات محفوظة", style: TextStyle(color: Colors.grey));
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snap.data!.docs.length,
                    separatorBuilder: (_,__)=> const Divider(height:1),
                    itemBuilder: (_,i){
                      final d = snap.data!.docs[i].data() as Map<String,dynamic>;
                      final isOk = d['status']=='success';
                      return ListTile(dense: true, leading: Icon(isOk? Icons.check_circle: Icons.error, color: isOk? Colors.green: Colors.red, size:20), title: Text(d['productName'] ?? '', style: const TextStyle(fontSize:13)), subtitle: Text("${d['receiver']} • ${d['status']}", style: const TextStyle(fontSize:11)), trailing: Text(d['createdAtLocal']?.toString().substring(11,16) ?? '', style: const TextStyle(fontSize:11)));
                    },
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text("كروت وشحن © 2026", style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Card(margin: const EdgeInsets.only(bottom:12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
  Widget _title(String t, String? sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), if(sub!=null) Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
}
