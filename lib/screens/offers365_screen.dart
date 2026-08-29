import 'package:flutter/material.dart';
import '../services/offers365_service.dart';
import '../services/telegram_service.dart';

class Offers365Screen extends StatefulWidget {
  const Offers365Screen({super.key});
  @override
  State<Offers365Screen> createState() => _Offers365ScreenState();
}

class _Offers365ScreenState extends State<Offers365Screen> {
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPass = false;
  bool loadingLogin = false;
  bool loadingOffers = false;
  String? token;
  List<dynamic> offers = [];
  final svc = Offers365Service();

  Future<void> doLogin() async {
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أدخل الرقم وكلمة السر")));
      return;
    }
    setState(() => loadingLogin = true);
    try {
      final t = await svc.login(phone, pass);
      setState(() { token = t; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تسجيل الدخول بنجاح"), backgroundColor: Colors.green));
      await fetchOffers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: Colors.red));
      if (e.toString().contains("401")) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الباسورد او الرقم خطأ"), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => loadingLogin = false);
    }
  }

  Future<void> fetchOffers() async {
    if (token == null) return;
    setState(() => loadingOffers = true);
    try {
      final list = await svc.getOffers(phoneCtrl.text.trim(), token!);
      setState(() => offers = list);
      if (list.isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد عروض متاحة")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل جلب العروض: $e")));
    } finally {
      setState(() => loadingOffers = false);
    }
  }

  Future<void> subscribe(String offerId, String desc) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text("تأكيد الاشتراك"), content: Text(desc), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("اشتراك"))]));
    if (ok != true) return;
    final res = await svc.subscribe(phoneCtrl.text.trim(), token!, offerId);
    TelegramService.notifyOperation(operation: "عروض 365", details: "$desc - ${res.message}", phone: phoneCtrl.text.trim(), status: res.success ? "نجاح" : "فشل");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: res.success ? Colors.green : Colors.red));
      showDialog(context: context, builder: (_) => AlertDialog(title: Row(children: [Icon(res.success ? Icons.check_circle : Icons.error, color: res.success ? Colors.green : Colors.red), const SizedBox(width: 8), Text(res.success ? "تم" : "فشل")]), content: Text(res.message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))]));
    }
  }

  String _getDesc(dynamic offer) => offer['description']?.toString() ?? offer['desc']?.toString() ?? "عرض 365";
  String _getPrice(dynamic offer) {
    try {
      final p = offer['pattern']?[0]?['price']?['value']?.toString();
      if (p != null) return p;
      final price = offer['pattern']?[0]?['price']?['value']?.toString();
      return price ?? "غير معروف";
    } catch (_) { return "غير معروف"; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, title: const Text("عروض 365", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 120,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF7A0A15)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.card_giftcard, color: Color(0xFFFACC15), size: 42),
              SizedBox(height: 8),
              Text("عروض 365 - فودافون", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text("JOKS 365 OFFERS", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ),
          const SizedBox(height: 16),
          if (token == null) ...[
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
                  SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loadingLogin ? null : doLogin, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: loadingLogin ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("تسجيل الدخول"))),
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
            if (!loadingOffers && offers.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text("لا توجد عروض متاحة حالياً", style: TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center)),
            ...offers.asMap().entries.map((e) {
              final idx = e.key + 1;
              final o = e.value;
              final desc = _getDesc(o);
              final id = o['id']?.toString() ?? "";
              String price = "غير معروف";
              String action = "";
              try {
                final pat = o['pattern']?[0];
                price = pat?['price']?['value']?.toString() ?? "غير معروف";
                action = pat?['action']?[0]?['actionValue']?.toString() ?? "";
              } catch (_) {}
              IconData icon = Icons.card_giftcard;
              if (desc.contains("إنترنت") || desc.contains("Internet")) icon = Icons.wifi;
              else if (desc.contains("فليكس") || desc.contains("Flex")) icon = Icons.battery_charging_full;
              else if (desc.contains("دقيقة")) icon = Icons.phone;
              return Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24, width: 0.5)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(6)), child: Text("$idx", style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Icon(icon, color: const Color(0xFFFACC15), size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(desc.length > 60 ? "${desc.substring(0, 60)}..." : desc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.attach_money, color: Colors.greenAccent, size: 14),
                      Text(" $price جنيه", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      if (action.isNotEmpty) ...[const SizedBox(width: 12), const Icon(Icons.data_usage, color: Colors.white70, size: 14), Text(" $action", style: const TextStyle(color: Colors.white70, fontSize: 11))],
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, height: 36, child: ElevatedButton(onPressed: () => subscribe(id, desc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: const Text("اشتراك", style: TextStyle(fontSize: 12)))),
                  ]),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
