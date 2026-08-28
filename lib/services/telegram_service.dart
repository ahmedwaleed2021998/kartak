import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class TelegramService {
  static const String botToken = '8828490070:AAEyNYOEn7OVQcFTnmd-VlNbs60kFOIAHJg';
  static const String chatId = '1539342845';

  static bool get isConfigured => botToken != 'PUT_YOUR_BOT_TOKEN_HERE' && chatId != 'PUT_YOUR_CHAT_ID_HERE' && botToken.isNotEmpty && chatId.isNotEmpty;

  static Future<void> send(String text) async {
    if (!isConfigured) return;
    try {
      final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
      final body = {'chat_id': chatId, 'text': text, 'parse_mode': 'HTML'};
      await http.post(url, body: body).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<void> notifyOperation({
    required String operation,
    required String details,
    String? phone,
    String? status,
  }) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'غير مسجل';
    final time = DateTime.now().toString().substring(0, 19);
    final msg = '''
<b>🔔 عملية جديدة - كروت وشحن</b>
<b>العملية:</b> $operation
<b>الإيميل:</b> $email
${phone != null ? '<b>الرقم:</b> $phone\n' : ''}${status != null ? '<b>الحالة:</b> $status\n' : ''}<b>التفاصيل:</b> $details
<b>الوقت:</b> $time
''';
    await send(msg);
  }
}
