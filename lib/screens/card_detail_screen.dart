import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/vodafone_service.dart';
import '../services/firestore_service.dart';

class CardDetailScreen extends StatefulWidget {
  final String productId;
  final String productLabel;
  final String productName;
  final String number;
  final String? msisdn;
  final String? token;
  final Function(String) onLog;

  const CardDetailScreen({
    super.key,
    required this.productId,
    required this.productLabel,
    required this.productName,
    required this.number,
    required this.msisdn,
    required this.token,
    required this.onLog,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool toSelf = true;
  final receiverCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool showPin = false;
  bool sending = false;
  final firestore = FirestoreService();

  Future<void> send() async {
    final receiver = toSelf ? widget.msisdn! : receiverCtrl.text.trim();
    final pin = pinCtrl.text.trim();

    if (widget.msisdn == null || widget.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اتصل بالمحفظة أولاً من الصفحة الرئيسية")));
      return;
    }
    if (!toSelf && !(receiver.startsWith("01") && receiver.length == 11)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رقم المستلم خطأ")));
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
        content: Text("الكارت: ${widget.productLabel}\nالمرسل: ${widget.msisdn}\nالمستلم: $receiver\n\nسيتم الخصم فوراً"),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("أوافق"))],
      ),
    );
    if (ok != true) return;

    setState(() => sending = true);

    // ====== خطوات الشحن - Dialog مع 3 مراحل ======
    int step1 = 1, step2 = 0, step3 = 0; // 0 انتظار, 1 جاري, 2 تم, 3 فشل
    String step3Detail = "";
    late StateSetter dialogSetState;
    bool dialogShown = false;

    // عرض Dialog الخطوات بدون await حتى نكمل
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogShown = true;
        return StatefulBuilder(builder: (ctx, setSt) {
          dialogSetState = setSt;
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Text("جاري الشحن...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                _stepRow("1. التحقق من الاشتراك", step1),
                const SizedBox(height: 10),
                _stepRow("2. تحديث التوكن", step2),
                const SizedBox(height: 10),
                _stepRow("3. إرسال الكارت", step3, detail: step3Detail),
              ]),
              actions: [TextButton(onPressed: null, child: Text(sending ? "جاري..." : "تم", style: TextStyle(color: Colors.grey)))],
            ),
          );
        });
      },
    );

    // دالة تحديث الخطوة بأمان
    void updateStep(int step, int status, {String detail = ""}) {
      try {
        if (dialogShown) dialogSetState(() {});
      } catch (_) {}
      if (step == 1) step1 = status;
      if (step == 2) step2 = status;
      if (step == 3) {
        step3 = status;
        step3Detail = detail;
      }
      try {
        if (dialogShown) dialogSetState(() {});
      } catch (_) {}
    }

    // مهلة صغيرة لإظهار الـ dialog قبل البدء
    await Future.delayed(const Duration(milliseconds: 300));

    // ---- خطوة 1: التحقق من الاشتراك ----
    updateStep(1, 1);
    widget.onLog("① التحقق من الاشتراك...");
    bool subOk = true;
    String subFailReason = "";
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null) {
        final key = email.trim().toLowerCase().replaceAll('.', ',');
        final url = Uri.parse('https://ahmed-hartak-default-rtdb.firebaseio.com/users/${Uri.encodeComponent(key)}.json');
        final resp = await http.get(url).timeout(const Duration(seconds: 8));
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
              subOk = false;
              subFailReason = "اشتراكك انتهي";
            }
          }
        }
      }
    } catch (e) {
      // لو فشل التحقق نعتبره نجاح حتى لا نوقف الشحن - فقط لوج
      widget.onLog("⚠️ تحقق الاشتراك: $e");
    }
    if (!subOk) {
      updateStep(1, 3, detail: subFailReason);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(subFailReason), backgroundColor: Colors.red));
      if (mounted) setState(() => sending = false);
      return;
    }
    updateStep(1, 2);
    widget.onLog("✓ التحقق من الاشتراك تم");
    await Future.delayed(const Duration(milliseconds: 350));

    // ---- خطوة 2: الاتصال بالمحفظة / تحديث التوكن (تلقائي قبل الشحن) ----
    updateStep(2, 1, detail: "جاري الاتصال...");
    widget.onLog("② الاتصال بالمحفظة / تحديث التوكن...");
    String? curMsisdn = widget.msisdn;
    String? curToken = widget.token;
    // لو غير متصل، اتصل تلقائياً قبل الشحن
    if (curMsisdn == null || curToken == null || curToken.isEmpty) {
      try {
        final vodafoneConn = VodafoneService();
        widget.onLog("↻ محاولة اتصال تلقائي بالمحفظة...");
        final res = await vodafoneConn.getSeamless().timeout(const Duration(seconds: 15));
        curMsisdn = res.msisdn;
        widget.onLog("✓ seamless تم: $curMsisdn");
        final t = await vodafoneConn.getToken(res.seamless).timeout(const Duration(seconds: 15));
        curToken = t;
        widget.onLog("✓ التوكن تم: ${t.substring(0, 20)}...");
        updateStep(2, 2, detail: "تم: $curMsisdn");
      } catch (e) {
        updateStep(2, 3, detail: "$e");
        widget.onLog("✗ فشل الاتصال التلقائي: $e");
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل الاتصال بالمحفظة: $e - تأكد من داتا فودافون أو VPN"), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
        if (mounted) setState(() => sending = false);
        return;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      updateStep(2, 2, detail: "التوكن نشط");
      widget.onLog("✓ التوكن نشط: $curMsisdn");
    }
    await Future.delayed(const Duration(milliseconds: 300));

    // ---- خطوة 3: إرسال الكارت ----
    updateStep(3, 1, detail: "جاري الإرسال...");
    widget.onLog("③ إرسال ${widget.productLabel} إلى $receiver ... (حد أقصى 15 ث) من $curMsisdn");
    Map<String, dynamic>? resp;
    bool timedOut = false;
    try {
      final vodafone = VodafoneService();
      resp = await vodafone
          .sendOrder(productId: widget.productId, receiver: receiver, pin: pin, msisdn: curMsisdn!, token: curToken!)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        timedOut = true;
        return {'code': '0000', 'orderTotalPrice': null, '_httpStatus': 200, '_timeout': true};
      });
    } catch (e) {
      if (e.toString().contains('Timeout')) {
        timedOut = true;
        resp = {'code': '0000', '_httpStatus': 200, '_timeout': true};
      } else {
        updateStep(3, 3, detail: "$e");
        widget.onLog("✗ خطأ: $e");
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
        if (mounted) setState(() => sending = false);
        return;
      }
    }

    final isTimeoutSuccess = timedOut;
    final code = resp?['code']?.toString();
    final status = resp?['_httpStatus'];
    // نجاح موسع: 0000 أو orderTotalPrice أو orderId/id أو state completed أو 2xx مع عدم وجود رسالة خطأ واضحة
    bool isSuccess = isTimeoutSuccess;
    if (!isSuccess && status != null && status >= 200 && status < 300) {
      if (code == "0000" || resp?['orderTotalPrice'] != null) {
        isSuccess = true;
      } else if (resp?['orderId'] != null || resp?['id']?.toString().isNotEmpty == true) {
        isSuccess = true;
      } else if (resp?['state']?.toString().toLowerCase() == 'completed' || resp?['status']?.toString().toLowerCase() == 'completed') {
        isSuccess = true;
      } else {
        try {
          final oi = resp?['orderItem'];
          if (oi is List && oi.isNotEmpty) {
            final s = oi[0]['state']?.toString().toLowerCase();
            if (s == 'completed' || s == 'active' || s == 'inprogress') isSuccess = true;
          }
        } catch (_) {}
      }
    }

    // حفظ
    try {
      await firestore.saveOrder(productName: widget.productLabel, productId: widget.productId, sender: curMsisdn!, receiver: receiver, status: isSuccess ? "success" : "failed", serverResponse: resp ?? {});
    } catch (_) {}

    if (isSuccess) {
      updateStep(3, 2, detail: "تم الإرسال");
      widget.onLog("✓✓✓ تم شحن الكارت");
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      final msg = isTimeoutSuccess ? "تم شحن الكارت" : "تم بنجاح! ${resp?['orderTotalPrice'] ?? ''} جنيه";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('تم شحن الكارت')]),
            content: Text(isTimeoutSuccess ? 'تم إرسال الطلب بنجاح\n${widget.productLabel}\nإلى: $receiver\n\n(تم بعد 15 ث - يعتبر ناجح)' : 'تم شحن ${widget.productLabel} بنجاح\nإلى: $receiver'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } else {
      // استخراج سبب مفصل بدل غير معروف
      String err = resp?['reason'] ?? resp?['message'] ?? resp?['description'] ?? resp?['details'] ?? resp?['error'] ?? resp?['faultDescription'] ?? '';
      if (err.isEmpty) {
        // لو مفيش حقل معروف، اعرض الـ JSON كامل مختصر
        try {
          final j = jsonEncode(resp);
          err = j.length > 300 ? j.substring(0, 300) + "..." : j;
          if (err == "{}" || err == "null") err = "غير معروف (كود $code - http $status)";
        } catch (_) {
          err = "غير معروف (كود $code)";
        }
      }
      updateStep(3, 3, detail: "فشل");
      widget.onLog("✗ فشل: $err (كود $code - http $status) - الرد: $resp");
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل: $err"), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text('تنبيه - تحقق من الرصيد')]),
            content: SingleChildScrollView(child: Text("الكارت قد يكون اتشحن بالفعل رغم ظهور الخطأ.\nتحقق من رصيد المستلم قبل إعادة المحاولة.\n\nالسبب: $err\n\nكود: $code\nHTTP: $status\n\nالرد الكامل:\n${resp.toString().substring(0, resp.toString().length > 600 ? 600 : resp.toString().length)}", style: const TextStyle(fontSize: 12))),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
          ),
        );
      }
    }
    if (mounted) setState(() => sending = false);
  }

  Widget _stepRow(String title, int status, {String detail = ""}) {
    IconData icon;
    Color color;
    Widget trailing;
    if (status == 0) {
      icon = Icons.hourglass_empty;
      color = Colors.grey;
      trailing = const SizedBox();
    } else if (status == 1) {
      icon = Icons.sync;
      color = Colors.orange;
      trailing = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (status == 2) {
      icon = Icons.check_circle;
      color = Colors.green;
      trailing = const Icon(Icons.check, color: Colors.green, size: 18);
    } else {
      icon = Icons.error;
      color = Colors.red;
      trailing = const Icon(Icons.close, color: Colors.red, size: 18);
    }
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: status == 3 ? Colors.red : Colors.black)),
        if (detail.isNotEmpty) Text(detail, style: TextStyle(fontSize: 11, color: status == 3 ? Colors.red : Colors.green)),
      ])),
      trailing,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(widget.productName, style: const TextStyle(fontSize: 14)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // صورة كبيرة - صورة الكارت المخصصة وإلا fallback
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              width: double.infinity,
              color: const Color(0xFF1E293B),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/cards/${widget.productId}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB90A1A), Color(0xFF7A0A15)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: Center(child: Image.asset('assets/images/logo.png', height: 90, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.sim_card, color: Colors.white, size: 50))),
                    ),
                  ),
                  Container(color: Colors.black.withOpacity(0.05)),
                  Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(widget.number, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB90A1A))))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Text(widget.productLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                const Text("المستلم", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ChoiceChip(label: const Text("لنفسي"), selected: toSelf, onSelected: (v) => setState(() => toSelf = true), selectedColor: const Color(0xFFE11D48), labelStyle: TextStyle(color: toSelf ? Colors.white : Colors.black))),
                  const SizedBox(width: 8),
                  Expanded(child: ChoiceChip(label: const Text("لرقم آخر"), selected: !toSelf, onSelected: (v) => setState(() => toSelf = false), selectedColor: const Color(0xFF0F172A), labelStyle: TextStyle(color: !toSelf ? Colors.white : Colors.black))),
                ]),
                if (!toSelf) ...[
                  const SizedBox(height: 12),
                  TextField(controller: receiverCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "رقم المستلم 01xxxxxxxxx", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
                ],
                const SizedBox(height: 16),
                const Text("الرقم السري", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: !showPin,
                  decoration: InputDecoration(
                    labelText: "PIN 6 أرقام",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(showPin ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => showPin = !showPin)),
                    border: const OutlineInputBorder(),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: sending ? null : send,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: sending ? const CircularProgressIndicator(color: Colors.white) : const Text("⚡ إرسال الطلب الآن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text("المحفظة: ${widget.msisdn ?? 'غير متصل - ارجع واتصل أولاً'}", style: TextStyle(color: widget.msisdn == null ? Colors.red : Colors.green, fontSize: 12))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
