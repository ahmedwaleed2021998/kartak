import 'dart:convert';
import 'package:http/http.dart' as http;

class Offers365Service {
  Future<String> login(String number, String password) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/auth/realms/vf-realm/protocol/openid-connect/token');
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Xiaomi M2102J20SG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 AnaVodafoneAndroid/2025.11.1',
      'Accept': 'application/json',
      'x-agent-operatingsystem': '13',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Xiaomi M2102J20SG',
      'x-agent-version': '2025.11.1',
      'x-agent-build': '1063',
      'digitalId': '244BQYOGFM0IM',
      'device-id': 'b83aab2d8fa633da',
    };
    final body = {
      'username': number,
      'password': password,
      'grant_type': 'password',
      'client_secret': '95fd95fb-7489-4958-8ae6-d31a525cd20a',
      'client_id': 'ana-vodafone-app',
    };
    final resp = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('فشل تسجيل الدخول: ${resp.statusCode}');
    final data = jsonDecode(resp.body);
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) throw Exception('لم يتم العثور على التوكن');
    return token;
  }

  Future<List<dynamic>> getOffers(String number, String token) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/promo/promotion');
    final params = {'@type': 'Promo', r'$.context.type': 'offerstab'};
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json',
      'channel': 'MOBILE',
      'useCase': 'Promo',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': 'b83aab2d8fa633da',
      'x-agent-operatingsystem': '13',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Xiaomi M2102J20SG',
      'x-agent-version': '2025.11.1',
      'x-agent-build': '1063',
      'msisdn': number,
      'Content-Type': 'application/json',
      'Accept-Language': 'en',
    };
    final uri = url.replace(queryParameters: params);
    final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('فشل جلب العروض: ${resp.statusCode}');
    final data = jsonDecode(resp.body);
    if (data is List) return data;
    return [];
  }

  Future<({bool success, String message})> subscribe(String number, String token, String offerId) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/promo/promotion/$offerId');
    final payload = {
      'channel': {'id': '0'},
      'characteristics': [{'name': 'Param6', 'value': '0'}],
      'context': {'type': 'offerstabV2'},
      '@type': 'Promo',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json',
      'channel': 'MOBILE',
      'useCase': 'Promo',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': 'b83aab2d8fa633da',
      'x-agent-operatingsystem': '13',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Xiaomi M2102J20SG',
      'x-agent-version': '2025.11.1',
      'x-agent-build': '1063',
      'msisdn': number,
      'Accept-Language': 'en',
      'Content-Type': 'application/json; charset=UTF-8',
    };
    try {
      final resp = await http.patch(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 204) return (success: true, message: 'تم الاشتراك بنجاح');
      try {
        final data = jsonDecode(resp.body);
        final reason = data['reason']?.toString() ?? resp.body;
        return (success: false, message: 'فشل: $reason');
      } catch (_) {
        return (success: false, message: 'فشل: ${resp.body.substring(0, resp.body.length > 150 ? 150 : resp.body.length)}');
      }
    } catch (e) {
      return (success: false, message: 'خطأ: $e');
    }
  }
}
