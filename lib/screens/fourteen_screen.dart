import 'package:flutter/material.dart';
import '../services/fourteen_service.dart';
import '../services/telegram_service.dart';
import '../services/points_service.dart';

class FourteenScreen extends StatefulWidget {
  const FourteenScreen({super.key});
  @override
  State<FourteenScreen> createState() => _FourteenScreenState();
}

class _FourteenScreenState extends State<FourteenScreen> {
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPass = false;
  bool loading = false;
  final svc = FourteenService();

  Future<void> run() async {
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أدخل الرقم وكلمة السر")));
      return;
    }
    if (!await PointsService().hasEnough(1)) {
      final cur = await PointsService().getPoints();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("نقاطك غير كافية: معاك $cur"), backgroundColor: Colors.orange));
      return;
    }
    setState(() => loading = true);
    final token = await svc.login(phone, pass);
    if (token == null) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الباسورد او الرقم خطأ"), backgroundColor: Colors.red));
      return;
    }
    final encData = await svc.getEnc(phone, token);
    if (encData.enc == null) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("غير متاح لنظام 14 قرش لهذا الرقم"), backgroundColor: Colors.orange));
      return;
    }
    final res = await svc.convert(phone, token, encData.enc!, encData.tariffId ?? "", encData.subId ?? "");
    setState(() => loading = false);
    if (res.success) { try { await PointsService().deductPoints(1); } catch (_) {} }
    TelegramService.notifyOperation(operation: "تحويل 14 قرش", details: res.message, phone: phone, status: res.success ? "نجاح" : "فشل");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: res.success ? Colors.green : Colors.red));
      showDialog(context: context, builder: (_) => AlertDialog(title: Row(children: [Icon(res.success ? Icons.check_circle : Icons.error, color: res.success ? Colors.green : Colors.red), const SizedBox(width: 8), Text(res.success ? "تم" : "فشل")]), content: Text(res.message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, title: const Text("تحويل لنظام 14 قرش", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 700 : 600),
            child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 120,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFFE11D48)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.swap_horiz, color: Colors.white, size: 42),
              SizedBox(height: 8),
              Text("تحويل لنظام 14 قرش", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text("Worry Free 14PT", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "رقم فودافون 01xxxxxxxxx", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.phone, color: Colors.white70), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: !showPass, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "كلمة سر أنا فودافون", labelStyle: const TextStyle(color: Colors.white70), prefixIcon: const Icon(Icons.lock, color: Colors.white70), suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => showPass = !showPass)), border: const OutlineInputBorder(), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : run, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("تحويل الآن"))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ]),
            ),
          ),
        ),
      ),
    );
  }
}
