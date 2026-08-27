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

  // لكل كارت: controller للرقم والباس
  final Map<String, TextEditingController> receiverCtrls = {};
  final Map<String, TextEditingController> pinCtrls = {};
  final Map<String, bool> showPin = {};
  final Map<String, bool> sending = {};
  final Map<String, bool> toSelf = {};

  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    for (var p in VodafoneService.products) {
      receiverCtrls[p.$3] = TextEditingController();
      pinCtrls[p.$3] = TextEditingController();
      showPin[p.$3] = false;
      sending[p.$3] = false;
      toSelf[p.$3] = true;
    }
    _checkSubscription();
  }

  @override
  void dispose() {
    for (var c in receiverCtrls.values) c.dispose();
    for (var c in pinCtrls.values) c.dispose();
    super.dispose();
  }

  void addLog(String m) => setState(() => logs.insert(0, "[${TimeOfDay.now().format(context)}] $m"));

  Future<void> _checkSubscription() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      setState(() => checkingSub = false);
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
          int nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          try {
            final g = await http.head(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
            final d = g.headers['date'];
            if (d != null) nowTs = DateTime.parse(d).millisecondsSinceEpoch ~/ 1000;
          } catch (_) {}
          if (expires <= nowTs) {
            setState(() {
              expired = true;
              checkingSub = false;
            });
            if (mounted) _showExpiredDialog();
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => checkingSub = false);
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
            TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); if (context.mounted) Navigator.of(context).pop(); }, child: const Text('خروج')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
              onPressed: () async {
                final uri = Uri.parse('https://wa.me/201098969844?text=مرحبا%20مطور%20كروت%20وشحن%20اشتراكي%20انتهى%20-%20${FirebaseAuth.instance.currentUser?.email ?? ''}');
                try { if (await canLaunchUrl(uri)) { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } } catch (_) {}
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
    try { if (await canLaunchUrl(uri)) { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } } catch (_) {}
    await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true));
  }

  Future<void> connect() async {
    setState(() => connecting = true);
    addLog("↻ الاتصال بمحفظة فودافون...");
    try {
      final res = await vodafone.getSeamless();
      addLog("✓ seamless OK");
      final t = await vodafone.getToken(res.seamless);
      setState(() { msisdn = res.msisdn; token = t; seamless = res.seamless; });
      addLog("✓ تم الاتصال: $msisdn - الجلسة نشطة");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الاتصال: $msisdn"), backgroundColor: Colors.green));
    } catch (e) {
      addLog("✗ فشل: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: Colors.red));
    } finally {
      setState(() => connecting = false);
    }
  }

  Future<void> sendFor(String productId, String productLabel) async {
    final isSelf = toSelf[productId] ?? true;
    final recvCtrl = receiverCtrls[productId]!;
    final pinCtrl = pinCtrls[productId]!;
    final receiver = isSelf ? msisdn! : recvCtrl.text.trim();
    final pin = pinCtrl.text.trim();

    if (msisdn == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اتصل بالمحفظة أولاً")));
      return;
    }
    if (!isSelf && !(receiver.startsWith("01") && receiver.length == 11 && int.tryParse(receiver) != null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رقم المستلم خطأ - 11 رقم يبدأ 01")));
      return;
    }
    if (pin.length != 6 || int.tryParse(pin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN لازم 6 أرقام")));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد التحويل"),
        content: Text("الكارت: $productLabel\nالمرسل: $msisdn\nالمستلم: $receiver\n\nسيتم الخصم فوراً"),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("أوافق"))],
      ),
    );
    if (ok != true) return;

    setState(() => sending[productId] = true);
    addLog("↻ إرسال $productLabel إلى $receiver ...");
    try {
      final resp = await vodafone.sendOrder(productId: productId, receiver: receiver, pin: pin, msisdn: msisdn!, token: token!);
      final code = resp['code'];
      final status = resp['_httpStatus'];
      final isSuccess = status == 200 && (code == "0000" || resp['orderTotalPrice'] != null);
      final statusStr = isSuccess ? "success" : "failed";
      await firestore.saveOrder(productName: productLabel, productId: productId, sender: msisdn!, receiver: receiver, status: statusStr, serverResponse: resp);
      if (isSuccess) {
        addLog("✓✓✓ تم بنجاح! ${resp['orderTotalPrice'] ?? ''} جنيه");
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
      setState(() => sending[productId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = msisdn != null && token != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(children: [
          Image.asset('assets/images/logo.png', width: 36, height: 36, errorBuilder: (_, __, ___) => const Icon(Icons.sim_card, color: Colors.white)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("كروت وشحن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("شحن الفكة بأسعار زمان", style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
        actions: [IconButton(onPressed: () async => await FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))],
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
                  child: Column(children: [
                    // اتصال
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("① الاتصال بالمحفظة", style: TextStyle(fontWeight: FontWeight.bold)),
                          const Text("لازم داتا فودافون أو VPN", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: Text(connected ? "✓ $msisdn" : "● غير متصل", style: TextStyle(color: connected ? Colors.green : Colors.grey, fontWeight: FontWeight.bold))),
                            ElevatedButton(onPressed: connecting ? null : connect, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: connecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("↻ اتصال")),
                          ]),
                          if (connected) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 16), const SizedBox(width: 6), Expanded(child: Text("رقم المحفظة: $msisdn - الجلسة نشطة", style: const TextStyle(color: Colors.green, fontSize: 12)))])),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // شبكة الكروت
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: VodafoneService.products.length,
                      itemBuilder: (context, idx) {
                        final p = VodafoneService.products[idx];
                        final pid = p.$3;
                        final label = "${p.$1} - ${p.$2}";
                        final price = p.$2.replaceAll(RegExp(r'[^0-9.]'), '').trim();
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(children: [
                            // صورة الكارت
                            Container(
                              height: 90,
                              width: double.infinity,
                              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB90A1A), Color(0xFF7A0A15)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                              child: Stack(alignment: Alignment.center, children: [
                                Image.asset('assets/images/logo.png', height: 70, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.sim_card, color: Colors.white, size: 40)),
                                Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text("${p.$1}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB90A1A))))),
                              ]),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  Text(p.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  if (price.isNotEmpty) Text("$price جنيه", style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                                  const SizedBox(height: 6),
                                  // لنفسي / لرقم آخر
                                  Row(children: [
                                    Expanded(child: InkWell(onTap: () => setState(() => toSelf[pid] = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: (toSelf[pid] ?? true) ? const Color(0xFFE11D48) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: Text("لنفسي", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: (toSelf[pid] ?? true) ? Colors.white : Colors.black, fontWeight: FontWeight.bold))))),
                                    const SizedBox(width: 4),
                                    Expanded(child: InkWell(onTap: () => setState(() => toSelf[pid] = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: !(toSelf[pid] ?? true) ? const Color(0xFF0F172A) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: Text("لرقم آخر", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: !(toSelf[pid] ?? true) ? Colors.white : Colors.black, fontWeight: FontWeight.bold))))),
                                  ]),
                                  const SizedBox(height: 6),
                                  if (!(toSelf[pid] ?? true))
                                    SizedBox(height: 36, child: TextField(controller: receiverCtrls[pid], keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: "01xxxxxxxxx", prefixIcon: Icon(Icons.phone, size: 16), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), isDense: true))),
                                  if (!(toSelf[pid] ?? true)) const SizedBox(height: 6),
                                  SizedBox(height: 36, child: TextField(controller: pinCtrls[pid], keyboardType: TextInputType.number, maxLength: 6, obscureText: !(showPin[pid] ?? false), style: const TextStyle(fontSize: 12), decoration: InputDecoration(counterText: "", hintText: "PIN 6 أرقام", prefixIcon: const Icon(Icons.lock, size: 16), suffixIcon: InkWell(onTap: () => setState(() => showPin[pid] = !(showPin[pid] ?? false)), child: Icon((showPin[pid] ?? false) ? Icons.visibility_off : Icons.visibility, size: 16)), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), isDense: true))),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 36,
                                    child: ElevatedButton(
                                      onPressed: (connected && !(sending[pid] ?? false)) ? () => sendFor(pid, label) : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.zero),
                                      child: (sending[pid] ?? false) ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("⚡ إرسال", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("سجل العمليات", style: TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: () => setState(() => logs.clear()), child: const Text("مسح"))]),
                          Container(height: 120, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)), child: logs.isEmpty ? const Center(child: Text("لا يوجد سجل", style: TextStyle(color: Colors.white54))) : ListView.builder(itemCount: logs.length, itemBuilder: (_, i) => Text(logs[i], style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11), textDirection: TextDirection.rtl))),
                        ]),
                      ),
                    ),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("سجلك المحفوظ (Firebase)", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: firestore.ordersStream(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                              if (snap.data!.docs.isEmpty) return const Text("لا توجد عمليات محفوظة", style: TextStyle(color: Colors.grey));
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: snap.data!.docs.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final d = snap.data!.docs[i].data() as Map<String, dynamic>;
                                  final isOk = d['status'] == 'success';
                                  return ListTile(dense: true, leading: Icon(isOk ? Icons.check_circle : Icons.error, color: isOk ? Colors.green : Colors.red, size: 20), title: Text(d['productName'] ?? '', style: const TextStyle(fontSize: 13)), subtitle: Text("${d['receiver']} • ${d['status']}", style: const TextStyle(fontSize: 11)), trailing: Text(d['createdAtLocal']?.toString().substring(11, 16) ?? '', style: const TextStyle(fontSize: 11)));
                                },
                              );
                            },
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    const Text("كروت وشحن © 2026", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ]),
                ),
    );
  }

  Widget _card({required List<Widget> children}) => Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
  Widget _title(String t, String? sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), if (sub != null) Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
}
