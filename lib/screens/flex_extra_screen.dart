import 'package:flutter/material.dart';

class FlexExtraScreen extends StatefulWidget {
  const FlexExtraScreen({super.key});
  @override
  State<FlexExtraScreen> createState() => _FlexExtraScreenState();
}

class _FlexExtraScreenState extends State<FlexExtraScreen> {
  final msisdnCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool showPin = false;
  bool loading = false;
  String logs = "";

  void addLog(String m) => setState(() => logs = "[$m]\n$logs");

  Future<void> runFlexExtra() async {
    // TODO: ضع هنا كود سكريبت تزويد يومين لباقة فليكس
    // في انتظار تفاصيل السكريبت من العميل
    setState(() => loading = true);
    addLog("↻ جاري تشغيل تزويد يومين فليكس...");
    await Future.delayed(const Duration(seconds: 1));
    addLog("⚠️ كود السكريبت لم يضاف بعد - ابعت التفاصيل");
    setState(() => loading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("في انتظار كود تزويد يومين من المطور")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text("تزويد يومين لباقة فليكس", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE11D48), width: 2),
            ),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_today, color: Color(0xFFFACC15), size: 48),
              SizedBox(height: 8),
              Text("تزويد يومين لباقة فليكس", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("تمديد الباقة + يومين", style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                TextField(controller: msisdnCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "رقم فودافون 01xxxxxxxxx", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.phone, color: Colors.white70), border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                const SizedBox(height: 12),
                TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 6, obscureText: !showPin, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "PIN 6 أرقام", labelStyle: const TextStyle(color: Colors.white70), prefixIcon: const Icon(Icons.lock, color: Colors.white70), suffixIcon: IconButton(icon: Icon(Icons.visibility, color: Colors.white70), onPressed: null), border: const OutlineInputBorder(), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), counterText: "")),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : runFlexExtra, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15), foregroundColor: Colors.black), child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text("⏰ تزويد يومين الآن"))),
                const SizedBox(height: 8),
                const Text("في انتظار كود السكريبت الأصلي", style: TextStyle(color: Colors.orangeAccent, fontSize: 11), textAlign: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (logs.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Text(logs, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(height: 12),
          const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
