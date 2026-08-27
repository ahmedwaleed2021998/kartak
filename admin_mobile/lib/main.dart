import 'package:flutter/material.dart';
import 'admin_service.dart';

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كروت وشحن - Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE11D48))),
      home: const AdminHome(),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  late TabController tab;

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(children: [
          Image.asset('assets/images/logo.png', width: 32, height: 32, errorBuilder: (_,__,___)=> const Icon(Icons.admin_panel_settings)),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('كروت وشحن - Admin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('ahmed-hartak', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        ]),
        bottom: TabBar(controller: tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: const Color(0xFFE11D48), tabs: const [
          Tab(text: 'إنشاء حساب', icon: Icon(Icons.person_add, size: 18)),
          Tab(text: 'تمديد', icon: Icon(Icons.timer, size: 18)),
          Tab(text: 'المستخدمين', icon: Icon(Icons.people, size: 18)),
        ]),
      ),
      body: TabBarView(controller: tab, children: const [CreateTab(), ExtendTab(), UsersTab()]),
    );
  }
}

class CreateTab extends StatefulWidget {
  const CreateTab({super.key});
  @override
  State<CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<CreateTab> {
  final user = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  final days = TextEditingController(text: '30');
  final hours = TextEditingController(text: '0');
  final minutes = TextEditingController(text: '0');
  bool loading = false;
  String msg = '';
  bool ok = false;

  Future<void> submit() async {
    if (user.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() { msg = 'ادخل المستخدم وكلمة السر'; ok = false; });
      return;
    }
    if (pass.text != confirm.text) {
      setState(() { msg = 'كلمتا السر غير متطابقتين'; ok = false; });
      return;
    }
    final d = int.tryParse(days.text) ?? -1;
    final h = int.tryParse(hours.text) ?? -1;
    final m = int.tryParse(minutes.text) ?? -1;
    if (d < 0 || h < 0 || m < 0 || d + h + m == 0) {
      setState(() { msg = 'المدة يجب أن تكون > 0'; ok = false; });
      return;
    }
    setState(() { loading = true; msg = 'جاري...'; });
    final users = await AdminService.getAllUsers();
    if (users == null) {
      setState(() { msg = 'تعذر الاتصال'; ok = false; loading = false; });
      return;
    }
    if (users.containsKey(user.text.trim())) {
      setState(() { msg = 'المستخدم موجود بالفعل'; ok = false; loading = false; });
      return;
    }
    final (success, message) = await AdminService.registerUser(user.text.trim(), pass.text, d, h, m);
    setState(() { msg = message; ok = success; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('إنشاء حساب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: user, decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 10),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
        const SizedBox(height: 10),
        TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة السر', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 16),
        const Text('المدة', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          Expanded(child: TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أيام', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ساعات', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'دقائق', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('إنشاء حساب'))),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(color: ok ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class ExtendTab extends StatefulWidget {
  const ExtendTab({super.key});
  @override
  State<ExtendTab> createState() => _ExtendTabState();
}

class _ExtendTabState extends State<ExtendTab> {
  final user = TextEditingController();
  final days = TextEditingController(text: '0');
  final hours = TextEditingController(text: '0');
  final minutes = TextEditingController(text: '0');
  bool loading = false;
  String msg = '';
  bool ok = false;

  Future<void> submit() async {
    if (user.text.trim().isEmpty) {
      setState(() { msg = 'ادخل اسم المستخدم'; ok = false; });
      return;
    }
    final d = int.tryParse(days.text) ?? -1;
    final h = int.tryParse(hours.text) ?? -1;
    final m = int.tryParse(minutes.text) ?? -1;
    if (d < 0 || h < 0 || m < 0 || d + h + m == 0) {
      setState(() { msg = 'المدة يجب أن تكون > 0'; ok = false; });
      return;
    }
    setState(() { loading = true; msg = 'جاري...'; });
    final (success, message) = await AdminService.renewUser(user.text.trim(), d, h, m);
    setState(() { msg = message; ok = success; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('تمديد الاشتراك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: user, decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 16),
        const Text('المدة الإضافية', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          Expanded(child: TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أيام', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ساعات', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'دقائق', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white), child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('تمديد'))),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(color: ok ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  Map<String, dynamic>? users;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() { loading = true; error = null; });
    final data = await AdminService.getAllUsers();
    if (data == null) {
      setState(() { error = 'تعذر الاتصال'; loading = false; });
    } else {
      setState(() { users = data; loading = false; });
    }
  }

  String statusText(Map<String, dynamic> user) {
    final expires = user['expires'] as int?;
    if (expires == null) return 'بدون انتهاء';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expires > now) {
      final days = (expires - now) / 86400;
      return 'نشط (${days.toStringAsFixed(1)} يوم متبقي)';
    }
    return 'منتهي';
  }

  Color statusColor(Map<String, dynamic> user) {
    final expires = user['expires'] as int?;
    if (expires == null) return Colors.grey;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expires > now ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), const SizedBox(height: 10), ElevatedButton(onPressed: refresh, child: const Text('إعادة المحاولة'))]));
    if (users == null || users!.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('لا يوجد مستخدمين'), const SizedBox(height: 10), ElevatedButton(onPressed: refresh, child: const Text('تحديث'))]));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Text('${users!.length} مستخدم', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('تحديث')),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: users!.length,
          itemBuilder: (c, i) {
            final name = users!.keys.elementAt(i);
            final user = users![name] is Map ? Map<String, dynamic>.from(users![name]) : <String, dynamic>{'password': users![name].toString()};
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: statusColor(user), child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(statusText(user), style: TextStyle(color: statusColor(user))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showUserDialog(name),
              ),
            );
          },
        ),
      ),
    ]);
  }

  void showUserDialog(String username) {
    final pwNew = TextEditingController();
    final pwConfirm = TextEditingController();
    final d = TextEditingController(text: '0');
    final h = TextEditingController(text: '0');
    final m = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        bool pwLoading = false;
        String pwMsg = '';
        bool pwOk = false;
        bool extLoading = false;
        String extMsg = '';
        bool extOk = false;

        return AlertDialog(
          title: Text(username, textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تغيير كلمة السر', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: pwNew, obscureText: true, decoration: const InputDecoration(labelText: 'جديدة', border: OutlineInputBorder())),
              const SizedBox(height: 6),
              TextField(controller: pwConfirm, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد', border: OutlineInputBorder())),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: pwLoading
                    ? null
                    : () async {
                        if (pwNew.text.isEmpty) {
                          setState(() { pwMsg = 'ادخل كلمة السر'; pwOk = false; });
                          return;
                        }
                        if (pwNew.text != pwConfirm.text) {
                          setState(() { pwMsg = 'غير متطابقتين'; pwOk = false; });
                          return;
                        }
                        setState(() { pwLoading = true; pwMsg = 'جاري...'; });
                        final (ok, msg) = await AdminService.changePassword(username, pwNew.text);
                        setState(() { pwMsg = msg; pwOk = ok; pwLoading = false; });
                        if (ok) refresh();
                      },
                child: pwLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
              ),
              Text(pwMsg, style: TextStyle(color: pwOk ? Colors.green : Colors.red, fontSize: 12)),
              const Divider(),
              const Text('إضافة وقت', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [
                Expanded(child: TextField(controller: d, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أيام', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ساعات', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: m, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'دقائق', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: extLoading
                    ? null
                    : () async {
                        final dd = int.tryParse(d.text) ?? -1;
                        final hh = int.tryParse(h.text) ?? -1;
                        final mm = int.tryParse(m.text) ?? -1;
                        if (dd < 0 || hh < 0 || mm < 0 || dd + hh + mm == 0) {
                          setState(() { extMsg = 'مدة > 0'; extOk = false; });
                          return;
                        }
                        setState(() { extLoading = true; extMsg = 'جاري...'; });
                        final (ok, msg) = await AdminService.renewUser(username, dd, hh, mm);
                        setState(() { extMsg = msg; extOk = ok; extLoading = false; });
                        if (ok) refresh();
                      },
                child: extLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تمديد'),
              ),
              Text(extMsg, style: TextStyle(color: extOk ? Colors.green : Colors.red, fontSize: 12)),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('حذف؟'), content: Text('حذف $username؟'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))]));
                  if (ok == true) {
                    final (success, msg) = await AdminService.deleteUser(username);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red));
                    if (success) {
                      if (context.mounted) Navigator.pop(context);
                      refresh();
                    }
                  }
                },
                child: const Text('حذف الحساب'),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
        );
      }),
    );
  }
}
