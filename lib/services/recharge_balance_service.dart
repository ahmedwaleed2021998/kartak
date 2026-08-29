import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class RechargeBalanceService {
  Future<({bool success, dynamic data})> recharge({
    required String token,
    required String senderMsisdn,
    required String receiverNumber,
    required double amount,
    required String pin,
  }) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/orderor/productOrder');
    final senderInt = senderMsisdn.startsWith('0') ? senderMsisdn.substring(1) : senderMsisdn;
    final receiverInt = receiverNumber.startsWith('0') ? receiverNumber.substring(1) : receiverNumber;
    final digitalId = "${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}".substring(0, 13).toUpperCase();
    final payload = {
      'payment': [
        {
          'characteristics': [
            {'name': 'authorizationCode', 'value': pin},
            {'name': 'digitalTransactionId', 'value': digitalId},
          ],
          '@type': 'digitalWallet',
        }
      ],
      'productOrderItem': [
        {
          'characteristics': [
            {'name': 'MSISDN', '@type': 'receiver', 'value': '20$receiverInt'},
            {'name': 'MSISDN', '@type': 'sender', 'value': '20$senderInt'},
          ],
          'itemTotalPrice': [
            {
              'price': {
                'taxIncludedAmount': {'unit': 'EGP', 'value': amount}
              }
            }
          ]
        }
      ],
      '@type': 'paymentRecharge',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Request-ID': "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}",
      'device-id': 'b26ba335813fad21',
      'api-version': 'v2',
      'msisdn': senderMsisdn,
      'Authorization': 'Bearer $token',
      'Accept-Language': 'ar',
      'x-agent-operatingsystem': '16',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Samsung SM-A165F',
      'x-agent-version': '2025.11.1',
      'x-agent-build': '1063',
      'digitalId': '',
    };
    try {
      final resp = await http.post(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 10));
      dynamic data;
      try { data = jsonDecode(resp.body); } catch (_) { data = resp.body; }
      if (resp.statusCode == 200) {
        if (data is Map && (data['state'] == 'Completed' || data['complete'] == true || data['code'] == '0000')) return (success: true, data: data);
        final reason = data is Map ? data['reason']?.toString() ?? 'رصيدك غير كافي أو خطأ' : resp.body;
        if (reason.toLowerCase().contains('balance') || reason.contains('رصيد')) return (success: false, data: 'مفيش رصيد كافى علي المحفظة');
        return (success: false, data: reason);
      }
      return (success: false, data: resp.body);
    } catch (e) {
      return (success: false, data: e.toString());
    }
  }
}
