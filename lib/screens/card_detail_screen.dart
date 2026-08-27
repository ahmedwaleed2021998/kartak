import 'package:flutter/material.dart';
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
    widget.onLog("↻ إرسال ${widget.productLabel} إلى $receiver ... (حد أقصى 15 ث)");
    Map<String, dynamic>? resp;
    bool timedOut = false;
    try {
      final vodafone = VodafoneService();
      // حد أقصى 15 ثانية ثم اعتبره نجاح كما طلب العميل
      resp = await vodafone
          .sendOrder(productId: widget.productId, receiver: receiver, pin: pin, msisdn: widget.msisdn!, token: widget.token!)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        timedOut = true;
        return {'code': '0000', 'orderTotalPrice': null, '_httpStatus': 200, '_timeout': true};
      });
    } catch (e) {
      // لو Timeout من http نفسه
      if (e.toString().contains('Timeout')) {
        timedOut = true;
        resp = {'code': '0000', '_httpStatus': 200, '_timeout': true};
      } else {
        widget.onLog("✗ خطأ: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
        if (mounted) setState(() => sending = false);
        return;
      }
    }

    final isTimeoutSuccess = timedOut;
    final code = resp?['code'];
    final status = resp?['_httpStatus'];
    final isSuccess = isTimeoutSuccess || (status == 200 && (code == "0000" || resp?['orderTotalPrice'] != null));

    // حفظ
    try {
      await firestore.saveOrder(productName: widget.productLabel, productId: widget.productId, sender: widget.msisdn!, receiver: receiver, status: isSuccess ? "success" : "failed", serverResponse: resp ?? {});
    } catch (_) {}

    if (isSuccess) {
      final msg = isTimeoutSuccess ? "تم شحن الكارت" : "تم بنجاح! ${resp?['orderTotalPrice'] ?? ''} جنيه";
      widget.onLog("✓✓✓ $msg");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
        // رسالة كبيرة
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('تم شحن الكارت')]),
            content: Text(isTimeoutSuccess ? 'تم إرسال الطلب بنجاح\n${widget.productLabel}\nإلى: $receiver' : 'تم شحن ${widget.productLabel} بنجاح'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } else {
      final err = resp?['reason'] ?? resp?['message'] ?? 'غير معروف';
      widget.onLog("✗ فشل: $err (كود $code)");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل: $err"), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => sending = false);
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
