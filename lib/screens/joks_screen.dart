import 'package:flutter/material.dart';
import '../services/joks_service.dart';
import '../services/telegram_service.dart';
import '../services/points_service.dart';

class JoksScreen extends StatefulWidget {
  const JoksScreen({super.key});
  @override
  State<JoksScreen> createState() => _JoksScreenState();
}

class _JoksScreenState extends State<JoksScreen> {
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPass = false;
  bool loadingLogin = false;
  bool loadingOffers = false;
  bool purchasing = false;
  String? token;
  List<Map<String, dynamic>> offers = [];
  String logs = "";

  final joks = JoksService();

  void addLog(String m) => setState(() => logs = "[$m]\n$logs");

  Future<void> doLogin() async {
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أدخل الرقم وكلمة السر")));
      return;
    }
    setState(() => loadingLogin = true);
    addLog("جاري تسجيل الدخول...");
    final res = await joks.loginVodafone(phone, pass);
    setState(() => loadingLogin = false);
    addLog(res.message);
    if (res.success && res.token != null) {
      setState(() {
        token = res.token;
        offers = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.green));
      await fetchOffers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.red));
    }
  }

  Future<void> fetchOffers() async {
    if (token == null) return;
    setState(() => loadingOffers = true);
    addLog("جاري جلب العروض...");
    final phone = phoneCtrl.text.trim();
    final data = await joks.getDiscountOffers(token!, phone);
    if (data.isEmpty) {
      addLog("لا توجد عروض متاحة");
      setState(() => loadingOffers = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد عروض متاحة"), backgroundColor: Colors.orange));
      return;
    }
    final all = joks.extractAllDiscountOffers(data);
    setState(() => offers = all);
    setState(() => loadingOffers = false);
    addLog("تم العثور على ${all.length} عرض");
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لم يتم العثور على عروض خصم")));
    }
  }

  Future<void> purchase(Map<String, dynamic> offer) async {
    final phone = phoneCtrl.text.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد التفعيل"),
        content: Text("الباقة: ${offer['bundle_name']}\nالوصف: ${offer['desc']}\nالسعر الأصلي: ${offer['original_price']} جنيه\nسعر الخصم: ${offer['discounted_price']} جنيه\nنسبة الخصم: ${(offer['discount_percentage'] as double).toStringAsFixed(1)}%"),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("تفعيل"))],
      ),
    );
    if (confirm != true) return;
    setState(() => purchasing = true);
    addLog("جاري تفعيل ${offer['bundle_name']}...");
    final res = await joks.purchaseDiscountOffer(token!, phone, offer);
    setState(() => purchasing = false);
    addLog(res.message);
    TelegramService.notifyOperation(operation: "JoKs خصم 50%", details: "${offer['bundle_name']} - ${offer['discounted_price']}ج بدل ${offer['original_price']}ج - ${res.message}", phone: phone, status: res.success ? "نجاح" : "فشل");
    if (res.success) {
      try { await PointsService().addPointsForCurrentUser(15); } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.green));
      showDialog(context: context, builder: (_) => AlertDialog(title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("تم التفعيل")]), content: Text(res.message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))]));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.red));
      showDialog(context: context, builder: (_) => AlertDialog(title: const Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 8), Text("فشل")]), content: Text(res.message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))]));
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
        title: const Text("خصم 50% باقات فليكس فودافون", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 750 : 600),
            child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF7A0A15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.local_offer, color: Colors.white, size: 42),
              SizedBox(height: 8),
              Text("خصم 50% باقات فليكس فودافون", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ])),
          ),
          const SizedBox(height: 16),
          if (token == null) ...[
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("تسجيل دخول فودافون", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "رقم فودافون 01xxxxxxxxx", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.phone, color: Colors.white70), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                  const SizedBox(height: 12),
                  TextField(controller: passCtrl, obscureText: !showPass, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "كلمة سر أنا فودافون", labelStyle: const TextStyle(color: Colors.white70), prefixIcon: const Icon(Icons.lock, color: Colors.white70), suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => showPass = !showPass)), border: const OutlineInputBorder(), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loadingLogin ? null : doLogin, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: loadingLogin ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("تسجيل الدخول وجلب العروض"))),
                ]),
              ),
            ),
          ] else ...[
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("مسجل: ${phoneCtrl.text}", style: const TextStyle(color: Colors.greenAccent, fontSize: 13))),
                  TextButton(onPressed: () => setState(() { token = null; offers = []; }), child: const Text("خروج", style: TextStyle(color: Colors.white70))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (loadingOffers) const Center(child: CircularProgressIndicator()),
            if (!loadingOffers && offers.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text("لا توجد عروض خصم متاحة لهذا الرقم", style: TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center)),
            ...offers.asMap().entries.map((e) {
              final idx = e.key;
              final o = e.value;
              final isHalf = o['is_half_price'] == true;
              return Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isHalf ? const Color(0xFFFACC15) : Colors.white24, width: isHalf ? 1.5 : 0.5)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isHalf ? const Color(0xFFFACC15) : Colors.white24, borderRadius: BorderRadius.circular(6)), child: Text("${idx + 1}", style: TextStyle(color: isHalf ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o['bundle_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                      if (isHalf) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)), child: const Text("نصف السعر!", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 6),
                    Text(o['desc'], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text("الأصلي: ${o['original_price']} ج", style: const TextStyle(color: Colors.grey, fontSize: 11, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 8),
                      Text("${o['discounted_price']} ج", style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text("${(o['discount_percentage'] as double).toStringAsFixed(1)}% خصم", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, height: 40, child: ElevatedButton(onPressed: purchasing ? null : () => purchase(o), style: ElevatedButton.styleFrom(backgroundColor: isHalf ? const Color(0xFFE11D48) : const Color(0xFFFACC15), foregroundColor: isHalf ? Colors.white : Colors.black), child: purchasing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text("تفعيل خصم ${o['discount_amount']} ج"))),
                  ]),
                ),
              );
            }),
          ],
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
