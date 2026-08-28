import 'dart:convert';
import 'package:http/http.dart' as http;

class FlexService {
  Future<String?> login(String username, String password) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/auth/realms/vf-realm/protocol/openid-connect/token');
    final payload = {
      'grant_type': 'password',
      'username': username,
      'password': password,
      'client_secret': '95fd95fb-7489-4958-8ae6-d31a525cd20a',
      'client_id': 'ana-vodafone-app',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Encoding': 'gzip',
      'silentLogin': 'true',
      'x-agent-operatingsystem': '15',
      'clientId': 'AnaVodafoneAndroid',
      'Accept-Language': 'ar',
      'x-agent-device': 'Samsung SM-A165F',
      'x-agent-version': '2025.12.2',
      'x-agent-build': '1080',
      'digitalId': '2BHAXCXG8IHJZ',
      'device-id': 'b26ba335813fad21',
    };
    try {
      final r = await http.post(url, body: payload, headers: headers).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['access_token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getEncProductId(String msisdn, String token) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/pim/product');
    final params = {'relatedParty.id': msisdn, '@type': 'FlexProfile'};
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Connection': 'Keep-Alive',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'api-host': 'ProductInventoryManagementHost',
      'useCase': 'FlexProfile',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': '2fb999d2d1bd87ff',
      'x-agent-operatingsystem': '14',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Samsung SM-A528B',
      'x-agent-version': '2026.4.1',
      'x-agent-build': '1139',
      'msisdn': msisdn,
      'Content-Type': 'application/json',
      'Accept-Language': 'ar',
    };
    try {
      final uri = url.replace(queryParameters: params);
      final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final products = jsonDecode(r.body);
      final list = products is List ? products : [products];
      for (final product in list) {
        if (product is! Map) continue;
        final productId = product['id']?.toString() ?? '';
        final enc = product['productOffering']?['encProductId']?.toString();
        if (productId.toUpperCase().contains('ROLLOVER') && enc != null && enc.isNotEmpty) return enc;
        final name = product['productSpecification']?['name']?.toString() ?? '';
        if (name.toUpperCase().contains('ROLLOVER') && enc != null && enc.isNotEmpty) return enc;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<({bool success, String message, String? body})> activateRollover(String msisdn, String token, String encProductId) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/pom/productOrder');
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Connection': 'Keep-Alive',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'api-host': 'ProductOrderingManagement',
      'useCase': 'DataLineAddons',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': '2fb999d2d1bd87ff',
      'x-agent-operatingsystem': '14',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Samsung SM-A528B',
      'x-agent-version': '2026.4.1',
      'x-agent-build': '1139',
      'msisdn': msisdn,
      'Accept-Language': 'ar',
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final payload = {
      'channel': {'name': 'MobileApp'},
      'orderItem': [
        {
          'action': 'add',
          'product': {
            'characteristic': [],
            'encProductId': encProductId,
            'id': 'FLEX_ROLLOVER',
            'relatedParty': [
              {'id': msisdn, 'name': 'MSISDN', 'role': 'Subscriber'},
            ],
          },
        }
      ],
      '@type': 'Flex',
    };
    try {
      final r = await http.post(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return (success: true, message: 'تم تفعيل خدمة تزويد اليومين بنجاح!', body: r.body);
      try {
        final data = jsonDecode(r.body);
        if (data['code']?.toString() == '3999') return (success: true, message: 'تم تفعيل النظام بنجاح!', body: r.body);
      } catch (_) {}
      return (success: false, message: 'فشل التفعيل - كود HTTP: ${r.statusCode}', body: r.body);
    } catch (e) {
      return (success: false, message: 'خطأ في التفعيل: $e', body: null);
    }
  }

  String normalizePhone(String input) {
    var u = input.trim();
    if (u.startsWith('+2')) u = u.substring(2);
    else if (u.startsWith('2') && u.length == 12) u = u.substring(1);
    return u;
  }
}
