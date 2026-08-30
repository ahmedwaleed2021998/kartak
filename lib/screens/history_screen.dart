import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatDate(Timestamp? ts, String? iso) {
    DateTime? d;
    if (ts != null) d = ts.toDate();
    else if (iso != null) d = DateTime.tryParse(iso);
    if (d == null) return "-";
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, title: const Text("سجل العمليات", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 750 : 600),
            child: StreamBuilder<QuerySnapshot>(
              stream: svc.ordersStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text("خطأ: ${snap.error}", style: const TextStyle(color: Colors.red)));
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text("لا يوجد عمليات سابقة", style: TextStyle(color: Colors.white70)));
                return ListView.separated(
                  padding: EdgeInsets.all(isTablet ? 20 : 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final name = d['productName']?.toString() ?? "-";
                    final receiver = d['receiver']?.toString() ?? "-";
                    final sender = d['sender']?.toString() ?? "-";
                    final status = d['status']?.toString() ?? "unknown";
                    final isSuccess = status == "success";
                    final ts = d['createdAt'] as Timestamp?;
                    final iso = d['createdAtLocal']?.toString();
                    return Container(
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSuccess ? Colors.green.withOpacity(0.6) : Colors.red.withOpacity(0.6))),
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.greenAccent : Colors.red, size: 18),
                          const SizedBox(width: 6),
                          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isSuccess ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(6)), child: Text(isSuccess ? "نجاح" : "فشل", style: const TextStyle(color: Colors.white, fontSize: 10))),
                        ]),
                        const SizedBox(height: 6),
                        Text("من: $sender → إلى: $receiver", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_formatDate(ts, iso), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
