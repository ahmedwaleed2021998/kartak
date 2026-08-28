import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/vodafone_service.dart';
import '../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../services/device_service.dart';
import '../services/security_service.dart';
import '../services/favorites_service.dart';
import '../services/theme_provider.dart';
import '../services/version_service.dart';
import 'card_detail_screen.dart';
import 'joks_screen.dart';
import 'flex_extra_screen.dart';

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
  int? _expiresAt;
  String _subRemaining = "";
  DateTime? _expiresDate;
  final searchCtrl = TextEditingController();
  String searchQuery = "";
  Set<String> favIds = {};

  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    _loadFavs();
    searchCtrl.addListener(() => setState(() => searchQuery = searchCtrl.text.trim()));
    _checkForceUpdate();
  }

  Future<void> _loadFavs() async {
    favIds = await FavoritesService.getFavorites();
    if (mounted) setState(() {});
  }

  Future<void> _toggleFav(String pid) async {
    await FavoritesService.toggle(pid);
    favIds = await FavoritesService.getFavorites();
    if (mounted) setState(() {});
  }

  void addLog(String m) => setState(() => logs.insert(0, "[${TimeOfDay.now().format(context)}] $m"));

  String _formatRemaining(int seconds) {
    if (seconds <= 0) return "منتهي";
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return "متبقي $d يوم${d > 1 ? '' : ''}${h > 0 ? " و $h ساعة" : ""}";
    if (h > 0) return "متبقي $h ساعة و $m دقيقة";
    if (m > 0) return "متبقي $m دقيقة";
    return "متبقي أقل من دقيقة";
  }

  Future<void> _checkSubscription() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      setState(() => checkingSub = false);
      return;
    }
    // تحقق انتهاء الاشتراك + حساب الباقي
    try {
      final key = email.trim().toLowerCase().replaceAll('.', ',');
      final url = Uri.parse('https://ahmed-hartak-default-rtdb.firebaseio.com/users/${Uri.encodeComponent(key)}.json');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.body != 'null' && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        final expires = data is Map ? data['expires'] as int? : null;
        if (expires != null) {
          _expiresAt = expires;
          _expiresDate = DateTime.fromMillisecondsSinceEpoch(expires * 1000);
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
          } else {
            final rem = expires - nowTs;
            _subRemaining = _formatRemaining(rem);
          }
        } else {
          _subRemaining = "اشتراك مفتوح";
        }
      } else {
        _subRemaining = "اشتراك غير محدد";
      }
    } catch (_) {
      _subRemaining = "";
    }
    // فحص الأمان - محاكي
    if (await SecurityService.isEmulator()) {
      setState(() {
        expired = true;
        checkingSub = false;
        _subRemaining = "محاكي غير مدعوم";
      });
      if (mounted) _showSecurityBlockDialog("التطبيق لا يعمل على المحاكي - استخدم جهاز حقيقي");
      return;
    }
    if (await SecurityService.isRooted()) {
      addLog("تحذير: جهاز مكسور الحماية");
    }
    // تحقق ربط الجهاز - إيميل = جهاز واحد فقط
    final emailForDevice = FirebaseAuth.instance.currentUser?.email;
    if (emailForDevice != null) {
      final deviceCheck = await DeviceService.checkAndBindDevice(emailForDevice);
      if (!deviceCheck.$1) {
        setState(() {
          expired = true;
          checkingSub = false;
        });
        if (mounted) _showDeviceBlockedDialog(deviceCheck.$2);
        return;
      }
    }
    if (mounted) setState(() => checkingSub = false);
  }

  Future<void> _checkForceUpdate() async {
    try {
      final remote = await VersionService.fetchRemote();
      if (remote == null) return;
      final latest = remote['latest']?.toString() ?? "";
      final force = remote['force'] == true;
      final url = remote['url']?.toString() ?? "https://github.com/ahmedwaleed2021998/kartak/releases";
      if (latest.isEmpty || !force) return;
      final current = await VersionService.getCurrentVersion();
      if (VersionService.compareBuild(current, latest) <= 0) return;
      if (mounted) _showForceUpdateDialog(latest, url);
    } catch (_) {}
  }

  void _showForceUpdateDialog(String latest, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(children: [Icon(Icons.system_update, color: Colors.red), SizedBox(width: 8), Text("تحديث إجباري")]),
          content: Text("يجب تحديث التطبيق إلى الإصدار $latest للمتابعة\nلن يعمل البرنامج بدون التحديث"),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
              onPressed: () async {
                final uri = Uri.parse(url);
                try { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } catch (_) {}
                try { if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return; } catch (_) {}
                await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true, enableDomStorage: true));
              },
              icon: const Icon(Icons.download),
              label: const Text("تحديث الآن"),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceBlockedDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(children: [Icon(Icons.phonelink_erase, color: Colors.red), SizedBox(width: 8), Text('الجهاز غير مصرح')]),
          content: Text('هذا الإيميل مربوط بجهاز آخر\n$msg\nتواصل مع المطور لفك الربط', style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); if (context.mounted) Navigator.of(context).pop(); }, child: const Text('خروج')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
              onPressed: () async {
                final uri = Uri.parse('https://api.whatsapp.com/send?phone=201208739523&text=مرحبا%20مطور%20كروت%20وشحن%20إيميلي%20مربوط%20بجهاز%20آخر%20-%20${FirebaseAuth.instance.currentUser?.email ?? ''}');
                try { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } catch (_) {}
                await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true, enableDomStorage: true));
              },
              icon: const Icon(Icons.chat),
              label: const Text('تواصل لفك الربط'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityBlockDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(children: [Icon(Icons.security, color: Colors.red), SizedBox(width: 8), Text('جهاز غير مدعوم')]),
          content: Text(msg, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); if (context.mounted) Navigator.of(context).pop(); }, child: const Text('خروج')),
          ],
        ),
      ),
    );
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
                final uri = Uri.parse('https://api.whatsapp.com/send?phone=201208739523&text=مرحبا%20مطور%20كروت%20وشحن%20اشتراكي%20انتهى%20-%20${FirebaseAuth.instance.currentUser?.email ?? ''}');
                try { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } catch (_) {}
                try { if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return; } catch (_) {}
                await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true, enableDomStorage: true));
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
    final uri = Uri.parse('https://api.whatsapp.com/send?phone=201208739523&text=مرحبا%20مطور%20كروت%20وشحن%20اشتراكي%20انتهى%20-%20${FirebaseAuth.instance.currentUser?.email ?? ''}');
    try { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } catch (_) {}
    try { if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return; } catch (_) {}
    await launchUrl(uri, mode: LaunchMode.inAppWebView, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true, enableDomStorage: true));
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

  void openCard(String productId, String productName, String number) {
    if (msisdn == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اتصل بالمحفظة أولاً"), backgroundColor: Colors.orange));
      return;
    }
    final label = "$number - $productName";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(
          productId: productId,
          productLabel: label,
          productName: productName,
          number: number,
          msisdn: msisdn,
          token: token,
          onLog: addLog,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = msisdn != null && token != null;
    final fakkaProducts = VodafoneService.products.where((p) => p.$2.contains("فكة")).toList();
    final maredProducts = VodafoneService.products.where((p) => p.$2.contains("مارد")).toList();

    Widget buildGrid(List<(String, String, String)> items) {
      // فلترة بحث ومفضلة
      List<(String, String, String)> filtered = items;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        filtered = items.where((p) => p.$2.toLowerCase().contains(q) || p.$3.toLowerCase().contains(q) || p.$1.contains(q)).toList();
        if (filtered.isEmpty) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("لا توجد نتائج", style: TextStyle(color: Colors.white70))));
        }
      } else if (favIds.isNotEmpty) {
        filtered = [...items.where((p) => favIds.contains(p.$3)), ...items.where((p) => !favIds.contains(p.$3))];
      }
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, idx) {
          final p = filtered[idx];
          final pid = p.$3;
          final name = p.$2;
          final number = p.$1;
          final unitsText = VodafoneService.getUnits(pid);
          final isFakka = name.contains("فكة");
          final isMared = name.contains("مارد");
          return InkWell(
            onTap: () => openCard(pid, name, number),
            borderRadius: BorderRadius.circular(16),
            child: Card(
              color: const Color(0xFF1E293B),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/cards/$pid.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                        ),
                        Container(color: Colors.black.withOpacity(0.12)),
                        Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(number, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB90A1A))))),
                        Positioned(top: 6, left: 6, child: InkWell(onTap: () => _toggleFav(pid), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle), child: Icon(favIds.contains(pid) ? Icons.star : Icons.star_border, color: favIds.contains(pid) ? Colors.amber : Colors.white70, size: 14)))),
                        Positioned(bottom: 6, left: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)), child: Text(isFakka ? "وحدات فكة" : isMared ? name.split(" ").last : "رصيد", textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (unitsText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(unitsText, style: const TextStyle(color: Color(0xFFFACC15), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.touch_app, color: Colors.white, size: 14), SizedBox(width: 4), Text("اضغط للشحن", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]),
                      ),
                      if (!connected) const Padding(padding: EdgeInsets.only(top: 4), child: Text("غير متصل", style: TextStyle(color: Colors.red, fontSize: 9))),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        },
      );
    }

    final connectionCard = Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("① الاتصال بالمحفظة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("لازم داتا فودافون أو VPN", style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(connected ? "✓ $msisdn" : "● غير متصل", style: TextStyle(color: connected ? Colors.greenAccent : Colors.white60, fontWeight: FontWeight.bold))),
            ElevatedButton(onPressed: connecting ? null : connect, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: connecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("↻ اتصال")),
          ]),
          if (connected) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)), child: Row(children: [const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16), const SizedBox(width: 6), Expanded(child: Text("رقم المحفظة: $msisdn - الجلسة نشطة", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)))])),
          if (!connected) const Padding(padding: EdgeInsets.only(top: 8), child: Text("⚠️ اتصل أولاً ثم اضغط على أي كارت", style: TextStyle(color: Colors.orangeAccent, fontSize: 11))),
        ]),
      ),
    );

    if (checkingSub) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
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
        body: const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      );
    }
    if (expired) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
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
        body: Center(
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
        actions: [
          Consumer<ThemeProvider>(builder: (_, th, __) => IconButton(tooltip: th.isDark ? "وضع نهاري" : "وضع ليلي", onPressed: () => th.toggle(), icon: Icon(th.isDark ? Icons.light_mode : Icons.dark_mode))),
          IconButton(onPressed: () async => await FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          connectionCard,
          if (_subRemaining.isNotEmpty) const SizedBox(height: 8),
          if (_subRemaining.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFACC15), width: 1)),
              child: Row(children: [
                const Icon(Icons.timer_outlined, color: Color(0xFFFACC15), size: 16),
                const SizedBox(width: 6),
                Text("الاشتراك: $_subRemaining", style: const TextStyle(color: Color(0xFFFACC15), fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_expiresDate != null) Text("ينتهي: ${_expiresDate!.day}/${_expiresDate!.month}/${_expiresDate!.year}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoksScreen())),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF7A0A15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(children: [
                    Icon(Icons.local_offer, color: Colors.white, size: 28),
                    SizedBox(height: 6),
                    Text("خصم 50% باقات فليكس فودافون", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FlexExtraScreen())),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.fromBorderSide(BorderSide(color: Color(0xFFFACC15), width: 1.5)),
                  ),
                  child: const Column(children: [
                    Icon(Icons.calendar_today, color: Color(0xFFFACC15), size: 28),
                    SizedBox(height: 6),
                    Text("تزويد يومين", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                    Text("لباقة فليكس", style: TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "بحث سريع - فكة 10 أو مارد...",
              hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
              suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.white70, size: 18), onPressed: () => searchCtrl.clear()) : (favIds.isNotEmpty ? const Icon(Icons.star, color: Colors.amber, size: 18) : null),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          // فكة - القائمة كلها تنزل مع بعض
          Row(children: const [Icon(Icons.credit_card, color: Color(0xFFE11D48), size: 18), SizedBox(width: 6), Text("كروت فكة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]),
          const SizedBox(height: 8),
          buildGrid(fakkaProducts),
          const SizedBox(height: 16),
          Row(children: const [Icon(Icons.phone_in_talk, color: Color(0xFFFACC15), size: 18), SizedBox(width: 6), Text("باقات مارد", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]),
          const SizedBox(height: 8),
          buildGrid(maredProducts),
          const SizedBox(height: 16),
          const Text("المطور AHMED_ELDEEP", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text("كروت وشحن © 2026", style: TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
      ),
    );
  }
}
