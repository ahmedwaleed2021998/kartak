import 'package:flutter/material.dart';
import '../services/flex_service.dart';
import '../services/telegram_service.dart';
import '../services/points_service.dart';

class FlexExtraScreen extends StatefulWidget {
  const FlexExtraScreen({super.key});
  @override
  State<FlexExtraScreen> createState() => _FlexExtraScreenState();
}

class _FlexExtraScreenState extends State<FlexExtraScreen> {
  final msisdnCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPass = false;
  bool loading = false;
  String logs = "";
  final flex = FlexService();

  void addLog(String m) => setState(() => logs = "[$m]\n$logs");

  Future<void> runFlexExtra() async {
    final rawPhone = msisdnCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (rawPhone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أدخل الرقم وكلمة السر")));
      return;
    }
    final phone = flex.normalizePhone(rawPhone);
    setState(() => loading = true);
    logs = "";
    addLog("جاري تسجيل الدخول...");
    final token = await flex.login(phone, pass);
    if (token == null) {
      addLog("فشل تسجيل الدخول");
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل تسجيل الدخول - تأكد من الرقم وكلمة السر"), backgroundColor: Colors.red));
      return;
    }
    addLog("تم تسجيل الدخول بنجاح");
    addLog("جاري جلب الكود المشفر...");
    final enc = await flex.getEncProductId(phone, token);
    if (enc == null) {
      addLog("خدمة تزويد اليومين غير متاحة لرقمك حالياً");
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خدمة تزويد اليومين غير متاحة لرقمك حالياً"), backgroundColor: Colors.orange));
      return;
    }
    addLog("تم العثور على الكود: $enc");
    addLog("جاري تفعيل خدمة تزويد اليومين...");
    final res = await flex.activateRollover(phone, token, enc);
    addLog(res.message);
    setState(() => loading = false);
    TelegramService.notifyOperation(operation: "تزويد يومين فليكس", details: res.message, phone: phone, status: res.success ? "نجاح" : "فشل");
    if (res.success) { try { await PointsService().addPointsForCurrentUser(5); } catch (_) {} }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: res.success ? Colors.green : Colors.red));
      showDialog(context: context, builder: (_) => AlertDialog(title: Row(children: [Icon(res.success ? Icons.check_circle : Icons.error, color: res.success ? Colors.green : Colors.red), const SizedBox(width: 8), Text(res.success ? "تم التفعيل" : "فشل")]), content: Text(res.success ? res.message : "${res.message}\n\n${res.body ?? ''}".substring(0, (res.body ?? '').length > 300 ? 300 : (res.body ?? '').length)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text("تزويد يومين لباقة فليكس", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 700 : 600),
            child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
            ),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_today, color: Color(0xFFFACC15), size: 42),
              SizedBox(height: 8),
              Text("تزويد يومين لباقة فليكس", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text("تمديد الباقة + يومين", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("بيانات فليكس", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: msisdnCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "رقم فودافون 01xxxxxxxxx", hintText: "مثال: 01098786582", hintStyle: TextStyle(color: Colors.white30, fontSize: 11), labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.phone, color: Colors.white70), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: !showPass, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "كلمة سر أنا فودافون", labelStyle: const TextStyle(color: Colors.white70), prefixIcon: const Icon(Icons.lock, color: Colors.white70), suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => showPass = !showPass)), border: const OutlineInputBorder(), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : runFlexExtra, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15), foregroundColor: Colors.black), child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text("⏰ تزويد يومين الآن", style: TextStyle(fontWeight: FontWeight.bold)))),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ]),
            ),
          ),
        ),
      ),
    );
  }
}
