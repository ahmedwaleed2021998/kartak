import 'package:flutter/material.dart';
import '../services/vodafone_service.dart';
import '../services/recharge_balance_service.dart';
import '../services/telegram_service.dart';

class RechargeBalanceScreen extends StatefulWidget {
  const RechargeBalanceScreen({super.key});
  @override
  State<RechargeBalanceScreen> createState() => _RechargeBalanceScreenState();
}

class _RechargeBalanceScreenState extends State<RechargeBalanceScreen> {
  final receiverCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool showPin = false;
  bool loading = false;
  String? msisdn;
  String? token;
  bool connecting = false;
  final vodafone = VodafoneService();
  final rechargeSvc = RechargeBalanceService();

  Future<void> connect() async {
    setState(() => connecting = true);
    try {
      final res = await vodafone.getSeamless().timeout(const Duration(seconds: 10));
      final t = await vodafone.getToken(res.seamless).timeout(const Duration(seconds: 10));
      setState(() { msisdn = res.msisdn; token = t; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الاتصال: $msisdn"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل الاتصال: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => connecting = false);
    }
  }

  Future<void> doRecharge() async {
    final receiver = receiverCtrl.text.trim();
    final amountStr = amountCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (!(receiver.startsWith("01") && receiver.length == 11)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رقم المستلم خطأ")));
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المبلغ غير صحيح")));
      return;
    }
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN 6 أرقام")));
      return;
    }
    if (msisdn == null || token == null) {
      await connect();
      if (msisdn == null || token == null) return;
    }
    setState(() => loading = true);
    final res = await rechargeSvc.recharge(token: token!, senderMsisdn: msisdn!, receiverNumber: receiver, amount: amount, pin: pin);
    setState(() => loading = false);
    TelegramService.notifyOperation(operation: "شحن رصيد عادي", details: "$amount جنيه إلى $receiver - ${res.success ? 'نجاح' : 'فشل: ${res.data}'}", phone: msisdn, status: res.success ? "نجاح" : "فشل");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.success ? "تم شحن $amount جنيه إلى $receiver" : "فشل: ${res.data}"), backgroundColor: res.success ? Colors.green : Colors.red));
      showDialog(context: context, builder: (_) => AlertDialog(title: Row(children: [Icon(res.success ? Icons.check_circle : Icons.error, color: res.success ? Colors.green : Colors.red), const SizedBox(width: 8), Text(res.success ? "تم الشحن" : "فشل")]), content: Text(res.success ? "تم شحن $amount جنيه إلى $receiver" : "${res.data}"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = msisdn != null && token != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, title: const Text("شحن رصيد", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 120,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF25D366)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 42),
              SizedBox(height: 8),
              Text("شحن رصيد عادي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text("إلى أي رقم فودافون", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("الاتصال بالمحفظة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(connected ? "✓ $msisdn" : "غير متصل", style: TextStyle(color: connected ? Colors.greenAccent : Colors.white60, fontSize: 12))),
                  ElevatedButton(onPressed: connecting ? null : connect, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: connecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("اتصال")),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: receiverCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "رقم المستلم 01xxxxxxxxx", prefixIcon: Icon(Icons.phone, color: Colors.white70), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 12),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "المبلغ بالجنيه", prefixIcon: Icon(Icons.attach_money, color: Colors.white70), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 12),
                TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 6, obscureText: !showPin, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "PIN 6 أرقام", prefixIcon: const Icon(Icons.lock, color: Colors.white70), suffixIcon: IconButton(icon: Icon(showPin ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => showPin = !showPin)), border: const OutlineInputBorder(), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), counterText: "")),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : doRecharge, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("شحن الآن"))),
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
